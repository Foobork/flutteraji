// ignore_for_file: avoid_print

import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/chaturaji/move.dart';
import 'package:flutteraji/graph/vertex.dart';
import 'package:flutteraji/graph/graph.dart';

class ChaturajiGame {
  Board board = Board()..reset();
  List<Board> history = [];
  List<Move> moveHistory = [];
  List<String> fenHistory = [];

  void makeSanMove(String move) {
    makeMove(sanToMove(move));
  }

  void makeMove(Move move) {
    history.add(Board.copy(board));
    fenHistory.add(board.generateFen());
    moveHistory.add(move);
    board.makeMove(move);

    // Check if game is over and backpropagate scores
    if (board.turn == gameOver) {
      backpropagateScores();
    }
  }

  void undoMove() {
    if (history.isNotEmpty) {
      board = history.removeLast();
      if (moveHistory.isNotEmpty) {
        moveHistory.removeLast();
      }
      if (fenHistory.isNotEmpty) {
        fenHistory.removeLast();
      }
    }
  }

  void reset() {
    board.reset();
    history.clear();
    moveHistory.clear();
    fenHistory.clear();
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

  void backpropagateScores() {
    // Get final points for each player
    List<int> finalPoints = List.from(board.points);

    print(
      "Game Over! Final points: Red=${finalPoints[0]}, Blue=${finalPoints[1]}, Yellow=${finalPoints[2]}, Green=${finalPoints[3]}",
    );
    print(
      "Backpropagating scores through ${fenHistory.length + 1} positions...",
    );

    // Add the starting position FEN
    List<String> allFens = [board.generateFen()];
    allFens.addAll(fenHistory);

    // Backpropagate through all positions in the game
    for (int i = 0; i < allFens.length; i++) {
      String fen = allFens[i];
      Vertex vertex = graph.addVertex(
        fen,
      ); // This will create the vertex if it doesn't exist

      // Increment N for this vertex
      vertex.N++;

      // Add final points to Q values for each player
      for (int color = 0; color < 4; color++) {
        vertex.Q[color] += finalPoints[color];
      }

      print("Updated vertex $i: N=${vertex.N}, Q=${vertex.Q}");
    }

    print("Backpropagation complete!");
  }

  // Manual trigger for backpropagation (useful for testing)
  void manualBackpropagate() {
    if (board.turn == gameOver) {
      backpropagateScores();
    } else {
      print("Game is not over yet. Cannot backpropagate.");
    }
  }
}
