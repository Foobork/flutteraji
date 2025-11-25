import 'package:flutter_test/flutter_test.dart';
import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/chaturaji/move.dart';

void main() {
  group('Check Scoring', () {
    late Board board;

    setUp(() {
      board = Board();
      board.clear();
      // Setup basic pieces for testing
      // Kings are required for liveColors
      board.liveColors = {red, blue, yellow, green};
      board.board[squaresA8] = red | king; // Red King at a8 (0)
      board.board[squaresH1] = blue | king; // Blue King at h1 (119)
      board.board[squaresA1] = yellow | king; // Yellow King at a1 (112)
      board.board[squaresH8] = green | king; // Green King at h8 (7)
      board.points = [0, 0, 0, 0];
      board.turn = red;
    });

    test('Double Check (+1 point) - Knight Fork', () {
      board.clear();
      board.liveColors = {red, blue, yellow, green};
      board.board[squaresA1] = red | king;

      // Kings at target squares
      board.board[34] = blue | king; // c6
      board.board[38] = yellow | king; // g6
      board.board[7] = green | king; // h8 (safe)

      // Red Knight at d3 (83).
      // Move to e5 (52).
      board.board[83] = red | knight;
      board.turn = red;

      final move = Move(83, 52);
      board.makeMove(move);

      // Knight at e5 checks c6 (Blue) and g6 (Yellow).
      // Both are NEW checks.
      expect(
        board.points[red],
        1,
        reason: "Should get +1 for double check (Knight fork)",
      );
    });

    test('Triple Check (+5 points) - Knight Fork', () {
      board.clear();
      board.liveColors = {red, blue, yellow, green};
      board.board[squaresA1] = red | king;

      // Kings at target squares for Knight at e5
      // Must ensure they don't attack each other!
      // c6 (34) and g6 (38) are safe.
      // f3 (85) is attacked by Knight at e5 (52 + 33 = 85).

      board.board[34] = blue | king; // c6
      board.board[38] = yellow | king; // g6
      board.board[85] = green | king; // f3

      // Red Knight at d3 (83).
      // Move to e5 (52).
      board.board[83] = red | knight;
      board.turn = red;

      final move = Move(83, 52);
      board.makeMove(move);

      expect(
        board.points[red],
        5,
        reason: "Should get +5 for triple check (Knight fork)",
      );
    });

    test('Assisted Double Check (Unblocking)', () {
      board.clear();
      board.liveColors = {red, blue, yellow, green};
      board.board[squaresA8] = red | king;

      // Blue King at d8 (3)
      // Green King at h4 (71)
      // Yellow King at h1 (119) - Just to be present
      board.board[3] = blue | king;
      board.board[71] = green | king;
      board.board[119] = yellow | king;

      // Yellow Rook at a4 (64). Checks rank 4 (Green King at h4).
      board.board[64] = yellow | rook;

      // Red Knight at b4 (65). Blocking Yellow Rook.
      // Knight does NOT check Green King at h4.
      board.board[65] = red | knight;

      // Red Knight moves to c6 (34). Checks Blue King at d8 (3)?
      // c6 (34) to d8 (3).
      // 34 - 3 = 31. Yes, Knight offset.
      // And unblocks Yellow Rook to check Green King.

      board.turn = red;
      final move = Move(65, 34);
      board.makeMove(move);

      expect(
        board.points[red],
        1,
        reason: "Should get +1 for assisted double check",
      );
    });

    test('Single Check (0 points)', () {
      board.clear();
      board.liveColors = {red, blue, yellow, green};
      board.board[squaresA8] = red | king;
      board.board[3] = blue | king; // d8

      // Red Rook moves to d4 checking Blue King
      // Ensure Blue King was NOT in check before.
      // Rook at c4 (66).
      // Move to d4 (67).
      // Checks d8 (Blue).

      board.board[66] = red | rook;
      board.turn = red;

      final move = Move(66, 67); // c4 -> d4
      board.makeMove(move);

      expect(board.points[red], 0, reason: "Single check is worth 0");
    });
  });
}
