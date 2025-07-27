// ignore_for_file: avoid_print

import 'package:flutteraji/chaturaji/chaturaji_board.dart';
import 'package:test/test.dart';

void main() {
  test('FEN load/save', () {
    ChaturajiBoard board = ChaturajiBoard();
    board.load(startPosition);
    expect(board.generateFen(), startPosition);
  });
}
