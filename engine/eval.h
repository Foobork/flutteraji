#pragma once
#include <array>
#include <cmath>
#include "board.h"

// --- Evaluation weight constants (mirrors eval.dart) ---
struct EvalWeights {
    static constexpr double pointsWeight = 3.0;
    static constexpr double materialWeight = 1.0;
    static constexpr double pawnAdvancementWeight = 0.5;
    static constexpr double centralityWeight = 0.3;
    static constexpr double checkPenalty = -5.0;
    static constexpr double nearbyEnemyPenalty = -1.0;
    static constexpr double nearbyFriendlyBonus = 0.3;
    static constexpr double deadPenalty = -50.0;
};

// Forward declarations
static double pawnAdvancement(int color, int row, int col);
static double centralityBonus(int row, int col);
static double kingSafety(const Board& board, int color);

// Evaluate board – returns an array of 4 scores (red, blue, yellow, green)
inline std::array<double, 4> evaluate(const Board& board) {
    std::array<double, 4> scores = {0.0, 0.0, 0.0, 0.0};

    for (int color = 0; color < 4; ++color) {
        if (!board.isColorLive(color)) {
            // Dead player: only earned points plus large penalty
            scores[color] = board.points[color] * EvalWeights::pointsWeight + EvalWeights::deadPenalty;
            continue;
        }

        double score = 0.0;
        // 1. Earned points (locked‑in)
        score += board.points[color] * EvalWeights::pointsWeight;
        // 2. Material on board (potential future captures)
        score += board.getMaterial(color) * EvalWeights::materialWeight;

        // 3‑4. Per‑piece positional bonuses
        for (int sq = SQ_A8; sq <= SQ_H1; ++sq) {
            if ((sq & 0x88) != 0) { sq += 7; continue; }
            uint8_t piece = board.board[sq];
            if (piece == EMPTY) continue;
            if (piece & DEAD) continue; // dead pieces can't move
            if ((piece & COLOR_MASK) != color) continue;

            uint8_t pieceType = piece & PIECE_MASK;
            int row = sq >> 4;      // high nibble
            int col = sq & 7;       // low nibble

            // 3. Pawn advancement (quadratic)
            if (pieceType == PAWN) {
                score += pawnAdvancement(color, row, col);
            }
            // 4. Centrality bonus for knights, bishops, rooks
            if (pieceType == KNIGHT || pieceType == BISHOP || pieceType == ROOK) {
                score += centralityBonus(row, col);
            }
        }

        // 5. King safety
        score += kingSafety(board, color);
        scores[color] = score;
    }
    return scores;
}

// -----------------------------------------------------------------
// Helper implementations
static double pawnAdvancement(int color, int row, int col) {
    int advancement = 0;
    switch (color) {
        case RED:    advancement = 6 - row; break;               // north
        case BLUE:   advancement = col - 1; break;               // east
        case YELLOW: advancement = row - 1; break;               // south
        case GREEN:  advancement = 6 - col; break;               // west
        default:     advancement = 0; break;
    }
    if (advancement < 0) advancement = 0;
    if (advancement > 6) advancement = 6;
    return static_cast<double>(advancement * advancement) * EvalWeights::pawnAdvancementWeight;
}

static double centralityBonus(int row, int col) {
    // Manhattan distance from board centre (3.5, 3.5)
    double dr = std::abs(row - 3.5);
    double dc = std::abs(col - 3.5);
    double dist = dr + dc; // max 7 (corner)
    return (7.0 - dist) * EvalWeights::centralityWeight;
}

static double kingSafety(const Board& board, int color) {
    int kingSq = board.getKingSquare(color);
    if (kingSq == -1) return -100.0; // sanity fallback
    double safety = 0.0;
    if (board.isKingInCheck(color)) {
        safety += EvalWeights::checkPenalty;
    }
    int kingRow = kingSq >> 4;
    int kingCol = kingSq & 7;
    for (int dr = -2; dr <= 2; ++dr) {
        for (int dc = -2; dc <= 2; ++dc) {
            if (dr == 0 && dc == 0) continue;
            int r = kingRow + dr;
            int c = kingCol + dc;
            if (r < 0 || r > 7 || c < 0 || c > 7) continue;
            int sq = r * 16 + c;
            uint8_t piece = board.board[sq];
            if (piece == EMPTY || (piece & DEAD)) continue;
            if ((piece & COLOR_MASK) == color) {
                safety += EvalWeights::nearbyFriendlyBonus;
            } else {
                safety += EvalWeights::nearbyEnemyPenalty;
            }
        }
    }
    return safety;
}
