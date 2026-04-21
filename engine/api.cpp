#ifndef CHATURAJI_BUILD_DLL
#define CHATURAJI_BUILD_DLL
#endif
#include "api.h"
#include "board.h"
#include "eval.h"
#include "mcts.h"
#include <cstdio>
#include <cstring>

#include <string>

// ============================================================
// Internal engine state
// ============================================================
struct MoveResult {
    char moveStr[8];
    int n;
    float q[4];
};

struct Engine {
    Board board;
    MCTS  mcts;
    NNUEModel nnue;

    // Cached results from last search/eval
    float  evalScores[4]  = {0.f, 0.f, 0.f, 0.f};
    char   bestMoveStr[8] = "resign";
    char   fenBuf[256]    = {};
    std::vector<MoveResult> lastChildStats;

    Engine() : mcts(42) {
        board.reset();
        mcts.setNNUE(&nnue);
    }
};

// ============================================================
// Helpers
// ============================================================
static Engine* asEngine(void* p) {
    return reinterpret_cast<Engine*>(p);
}

// Convert square index to algebraic (e.g. 0x10 → "a7")
static void squareToAlg(int sq, char* out) {
    int col = sq & 7;
    int row = sq >> 4;
    out[0] = 'a' + col;
    out[1] = '1' + (7 - row);
    out[2] = '\0';
}

// Convert algebraic square string to 0x88 index, returns -1 on failure
static int algToSquare(const char* s) {
    if (s[0] < 'a' || s[0] > 'h') return -1;
    if (s[1] < '1' || s[1] > '8') return -1;
    int col = s[0] - 'a';
    int row = 7 - (s[1] - '1');
    return (row << 4) | col;
}

// ============================================================
// Lifecycle
// ============================================================
void* engine_create(void) {
    return new Engine();
}

void engine_destroy(void* engine) {
    delete asEngine(engine);
}

// ============================================================
// Position
// ============================================================
int engine_set_position(void* engine, const char* fen) {
    auto* e = asEngine(engine);
    bool ok = e->board.load(std::string(fen));
    if (ok) {
        // Reset cached results
        memset(e->evalScores, 0, sizeof(e->evalScores));
        strncpy(e->bestMoveStr, "resign", sizeof(e->bestMoveStr));
    }
    return ok ? 1 : 0;
}

const char* engine_get_fen(void* engine) {
    auto* e = asEngine(engine);
    std::string fen = e->board.generateFen();
    strncpy(e->fenBuf, fen.c_str(), sizeof(e->fenBuf) - 1);
    e->fenBuf[sizeof(e->fenBuf) - 1] = '\0';
    return e->fenBuf;
}

int engine_is_game_over(void* engine) {
    return asEngine(engine)->board.turn == GAME_OVER ? 1 : 0;
}

int engine_load_nnue(void* engine, const char* path) {
    auto* e = asEngine(engine);
    return e->nnue.load(std::string(path)) ? 1 : 0;
}

// ============================================================
// Search
// ============================================================
void engine_search(void* engine, int iterations) {
    auto* e = asEngine(engine);
    if (e->board.turn == GAME_OVER) return;

    Node root;
    e->mcts.search(root, e->board, iterations);

    // Cache best move
    Move best = e->mcts.bestMove(root);
    if (best == RESIGN_MOVE) {
        strncpy(e->bestMoveStr, "resign", sizeof(e->bestMoveStr));
    } else {
        char from[3], to[3];
        squareToAlg(best.from, from);
        squareToAlg(best.to, to);
        snprintf(e->bestMoveStr, sizeof(e->bestMoveStr), "%s%s", from, to);
    }

    // Cache child statistics
    e->lastChildStats.clear();
    for (const auto& child : root.children) {
        MoveResult res;
        if (child->move == RESIGN_MOVE) {
            strncpy(res.moveStr, "resign", sizeof(res.moveStr));
        } else {
            char f[3], t[3];
            squareToAlg(child->move.from, f);
            squareToAlg(child->move.to, t);
            snprintf(res.moveStr, sizeof(res.moveStr), "%s%s", f, t);
        }
        res.n = child->visitCount;
        for (int c = 0; c < 4; c++) {
            res.q[c] = (child->visitCount > 0) ? (float)(child->qSum[c] / child->visitCount) : 0.0f;
        }
        e->lastChildStats.push_back(res);
    }

    // Cache Q-value from root statistics (average outcome)
    if (root.visitCount > 0) {
        for (int c = 0; c < 4; c++) {
            e->evalScores[c] = static_cast<float>(root.qSum[c] / root.visitCount);
        }
    }
}

