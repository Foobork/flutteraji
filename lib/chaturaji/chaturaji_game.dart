// ignore_for_file: avoid_print

import 'package:flutteraji/chaturaji/chaturaji_board.dart';
import 'package:flutteraji/chaturaji/chaturaji_move.dart';

class ChaturajiGame {

  ChaturajiBoard board = ChaturajiBoard()..reset();

  void makeMove(dynamic move) {
    // Implement the logic to make a move
    // This could involve updating the board state, checking for valid moves, etc.
    print("Move made: $move");
  }

  void undoMove() {
    // Implement the logic to undo the last move
    print("Last move undone");
  }

  ChaturajiGame copy() {
    ChaturajiGame other = ChaturajiGame();
    board.copy(other.board);
    print("Game state copied");
    return other;
  }

  List<ChaturajiMove> generateMoves() {
    // Implement the logic to generate all possible moves
    // This could involve checking the current board state and available pieces
    print("Generating moves");
    return [];
  }

  String get fen {
    // Generate a FEN string representing the current board state
    return board.generateFen();
  }

  String moveToSan(ChaturajiMove move) {
    // Convert a move to Standard Algebraic Notation (SAN)
    // This could involve translating the move's from and to squares into a string format
    return "${move.from}-${move.to}";
  }
}
