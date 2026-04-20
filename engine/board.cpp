#include "board.h"
#include <sstream>

// --- Color / Piece char mappings ---
static uint8_t charToColor(char c) {
    switch (c) {
        case 'r': return RED;
        case 'b': return BLUE;
        case 'y': return YELLOW;
        case 'g': return GREEN;
        default:  return 0xFF;
    }
}

static char colorToChar(uint8_t c) {
    constexpr char chars[] = "rbyg";
    return (c < 4) ? chars[c] : '?';
}

static uint8_t charToPiece(char c) {
    switch (c) {
        case 'P': return PAWN;
        case 'N': return KNIGHT;
        case 'B': return BISHOP;
        case 'R': return ROOK;
        case 'K': return KING;
        default:  return 0xFF;
    }
}

static char pieceToChar(uint8_t p) {
    switch (p) {
        case PAWN:   return 'P';
        case KNIGHT: return 'N';
        case BISHOP: return 'B';
        case ROOK:   return 'R';
        case KING:   return 'K';
        default:     return '?';
    }
}

// ============================================================
// FEN Loading
// ============================================================
bool Board::load(const std::string& fen) {
    // Split by whitespace
    std::istringstream iss(fen);
    std::string position, pointsStr, turnStr;
    if (!(iss >> position >> pointsStr >> turnStr)) return false;

    clear();

    // Parse board position
    int square = 0;
    for (size_t i = 0; i < position.size(); i++) {
        char c = position[i];
        if (c == '/') {
            square += 8;  // skip to next rank (0x88 padding)
        } else if (isDigit(c)) {
            square += (c - '0');
        } else {
            bool isDead = (c == '*');
            if (isDead) {
                c = position[++i];
            }
            uint8_t color = charToColor(c);
            uint8_t piece = charToPiece(position[++i]);
            if (piece == KING) {
                if (!isDead) setColorLive(color);
            }
            board[square] = color | piece;
            if (isDead) {
                board[square] |= DEAD;
            }
            square++;
        }
    }

    // Parse points "r/b/y/g"
    std::istringstream pss(pointsStr);
    std::string tok;
    for (int i = 0; i < 4 && std::getline(pss, tok, '/'); i++) {
        points[i] = std::stoi(tok);
    }

    // Parse turn and optional ply
    turn = charToColor(turnStr[0]);
    if (iss >> tok) {
        ply = std::stoi(tok);
    } else {
        ply = 0;
    }

    nnue_acc.zero();

    return true;
}

// ============================================================
// FEN Generation
// ============================================================
std::string Board::generateFen() const {
    std::string fen;
    int emptyCount = 0;

    for (int i = SQ_A8; i <= SQ_H1; i++) {
        if (board[i] == EMPTY) {
            emptyCount++;
        } else {
            if (emptyCount > 0) {
                fen += std::to_string(emptyCount);
                emptyCount = 0;
            }
            if (board[i] & DEAD) fen += '*';
            fen += colorToChar(board[i] & COLOR_MASK);
            fen += pieceToChar(board[i] & PIECE_MASK);
        }

        if (((i + 1) & 0x88) != 0) {
            if (emptyCount > 0) {
                fen += std::to_string(emptyCount);
                emptyCount = 0;
            }
            if (i != SQ_H1) fen += '/';
            i += 8;  // skip 0x88 padding
        }
    }

    // Points
    fen += ' ';
    fen += std::to_string(points[RED]) + '/' +
           std::to_string(points[BLUE]) + '/' +
           std::to_string(points[YELLOW]) + '/' +
           std::to_string(points[GREEN]);

    // Turn
    fen += ' ';
    fen += colorToChar(turn);

    // Ply
    fen += ' ';
    fen += std::to_string(ply);

    return fen;
}

