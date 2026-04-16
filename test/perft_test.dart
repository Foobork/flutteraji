import 'package:flutteraji/chaturaji/board.dart';
import 'package:test/test.dart';

int perft(Board board, int depth) {
  if (depth == 0) return 1;
  if (board.turn == gameOver) return 1;
  final moves = board.generateMoves();
  var nodes = 0;
  for (final m in moves) {
    final copy = Board.copy(board);
    copy.makeMove(m);
    nodes += perft(copy, depth - 1);
  }
  return nodes;
}

void main() {
  test('Perft validation against C++ reference', () {
    final expected = [9, 81, 729, 6553, 75761, 874122];
    for (int d = 1; d <= 6; d++) {
      final board = Board()..reset();
      final nodes = perft(board, d);
      expect(nodes, expected[d - 1], reason: 'Depth $d');
    }
  });
}
