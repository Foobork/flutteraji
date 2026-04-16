// Dart perft validation against C++ reference numbers
import 'dart:io';
import 'package:flutteraji/chaturaji/board.dart';

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
  final expected = [9, 81, 729, 6553, 75761, 874122];
  bool allPass = true;
  for (int d = 1; d <= 6; d++) {
    final board = Board()..reset();
    final nodes = perft(board, d);
    final ok = nodes == expected[d - 1];
    if (!ok) allPass = false;
    stdout.writeln('Depth $d: $nodes ${ok ? '(OK)' : '(MISMATCH, expected ${expected[d - 1]})'}');
  }
  if (allPass) {
    stdout.writeln('Dart perft matches C++ reference for depths 1-6.');
  } else {
    stdout.writeln('Dart perft does NOT match C++ reference.');
  }
}