// ============================================================
// Move Generation
// ============================================================
int Board::generateMoves(Move* moves) const {
    int count = 0;

    if (turn == GAME_OVER) return 0;

    for (int from = SQ_A8; from <= SQ_H1; from++) {
        if ((from & 0x88) != 0) { from += 7; continue; }

        uint8_t piece = board[from];
        if (piece == EMPTY || (piece & COLOR_MASK) != turn) continue;
        if (piece & DEAD) continue;

        uint8_t pieceType = piece & PIECE_MASK;

        if (pieceType == PAWN) {
            // Push
            int to = from + PAWN_OFFSETS[turn][0];
            if ((to & 0x88) == 0 && board[to] == EMPTY) {
                moves[count++] = {from, to};
            }
            // Captures
            for (int j = 1; j <= 2; j++) {
                to = from + PAWN_OFFSETS[turn][j];
                if ((to & 0x88) != 0) continue;
                if (board[to] != EMPTY && (board[to] & COLOR_MASK) != turn) {
                    moves[count++] = {from, to};
                }
            }
        } else {
            const int* offsets;
            int numOffsets;
            bool slider;

            switch (pieceType) {
                case KNIGHT: offsets = KNIGHT_OFFSETS; numOffsets = 8; slider = false; break;
                case BISHOP: offsets = BISHOP_OFFSETS; numOffsets = 4; slider = true;  break;
                case ROOK:   offsets = ROOK_OFFSETS;   numOffsets = 4; slider = true;  break;
                case KING:   offsets = KING_OFFSETS;    numOffsets = 8; slider = false; break;
                default: continue;
            }

            for (int d = 0; d < numOffsets; d++) {
                int to = from;
                while (true) {
                    to += offsets[d];
                    if ((to & 0x88) != 0) break;

                    if (board[to] == EMPTY) {
                        moves[count++] = {from, to};
                    } else {
                        if ((board[to] & COLOR_MASK) != turn) {
                            moves[count++] = {from, to};
                        }
                        break;
                    }

                    if (!slider) break;
                }
            }
        }
    }

    // Resign is always an option
    moves[count++] = RESIGN_MOVE;
    return count;
}

// ============================================================
// Make Move
// ============================================================
void Board::makeMove(const Move& move, const NNUEModel* nnue) {
    if (undoCount >= 1024) return; // Safety check

    UndoInfo& undo = undoStack[undoCount++];
    undo.move = move;
    memcpy(undo.points, points, sizeof(points));
    undo.turn = turn;
    undo.liveColors = liveColors;
    undo.captured = EMPTY;
    undo.movedPiece = EMPTY;
    undo.promoted = 0;
    undo.newChecks = 0;
    undo.deadCount = 0;

    // Initialize accumulator if needed
    if (nnue && !nnue_acc.initialized) {
        nnue->refresh_accumulator(*this, nnue_acc);
    }

    // Identify kings in check BEFORE move
    uint32_t kingsInCheckBefore = 0;
    for (uint8_t color = 0; color < 4; color++) {
        if (color == turn || !isColorLive(color)) continue;
        if (isKingInCheck(color)) {
            kingsInCheckBefore |= (1u << color);
        }
    }

    if (move == RESIGN_MOVE) {
        markDead(turn, nnue, -1);
        undo.deadColors[undo.deadCount++] = turn;
    } else {
        undo.captured = board[move.to];
        undo.movedPiece = board[move.from];

        // 1. NNUE: Remove the moved piece and captured piece
        if (nnue) {
            nnue->update_feature(nnue_acc, board[move.from] & COLOR_MASK, board[move.from] & PIECE_MASK, move.from, false, false);
            if (board[move.to] != EMPTY) {
                nnue->update_feature(nnue_acc, board[move.to] & COLOR_MASK, board[move.to] & PIECE_MASK, move.to, (board[move.to] & DEAD) != 0, false);
            }
        }

        // 2. Points for capture
        if (board[move.to] != EMPTY) {
            points[turn] += capturePoints(board[move.to]);
        }

        // 3. King capture → mark color dead
        if ((board[move.to] & PIECE_MASK) == KING && !(board[move.to] & DEAD)) {
            uint8_t dc = board[move.to] & COLOR_MASK;
            // The king is physically being REMOVED from the board in the next step
            // because board[move.to] is overwritten. 
            // markDead will transition ALL OTHER pieces of dc to DEAD.
            // It will also skip move.to because we're about to put something else there.
            markDead(dc, nnue, move.to);
            undo.deadColors[undo.deadCount++] = dc;
        }

        // 4. Actually perform the move on the board
        board[move.to] = board[move.from];
        board[move.from] = EMPTY;

        // 5. Promotion
        if ((board[move.to] & PIECE_MASK) == PAWN) {
            bool promotes = false;
            switch (board[move.to] & COLOR_MASK) {
                case RED:    promotes = (move.to <= 7); break;
                case BLUE:   promotes = ((move.to & 7) == 7); break;
                case YELLOW: promotes = (move.to >= 112); break;
                case GREEN:  promotes = ((move.to & 7) == 0); break;
            }
            if (promotes) {
                undo.promoted = board[move.to];
                board[move.to] = (board[move.to] & COLOR_MASK) | ROOK;
            }
        }

        // 6. NNUE: Add the piece at its new location (after promotion)
        if (nnue) {
            nnue->update_feature(nnue_acc, board[move.to] & COLOR_MASK, board[move.to] & PIECE_MASK, move.to, false, true);
        }

        // 7. Check bonuses
        int newChecks = 0;
        for (uint8_t color = 0; color < 4; color++) {
            if (color == turn || !isColorLive(color)) continue;
            bool wasBefore = (kingsInCheckBefore & (1u << color)) != 0;
            bool isNow = isKingInCheck(color);
            if (isNow && !wasBefore) newChecks++;
        }

        if (newChecks == 2) { points[turn] += 1; undo.newChecks = 1; }
        else if (newChecks == 3) { points[turn] += 5; undo.newChecks = 5; }
    }

    // Advance turn
    if (popCount() <= 1) {
        if (popCount() == 1) {
            for (uint8_t c = 0; c < 4; c++) {
                if (isColorLive(c)) { deadKingPoints(c); break; }
            }
        }
        turn = GAME_OVER;
    } else {
        do {
            turn = (turn + 1) & COLOR_MASK;
        } while (!isColorLive(turn));
    }
    ply++;
}

