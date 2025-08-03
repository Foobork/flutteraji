// ignore_for_file: avoid_print

import 'package:flutteraji/chaturaji/board.dart';
import 'package:test/test.dart';

void main() {
  test('FEN load/save', () {
    Board board = Board();
    board.load(startPosition);
    expect(board.generateFen(), startPosition);
  });
}
