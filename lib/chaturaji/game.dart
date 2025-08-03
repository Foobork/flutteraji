// ignore_for_file: avoid_print

import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/chaturaji/move.dart';

class ChaturajiGame {
  Board board = Board()..reset();
  List<Board> history = [];

  void makeSanMove(String move) {
    makeMove(Move.fromSan(move));
  }

  void makeMove(Move move) {
    history.add(Board.copy(board));
    board.move(move);
  }

  void undoMove() {
    if (history.isNotEmpty) {
      board = history.removeLast();
    }
  }

  void reset() {
    board.reset();
    history.clear();
  }

  List<Move> generateMoves() {
    // Implement the logic to generate all possible moves
    // This could involve checking the current board state and available pieces
    return board.generateMoves();
  }

  String generateFen() {
    // Generate a FEN string representing the current board state
    return board.generateFen();
  }
}
