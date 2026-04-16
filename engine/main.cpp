#include "board.h"
#include <cstdio>
#include <cstdlib>
#include <chrono>

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

    return 0;
}
