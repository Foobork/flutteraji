#define CHATURAJI_BUILD_DLL
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
struct Engine {
    Board board;
    MCTS  mcts;

    // Cached results from last search/eval
    float  evalScores[4]  = {0.f, 0.f, 0.f, 0.f};
    char   bestMoveStr[8] = "resign";
    char   fenBuf[256]    = {};

    Engine() : mcts(42) {
        board.reset();
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

    // Cache Q-value from root's most visited child
    const Node* best_child = nullptr;
    for (const auto& child : root.children) {
        if (!best_child || child->visitCount > best_child->visitCount)
            best_child = child.get();
    }
    if (best_child && root.visitCount > 0) {
        for (int c = 0; c < 4; c++) {
            e->evalScores[c] = static_cast<float>(root.qSum[c] / root.visitCount);
        }
    }
}

const char* engine_get_best_move(void* engine) {
    return asEngine(engine)->bestMoveStr;
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
    auto scores = evaluate(e->board);
    for (int c = 0; c < 4; c++) {
        e->evalScores[c] = static_cast<float>(scores[c]);
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

    e->board.makeMove(move);
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