// ============================================================
// Unmake Move
// ============================================
void Board::unmakeMove(const NNUEModel* nnue) {
    if (undoCount <= 0) return;
    UndoInfo& undo = undoStack[--undoCount];

    // NNUE: Remove the moved piece from its final location
    if (undo.move != RESIGN_MOVE && nnue) {
        nnue->update_feature(nnue_acc, board[undo.move.to] & COLOR_MASK, board[undo.move.to] & PIECE_MASK, undo.move.to, false, false);
    }

    // Restore board state for any colors marked dead
    for (int d = 0; d < undo.deadCount; d++) {
        uint8_t deadColor = undo.deadColors[d];
        for (int i = 0; i < 128; i++) {
            if (i & 0x88) { i += 7; continue; }
            if (board[i] != EMPTY && (board[i] & COLOR_MASK) == deadColor) {
                // Skip the captured king at move.to, it is restored below.
                if (nnue && (board[i] & DEAD) && (undo.move == RESIGN_MOVE || i != undo.move.to)) {
                    nnue->update_feature(nnue_acc, board[i] & COLOR_MASK, board[i] & PIECE_MASK, i, true, false);
                    nnue->update_feature(nnue_acc, board[i] & COLOR_MASK, board[i] & PIECE_MASK, i, false, true);
                }
                board[i] &= ~DEAD;
            }
        }
    }

    // NNUE: Restore moved piece and captured piece
    if (undo.move != RESIGN_MOVE && nnue) {
        nnue->update_feature(nnue_acc, undo.movedPiece & COLOR_MASK, undo.movedPiece & PIECE_MASK, undo.move.from, false, true);
        if (undo.captured != EMPTY) {
            nnue->update_feature(nnue_acc, undo.captured & COLOR_MASK, undo.captured & PIECE_MASK, undo.move.to, (undo.captured & DEAD) != 0, true);
        }
    }

    turn = undo.turn;
    liveColors = undo.liveColors;
    memcpy(points, undo.points, sizeof(points));
    ply--;

    if (undo.move != RESIGN_MOVE) {
        if (undo.promoted != 0) {
            board[undo.move.to] = undo.promoted;
        }
        board[undo.move.from] = undo.movedPiece;
        board[undo.move.to] = undo.captured;
    }
}