const char* engine_get_best_move(void* engine) {
    return asEngine(engine)->bestMoveStr;
}

int engine_get_move_stats(void* engine, const char* moveStr, int* n_out, float* q_out) {
    auto* e = asEngine(engine);
    for (const auto& res : e->lastChildStats) {
        if (strcmp(res.moveStr, moveStr) == 0) {
            *n_out = res.n;
            memcpy(q_out, res.q, 4 * sizeof(float));
            return 1;
        }
    }
    return 0;
}

float engine_get_eval(void* engine, int player) {
    if (player < 0 || player > 3) return 0.f;
    return asEngine(engine)->evalScores[player];
}

// ============================================================
// Direct evaluation (no search)
// ============================================================
void engine_evaluate(void* engine) {
    auto* e = asEngine(engine);
    if (e->board.turn == GAME_OVER) {
        float total = 0;
        for (int c = 0; c < 4; c++) total += e->board.points[c];
        for (int c = 0; c < 4; c++) {
            e->evalScores[c] = total > 0 ? (e->board.points[c] / total) * 12.0f : 3.0f;
        }
        return;
    }

    if (e->nnue.loaded) {
        float probs[NNUE_OUT_SIZE];
        e->nnue.evaluate(e->board, probs);
        // NNUE predicts [self, left, across, right] relative to board.turn.
        // Map back to [Red, Blue, Yellow, Green] and scale to rank-points (0..12).
        for (int c = 0; c < 4; c++) {
            int rel = NNUE_RELATION[e->board.turn][c];
            e->evalScores[c] = probs[rel] * 12.0f;
        }
    } else {
        auto scores = evaluate(e->board);
        for (int c = 0; c < 4; c++) {
            e->evalScores[c] = static_cast<float>(scores[c]);
        }
    }
}

// ============================================================
// Move application
// ============================================================
int engine_apply_move(void* engine, const char* moveStr) {
    auto* e = asEngine(engine);
    if (e->board.turn == GAME_OVER) return 0;

    Move move;
    if (strcmp(moveStr, "resign") == 0) {
        move = RESIGN_MOVE;
    } else if (strlen(moveStr) >= 4) {
        int from = algToSquare(moveStr);
        int to   = algToSquare(moveStr + 2);
        if (from == -1 || to == -1) return 0;
        move = {from, to};
    } else {
        return 0;
    }

    // Validate the move is legal
    Move legalMoves[MAX_MOVES];
    int count = e->board.generateMoves(legalMoves);
    bool found = false;
    for (int i = 0; i < count; i++) {
        if (legalMoves[i] == move) { found = true; break; }
    }
    if (!found) return 0;

    e->board.makeMove(move, &e->nnue);
    // Invalidate cached results
    memset(e->evalScores, 0, sizeof(e->evalScores));
    strncpy(e->bestMoveStr, "resign", sizeof(e->bestMoveStr));
    return 1;
}

int engine_get_turn(void* engine) {
    uint8_t t = asEngine(engine)->board.turn;
    if (t == GAME_OVER) return -1;
    return static_cast<int>(t);
}

int engine_get_points(void* engine, int player) {
    if (player < 0 || player > 3) return 0;
    return asEngine(engine)->board.points[player];
}
