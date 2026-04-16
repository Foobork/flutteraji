#include "board.h"
#include <cstdio>
#include <chrono>
#include <string>
#include "eval.h"
#include "mcts.h"
#include "selfplay.h"
#define CHATURAJI_BUILD_DLL  // needed when api.cpp is compiled inline into the exe
#include "api.h"
#include "api.cpp"  // compile API directly into exe for testing

// ============================================================
// Perft — exhaustive move enumeration for correctness testing
// ============================================================
static uint64_t perft(Board& board, int depth) {
    if (depth == 0) return 1;
    if (board.turn == GAME_OVER) return 1;

    Move moves[MAX_MOVES];
    int moveCount = board.generateMoves(moves);
    uint64_t nodes = 0;

    for (int i = 0; i < moveCount; i++) {
        board.makeMove(moves[i]);
        nodes += perft(board, depth - 1);
        board.unmakeMove();
    }

    return nodes;
}

// Divided perft — shows per-move breakdown at root
static uint64_t perftDivide(Board& board, int depth) {
    Move moves[MAX_MOVES];
    int moveCount = board.generateMoves(moves);
    uint64_t total = 0;

    for (int i = 0; i < moveCount; i++) {
        board.makeMove(moves[i]);
        uint64_t nodes = perft(board, depth - 1);
        board.unmakeMove();

        // Print move and count
        if (moves[i] == RESIGN_MOVE) {
            printf("resign: %llu\n", (unsigned long long)nodes);
        } else {
            int fromRow = moves[i].from >> 4;
            int fromCol = moves[i].from & 7;
            int toRow = moves[i].to >> 4;
            int toCol = moves[i].to & 7;
            printf("%c%d%c%d: %llu\n",
                   'a' + fromCol, 8 - fromRow,
                   'a' + toCol, 8 - toRow,
                   (unsigned long long)nodes);
        }

        total += nodes;
    }

    printf("\nTotal: %llu\n", (unsigned long long)total);
    return total;
}

// ============================================================
// Basic tests
// ============================================================
static void testFenRoundTrip() {
    Board board;
    board.reset();
    std::string fen1 = board.generateFen();
    
    Board board2;
    board2.load(fen1);
    std::string fen2 = board2.generateFen();

    if (fen1 == fen2) {
        printf("[PASS] FEN round-trip: %s\n", fen1.c_str());
    } else {
        printf("[FAIL] FEN round-trip:\n  got:      %s\n  expected: %s\n", fen2.c_str(), fen1.c_str());
    }
}

static void testMakeUnmake() {
    Board board;
    board.reset();
    std::string fenBefore = board.generateFen();

    Move moves[MAX_MOVES];
    int moveCount = board.generateMoves(moves);

    // Make and unmake each move — board should be identical after
    bool allPass = true;
    for (int i = 0; i < moveCount; i++) {
        board.makeMove(moves[i]);
        board.unmakeMove();
        std::string fenAfter = board.generateFen();
        if (fenAfter != fenBefore) {
            printf("[FAIL] Make/Unmake move %d: FEN mismatch\n  before: %s\n  after:  %s\n",
                   i, fenBefore.c_str(), fenAfter.c_str());
            allPass = false;
        }
    }

    if (allPass) {
        printf("[PASS] Make/Unmake: all %d moves restore board correctly\n", moveCount);
    }
}

static void testMakeUnmakeDepth(int depth) {
    Board board;
    board.reset();
    std::string fenBefore = board.generateFen();

    // Run perft (which does make/unmake at every node)
    uint64_t nodes = perft(board, depth);

    // After perft, board should be back to original
    std::string fenAfter = board.generateFen();
    if (fenAfter == fenBefore) {
        printf("[PASS] Make/Unmake depth %d (%llu nodes): board restored\n",
               depth, (unsigned long long)nodes);
    } else {
        printf("[FAIL] Make/Unmake depth %d: board corrupted\n  before: %s\n  after:  %s\n",
               depth, fenBefore.c_str(), fenAfter.c_str());
    }
}

