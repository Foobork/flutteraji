// ignore_for_file: avoid_print

import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/chaturaji/move.dart';
import 'package:flutteraji/chaturaji/mcts.dart';
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
    // Get final raw points for each player
    List<int> finalPoints = List.from(board.points);

    // Convert raw points to rank-based points with tie averaging
    // Ranks: 1st=6, 2nd=4, 3rd=2, 4th=0; ties share the average of tied places
    List<int> rankPoints = _calculateRankPoints(finalPoints);

    print(
      "Game Over! Final points: Red=${finalPoints[0]}, Blue=${finalPoints[1]}, Yellow=${finalPoints[2]}, Green=${finalPoints[3]}",
    );
    print(
      "Backpropagating scores through ${fenHistory.length + 1} positions...",
    );

    // Add the final position FEN
    List<String> allFens = [];
    allFens.addAll(fenHistory);
    allFens.add(board.generateFen());

    // Backpropagate through all positions in the game
    for (int i = 0; i < allFens.length; i++) {
      String fen = allFens[i];
      Vertex vertex = graph.addVertex(fen);

      // Increment N for this vertex
      vertex.N++;

      // Add final rank points to Q values for each player
      for (int color = 0; color < 4; color++) {
        vertex.Q[color] += rankPoints[color];
      }

      // If this isn't the last position, increment the N count for the edge that was taken
      if (i < moveHistory.length) {
        Move move = moveHistory[i];
        if (vertex.edges.containsKey(move)) {
          vertex.edges[move] = (vertex.edges[move] ?? 0) + 1;
        }
      }

      print("Updated vertex $i: N=${vertex.N}, Q=${vertex.Q}");
    }

    print("Backpropagation complete!");
  }

  // Compute rank-based points with tie averaging
  List<int> _calculateRankPoints(List<int> finalPoints) {
    const List<int> placePoints = [6, 4, 2, 0];

    // Create list of (index, score)
    final indexed = List.generate(4, (i) => MapEntry(i, finalPoints[i]));
    // Sort descending by score
    indexed.sort((a, b) => b.value.compareTo(a.value));

    List<int> result = List.filled(4, 0);

    int i = 0;
    while (i < 4) {
      // Find tie group with same score
      int j = i;
      while (j < 4 && indexed[j].value == indexed[i].value) {
        j++;
      }
      // Places covered are i..j-1 (0-based). Average corresponding placePoints.
      int sum = 0;
      for (int p = i; p < j; p++) {
        sum += placePoints[p];
      }
      int avg = sum ~/ (j - i);
      for (int p = i; p < j; p++) {
        result[indexed[p].key] = avg;
      }
      i = j;
    }

    return result;
  }

  // Manual trigger for backpropagation (useful for testing)
  void manualBackpropagate() {
    if (board.turn == gameOver) {
      backpropagateScores();
    } else {
      print("Game is not over yet. Cannot backpropagate.");
    }
  }

  void runMCTS(int iterations) {
    if (board.turn == gameOver) {
      print("Game is already over.");
      return;
    }
    print("Running MCTS for $iterations iterations...");
    MCTS().search(board, iterations);
    print("MCTS search complete.");
  }
}
