import 'board.dart';

/// Weights for the hand-crafted evaluation components.
/// Grouped here for easy tuning.
class EvalWeights {
  // How much earned points matter (locked-in, most valuable)
  static const double pointsWeight = 3.0;

  // Material on board (potential future points)
  static const double materialWeight = 1.0;

  // Pawn advancement scaling factor
  static const double pawnAdvancementWeight = 0.5;

  // Centrality bonus for non-pawn, non-king pieces
  static const double centralityWeight = 0.3;

  // King safety
  static const double checkPenalty = -5.0;
  static const double nearbyEnemyPenalty = -1.0;
  static const double nearbyFriendlyBonus = 0.3;

  // Dead player base penalty
  static const double deadPenalty = -50.0;
}

/// Hand-crafted evaluation function for Chaturaji.
///
/// Returns a [List<double>] with 4 values, one per player
/// (red=0, blue=1, yellow=2, green=3). Higher values are better
/// for that player.
///
/// Components:
///   1. Earned points (locked-in, highest weight)
///   2. Material on board (potential future captures)
///   3. Pawn advancement (quadratic — promotion threats are valuable)
///   4. Centrality bonus for pieces (knights, bishops, rooks)
///   5. King safety (check penalty, nearby attackers)
List<double> evaluate(Board board) {
  final scores = [0.0, 0.0, 0.0, 0.0];

  for (int color = 0; color < 4; color++) {
    if (!board.liveColors.contains(color)) {
      // Dead player: just their earned points plus a large penalty.
      // Their ranking is determined by points already scored.
      scores[color] =
          board.points[color] * EvalWeights.pointsWeight +
          EvalWeights.deadPenalty;
      continue;
    }

    double score = 0.0;

    // 1. Earned points (most important — these are locked in)
    score += board.points[color] * EvalWeights.pointsWeight;

    // 2. Material on board (potential future captures → future points)
    score += board.getMaterial(color) * EvalWeights.materialWeight;

    // 3–4. Per-piece positional bonuses
    for (int sq = squaresA8; sq <= squaresH1; sq++) {
      if ((sq & 0x88) != 0) {
        sq += 7;
        continue;
      }

      final piece = board.board[sq];
      if (piece == empty) continue;
      if ((piece & dead) != 0) continue; // dead pieces can't move
      if ((piece & colorMask) != color) continue;

      final pieceType = piece & pieceMask;
      final row = sq >> 4;
      final col = sq & 7;

      // 3. Pawn advancement — quadratic scaling rewards promotion threats
      if (pieceType == pawn) {
        score += _pawnAdvancement(color, row, col);
      }

      // 4. Centrality bonus for knights, bishops, rooks
      if (pieceType == knight || pieceType == bishop || pieceType == rook) {
        score += _centralityBonus(row, col);
      }
    }

    // 5. King safety
    score += _kingSafety(board, color);

    scores[color] = score;
  }

  return scores;
}

/// Pawn advancement bonus.
///
/// Each color's pawns advance in a different direction:
///   Red:    north  (row 6 → row 0, promotes at row 0)
///   Blue:   east   (col 1 → col 7, promotes at col 7)
///   Yellow: south  (row 1 → row 7, promotes at row 7)
///   Green:  west   (col 6 → col 0, promotes at col 0)
///
/// Returns a quadratic bonus: advancement² × weight.
/// This makes promotion threats disproportionately valuable.
double _pawnAdvancement(int color, int row, int col) {
  int advancement;

  switch (color) {
    case red:
      advancement = 6 - row; // row 6=0, row 0=6
      break;
    case blue:
      advancement = col - 1; // col 1=0, col 7=6
      break;
    case yellow:
      advancement = row - 1; // row 1=0, row 7=6
      break;
    case green:
      advancement = 6 - col; // col 6=0, col 0=6
      break;
    default:
      advancement = 0;
  }

  // Clamp to valid range
  if (advancement < 0) advancement = 0;
  if (advancement > 6) advancement = 6;

  return advancement * advancement * EvalWeights.pawnAdvancementWeight;
}

/// Centrality bonus for a piece at (row, col).
///
/// The center of the 8×8 board (around d4/d5/e4/e5) is strategically
/// valuable for all players. Bonus decreases with Manhattan distance
/// from center.
double _centralityBonus(int row, int col) {
  // Distance from center (3.5, 3.5) using Manhattan distance
  final dr = (row - 3.5).abs();
  final dc = (col - 3.5).abs();
  final dist = dr + dc;

  // Max Manhattan distance from center is 7 (corner).
  // Bonus ranges from ~2.1 (center) to 0 (corner).
  return (7.0 - dist) * EvalWeights.centralityWeight;
}

/// King safety evaluation.
///
/// Considers:
///   - Whether the king is currently in check (large penalty)
///   - Number of enemy pieces within 2 squares (penalty per enemy)
///   - Number of friendly pieces within 2 squares (small bonus, shielding)
double _kingSafety(Board board, int color) {
  final kingSquare = board.getKingSquare(color);
  if (kingSquare == -1) return -100.0; // shouldn't happen for live players

  double safety = 0.0;

  // Penalty for being in check
  if (board.isKingInCheck(color)) {
    safety += EvalWeights.checkPenalty;
  }

  // Count pieces within 2 squares of the king
  final kingRow = kingSquare >> 4;
  final kingCol = kingSquare & 7;

  for (int dr = -2; dr <= 2; dr++) {
    for (int dc = -2; dc <= 2; dc++) {
      if (dr == 0 && dc == 0) continue;
      final r = kingRow + dr;
      final c = kingCol + dc;
      if (r < 0 || r > 7 || c < 0 || c > 7) continue;

      final sq = r * 16 + c;
      final piece = board.board[sq];
      if (piece == empty || (piece & dead) != 0) continue;

      if ((piece & colorMask) == color) {
        safety += EvalWeights.nearbyFriendlyBonus;
      } else {
        safety += EvalWeights.nearbyEnemyPenalty;
      }
    }
  }

  return safety;
}