// ============================================================
// Main
// ============================================================
int main(int argc, char* argv[]) {
    // --help / -h
    if (argc > 1 && (std::string(argv[1]) == "--help" || std::string(argv[1]) == "-h")) {
        printf(
            "Usage: chaturaji.exe [mode] [options]\n\n"
            "Modes:\n"
            "  (none)     Run FEN/make-unmake tests + perft benchmark (depths 1-6)\n"
            "  validate   Assert perft node counts against reference values\n"
            "  eval       Print hand-crafted evaluation for start position\n"
            "  mcts       Run 1000 MCTS iterations and show best move\n"
            "  selfplay   Generate self-play training data (use selfplay --help for options)\n"
            "  --help     Show this help\n\n"
            "Perft reference (start position):\n"
            "  depth 1:        9\n"
            "  depth 2:       81\n"
            "  depth 3:      729\n"
            "  depth 4:    6,553\n"
            "  depth 5:   75,761\n"
            "  depth 6:  874,122\n"
        );
        return 0;
    }

    // selfplay mode — dispatch immediately, pass remaining args
    if (argc > 1 && std::string(argv[1]) == "selfplay") {
        return selfPlayMain(argc - 1, argv + 1);
    }
    printf("=== Chaturaji Engine Tests ===\n\n");

    // Basic tests
    testFenRoundTrip();
    testMakeUnmake();
    testMakeUnmakeDepth(2);
    testMakeUnmakeDepth(3);
    testMakeUnmakeDepth(4);

    printf("\n=== Perft Results ===\n");

    Board board;
    board.reset();

    for (int depth = 1; depth <= 6; depth++) {
        auto start = std::chrono::high_resolution_clock::now();
        uint64_t nodes = perft(board, depth);
        auto end = std::chrono::high_resolution_clock::now();
        double ms = std::chrono::duration<double, std::milli>(end - start).count();

        printf("Perft(%d) = %12llu  (%8.1f ms, %7.0f knps)\n",
               depth, (unsigned long long)nodes, ms,
               ms > 0 ? nodes / ms : 0);
    }

    // Perft validation mode (optional arg "validate")
    if (argc > 1 && std::string(argv[1]) == "validate") {
        const uint64_t expected[] = {9ULL,81ULL,729ULL,6553ULL,75761ULL,874122ULL};
        bool ok = true;
        for (int d = 1; d <= 6; ++d) {
            Board b; b.reset();
            uint64_t nodes = perft(b, d);
            if (nodes != expected[d-1]) {
                printf("Perft validation failed at depth %d: got %llu, expected %llu\n",
                       d, (unsigned long long)nodes, (unsigned long long)expected[d-1]);
                ok = false;
            }
        }
        if (ok) printf("Perft validation passed for depths 1-6.\n");
    }

    // Evaluation demo (optional arg "eval")
    if (argc > 1 && std::string(argv[1]) == "eval") {
        auto scores = evaluate(board);
        printf("\n=== Evaluation (post-reset) ===\n");
        const char* names[4] = {"Red", "Blue", "Yellow", "Green"};
        for (int i = 0; i < 4; ++i) {
            printf("%s: %8.3f\n", names[i], scores[i]);
        }
    }

    // MCTS smoke test (optional arg "mcts")
    if (argc > 1 && std::string(argv[1]) == "mcts") {
        const char* names[4] = {"Red", "Blue", "Yellow", "Green"};
        Board mctsBoard;
        mctsBoard.reset();
        MCTS mcts;
        Node root;

        const int iters = 1000;
        auto start = std::chrono::high_resolution_clock::now();
        mcts.search(root, mctsBoard, iters);
        auto end = std::chrono::high_resolution_clock::now();
        double ms = std::chrono::duration<double, std::milli>(end - start).count();

        Move best = mcts.bestMove(root);
        printf("\n=== MCTS (%d iterations, %.1f ms) ===\n", iters, ms);
        printf("Root visits: %d\n", root.visitCount);
        printf("Best move: ");
        if (best == RESIGN_MOVE) {
            printf("resign\n");
        } else {
            int fc = best.from & 7, fr = 8 - (best.from >> 4);
            int tc = best.to & 7,   tr = 8 - (best.to >> 4);
            printf("%c%d%c%d\n", 'a'+fc, fr, 'a'+tc, tr);
        }
        printf("\nChild stats (move: visits, Q[red]):\n");
        for (const auto& child : root.children) {
            if (child->visitCount == 0) continue;
            if (child->move == RESIGN_MOVE) {
                printf("  resign: N=%-5d  Q[red]=%.2f\n",
                       child->visitCount, child->q(0));
            } else {
                int fc2 = child->move.from & 7, fr2 = 8 - (child->move.from >> 4);
                int tc2 = child->move.to & 7,   tr2 = 8 - (child->move.to >> 4);
                printf("  %c%d%c%d: N=%-5d  Q[red]=%.2f\n",
                       'a'+fc2, fr2, 'a'+tc2, tr2,
                       child->visitCount, child->q(0));
            }
        }
    }

    // C API smoke test (optional arg "api")
    if (argc > 1 && std::string(argv[1]) == "api") {
        printf("\n=== C API Smoke Test ===\n");
        void* eng = engine_create();

        printf("FEN: %s\n", engine_get_fen(eng));
        printf("Turn: %d (0=red)\n", engine_get_turn(eng));
        printf("Game over: %d\n", engine_is_game_over(eng));

        // Direct eval
        engine_evaluate(eng);
        printf("Eval (no search): r=%.2f b=%.2f y=%.2f g=%.2f\n",
               engine_get_eval(eng, 0), engine_get_eval(eng, 1),
               engine_get_eval(eng, 2), engine_get_eval(eng, 3));

        // Search
        engine_search(eng, 500);
        printf("Best move: %s\n", engine_get_best_move(eng));
        printf("Q (r=%.2f b=%.2f y=%.2f g=%.2f)\n",
               engine_get_eval(eng, 0), engine_get_eval(eng, 1),
               engine_get_eval(eng, 2), engine_get_eval(eng, 3));

        // Apply move — copy the string first since apply_move invalidates the internal buffer
        char mvBuf[8];
        strncpy(mvBuf, engine_get_best_move(eng), sizeof(mvBuf));
        int ok = engine_apply_move(eng, mvBuf);
        printf("Applied '%s': %s\n", mvBuf, ok ? "OK" : "FAIL");
        printf("FEN after: %s\n", engine_get_fen(eng));
        printf("Turn: %d (1=blue)\n", engine_get_turn(eng));

        // Test illegal move rejected
        int rejected = engine_apply_move(eng, "a1a1");
        printf("Illegal move rejected: %s\n", rejected == 0 ? "YES" : "NO");

        engine_destroy(eng);
        printf("[PASS] C API smoke test complete.\n");
    }

    return 0;
}