// ============================================================
// King / Check detection
// ============================================================
int Board::getKingSquare(uint8_t color) const {
    for (int i = SQ_A8; i <= SQ_H1; i++) {
        if ((i & 0x88) != 0) { i += 7; continue; }
        if (board[i] == (color | KING)) return i;
    }
    return -1;
}

bool Board::isKingInCheck(uint8_t color) const {
    int kingSq = getKingSquare(color);
    if (kingSq == -1) return false;
    uint32_t attackers = liveColors & ~(1u << color);
    return isSquareAttacked(kingSq, attackers);
}

bool Board::isSquareAttacked(int square, uint32_t byColors) const {
    for (int d = 0; d < 8; d++) {
        int pos = square + KNIGHT_OFFSETS[d];
        if ((pos & 0x88) == 0) {
            uint8_t p = board[pos];
            if (p != EMPTY && !(p & DEAD) && (p & PIECE_MASK) == KNIGHT && (byColors & (1u << (p & COLOR_MASK)))) return true;
        }
    }
    for (int d = 0; d < 8; d++) {
        int pos = square + KING_OFFSETS[d];
        if ((pos & 0x88) == 0) {
            uint8_t p = board[pos];
            if (p != EMPTY && !(p & DEAD) && (p & PIECE_MASK) == KING && (byColors & (1u << (p & COLOR_MASK)))) return true;
        }
    }
    struct { const int* offsets; int count; uint8_t type; } sliders[] = {{ROOK_OFFSETS, 4, ROOK}, {BISHOP_OFFSETS, 4, BISHOP}};
    for (auto& s : sliders) {
        for (int d = 0; d < s.count; d++) {
            int pos = square;
            while (true) {
                pos += s.offsets[d];
                if ((pos & 0x88) != 0) break;
                uint8_t p = board[pos];
                if (p != EMPTY) {
                    if (!(p & DEAD) && (p & PIECE_MASK) == s.type && (byColors & (1u << (p & COLOR_MASK)))) return true;
                    break;
                }
            }
        }
    }
    for (uint8_t color = 0; color < 4; color++) {
        if (!(byColors & (1u << color))) continue;
        for (int j = 1; j <= 2; j++) {
            int pos = square - PAWN_OFFSETS[color][j];
            if ((pos & 0x88) == 0) {
                uint8_t p = board[pos];
                if (p != EMPTY && !(p & DEAD) && (p & PIECE_MASK) == PAWN && (p & COLOR_MASK) == color) return true;
            }
        }
    }
    return false;
}

// ============================================================
// Material
// ============================================================
int Board::getMaterial(uint8_t color) const {
    int total = 0;
    for (int i = SQ_A8; i <= SQ_H1; i++) {
        if ((i & 0x88) != 0) { i += 7; continue; }
        uint8_t p = board[i];
        if (p != EMPTY && (p & COLOR_MASK) == color && !(p & DEAD)) total += capturePoints(p);
    }
    return total;
}

// ============================================================
// Internal helpers
// ============================================================
void Board::markDead(uint8_t deadColor, const NNUEModel* nnue, int skip_sq) {
    for (int i = SQ_A8; i <= SQ_H1; i++) {
        if ((i & 0x88) != 0) { i += 7; continue; }
        if (board[i] != EMPTY && (board[i] & COLOR_MASK) == deadColor) {
            if (nnue && !(board[i] & DEAD) && i != skip_sq) {
                nnue->update_feature(nnue_acc, board[i] & COLOR_MASK, board[i] & PIECE_MASK, i, false, false);
                nnue->update_feature(nnue_acc, board[i] & COLOR_MASK, board[i] & PIECE_MASK, i, true, true);
            }
            board[i] |= DEAD;
        }
    }
    setColorDead(deadColor);
}

void Board::deadKingPoints(uint8_t color) {
    for (int i = SQ_A8; i <= SQ_H1; i++) {
        if ((i & 0x88) != 0) { i += 7; continue; }
        if ((board[i] & (DEAD | PIECE_MASK)) == (DEAD | KING)) points[color] += 3;
    }
}
