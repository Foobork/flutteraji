// ignore_for_file: avoid_print

import 'package:flutteraji/chaturaji/chaturaji_board.dart';
import 'package:flutteraji/chaturaji/chaturaji_move.dart';

class ChaturajiGame {

  ChaturajiBoard board = ChaturajiBoard()..reset();
  List<ChaturajiBoard> history = [];

  void makeMove(String move) {
    makeChaturajiMove(ChaturajiMove.fromSan(move));
  }

  void makeChaturajiMove(ChaturajiMove move) {
    history.add(ChaturajiBoard.copy(board));
    board.move(move);
  }

  void undoMove() {
    if (history.isNotEmpty) {
      board = history.removeLast();
    }
  }

  List<ChaturajiMove> generateMoves() {
    // Implement the logic to generate all possible moves
    // This could involve checking the current board state and available pieces
    return board.generateMoves();
  }

  String get fen {
    // Generate a FEN string representing the current board state
    return board.generateFen();
  }
}
