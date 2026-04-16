#pragma once
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

// --- Piece encoding (matches Dart engine bit layout) ---
constexpr uint8_t COLOR_MASK = 0x03;
constexpr uint8_t PIECE_MASK = 0x1C;

constexpr uint8_t EMPTY  = 0x00;
constexpr uint8_t PAWN   = 0x04;
constexpr uint8_t KNIGHT = 0x08;
constexpr uint8_t BISHOP = 0x0C;
constexpr uint8_t ROOK   = 0x10;
constexpr uint8_t KING   = 0x14;

constexpr uint8_t RED    = 0x00;
constexpr uint8_t BLUE   = 0x01;
constexpr uint8_t YELLOW = 0x02;
constexpr uint8_t GREEN  = 0x03;

constexpr uint8_t DEAD   = 0x40;
constexpr uint8_t GAME_OVER = 0x80;

// --- Square constants (0x88 board) ---
constexpr int SQ_A8 = 0;
constexpr int SQ_H8 = 7;
constexpr int SQ_A1 = 112;
constexpr int SQ_H1 = 119;

// --- Pawn movement offsets per color [color][0=push, 1=cap_left, 2=cap_right] ---
constexpr int PAWN_OFFSETS[4][3] = {
    {-16, -17, -15},  // Red:    north
    {  1, -15,  17},  // Blue:   east
    { 16,  17,  15},  // Yellow: south
    { -1,  15, -17},  // Green:  west
};

// --- Piece movement offsets ---
constexpr int KNIGHT_OFFSETS[] = {-18, -33, -31, -14, 18, 33, 31, 14};
constexpr int BISHOP_OFFSETS[] = {-17, -15, 17, 15};
constexpr int ROOK_OFFSETS[]   = {-16, 1, 16, -1};
constexpr int KING_OFFSETS[]   = {-17, -16, -15, 1, 17, 16, 15, -1};

// --- Move representation ---
struct Move {
    int from;
    int to;

    bool operator==(const Move& o) const { return from == o.from && to == o.to; }
    bool operator!=(const Move& o) const { return !(*this == o); }
};

constexpr Move RESIGN_MOVE = {-1, -1};
constexpr int MAX_MOVES = 256;

// --- Capture point values ---
inline int capturePoints(uint8_t piece) {
    uint8_t type = piece & PIECE_MASK;
    switch (type) {
        case PAWN:   return 1;
        case KNIGHT: return 3;
        case BISHOP: return 5;
        case ROOK:   return 5;
        case KING:   return 3;
        default:     return 0;
    }
}

// --- Undo info for unmakeMove ---
struct UndoInfo {
    Move move;
    uint8_t captured;       // piece on 'to' before move
    uint8_t movedPiece;     // piece on 'from' before move (after promotion it changes)
    uint8_t promoted;       // piece after promotion (0 if no promotion)
    int points[4];          // points before move
    uint8_t turn;           // turn before move
    uint32_t liveColors;    // bitmask of live colors before move
    int newChecks;          // check bonus awarded (to undo points)
};

// --- Board ---
class Board {
public:
    uint8_t board[128];
    int points[4];
    uint32_t liveColors;    // bitmask: bit 0=red, 1=blue, 2=yellow, 3=green
    uint8_t turn;

    // Undo stack
    UndoInfo undoStack[512];
    int undoCount;

    Board() : undoCount(0) {
        clear();
    }

    void clear() {
        memset(board, EMPTY, 128);
        memset(points, 0, sizeof(points));
        liveColors = 0;
        turn = RED;
        undoCount = 0;
    }

    void reset() {
        load("bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r");
    }

    bool isColorLive(uint8_t color) const {
        return (liveColors & (1u << color)) != 0;
    }

    void setColorLive(uint8_t color) {
        liveColors |= (1u << color);
    }

    void setColorDead(uint8_t color) {
        liveColors &= ~(1u << color);
    }

    int popCount() const {
        // Count live colors
        uint32_t v = liveColors;
        int count = 0;
        while (v) { count += v & 1; v >>= 1; }
        return count;
    }

    // --- FEN loading ---
    bool load(const std::string& fen);

    // --- FEN generation ---
    std::string generateFen() const;

    // --- Move generation ---
    int generateMoves(Move* moves) const;

    // --- Make / Unmake ---
    void makeMove(const Move& move);
    void unmakeMove();

    // --- King / Check ---
    int getKingSquare(uint8_t color) const;
    bool isKingInCheck(uint8_t color) const;
    bool isSquareAttacked(int square, uint32_t byColors) const;

    // --- Material ---
    int getMaterial(uint8_t color) const;

private:
    void markDead(uint8_t deadColor);
    void deadKingPoints(uint8_t color);
    static bool isDigit(char c) { return c >= '0' && c <= '9'; }
};
