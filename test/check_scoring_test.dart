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

    test('Double Check (+1 point)', () {
      // Setup: Red Rook at d4 (67)
      // Blue King at d8 (3)
      // Yellow King at h4 (71)
      // Green King safe

      board.clear();
      board.liveColors = {red, blue, yellow, green};
      board.board[squaresA8] = red | king;
      board.board[3] = blue | king; // d8
      board.board[71] = yellow | king; // h4
      board.board[7] = green | king; // h8

      // Red Rook moves from d3 (83) to d4 (67)
      // Checks Blue King at d8 (file d)
      // Checks Yellow King at h4 (rank 4)
      board.board[83] = red | rook;
      board.turn = red;

      final move = Move(83, 67);
      board.makeMove(move);

      expect(board.points[red], 1, reason: "Should get +1 for double check");
    });

    test('Triple Check (+5 points)', () {
      // Setup: Red Queen-like piece? No queens.
      // Need a setup where one piece checks multiple, or multiple pieces check.
      // E.g. Red Rook moves to check Blue and Yellow, and unblocks a Green Bishop to check Green? No, unblocks a Red Bishop?
      // Or simply Red Rook checks Blue (file) and Yellow (rank), and maybe unblocks something else?
      // Let's try:
      // Red Rook at d4 checks Blue(d8) and Yellow(h4).
      // And Red Bishop at a1 checks Green(h8) via diagonal?
      // Wait, unblocking implies the piece *moving* was blocking.
      // So Red Rook moves from e4 to d4.
      // e4 was blocking a Red Bishop at f3 from checking Green at c6?

      // Let's construct a simpler triple check if possible with one piece?
      // Rook can check 2 max (rank + file).
      // Bishop can check 2 max (diagonals).
      // Knight can check up to 8, but distinct kings? Yes.
      // Knight at e5 could check:
      // c6 (Blue King), g6 (Yellow King), d7 (Green King).

      board.clear();
      board.liveColors = {red, blue, yellow, green};
      board.board[squaresA1] = red | king;

      // Knight at e5 (52)
      // Targets:
      // c6 (34) -> Blue King
      // g6 (38) -> Yellow King
      // d7 (19) -> Green King

      board.board[34] = blue | king;
      board.board[38] = yellow | king;
      board.board[19] = green | king;

      // Red Knight moves from d3 (83) to e5 (52)
      board.board[83] = red | knight;
      board.turn = red;

      final move = Move(83, 52);
      board.makeMove(move);

      expect(board.points[red], 5, reason: "Should get +5 for triple check");
    });

    test('Assisted Double Check (Unblocking)', () {
      // Red moves Rook.
      // Rook checks Blue King.
      // Rook unblocks Yellow Rook which checks Green King.
      // Result: Blue and Green in check. Red gets +1.

      board.clear();
      board.liveColors = {red, blue, yellow, green};
      board.board[squaresA8] = red | king;

      // Blue King at d8 (3)
      // Green King at h4 (71)
      board.board[3] = blue | king;
      board.board[71] = green | king;

      // Yellow Rook at a4 (64). Checks rank 4 (Green King at h4).
      board.board[64] = yellow | rook;

      // Red Rook at b4 (65). Blocking Yellow Rook.
      board.board[65] = red | rook;

      // Red Rook moves to b8 (1). Checks Blue King at d8 (rank 8).
      // And unblocks Yellow Rook to check Green King.

      board.turn = red;
      final move = Move(65, 1);
      board.makeMove(move);

      // Verify Blue King is in check by Red Rook
      // Verify Green King is in check by Yellow Rook
      // Total 2 kings in check -> +1 for Red.

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
      board.board[83] = red | rook; // d3
      board.turn = red;

      final move = Move(83, 67); // d3 -> d4
      board.makeMove(move);

      expect(board.points[red], 0, reason: "Single check is worth 0");
    });
  });
}
