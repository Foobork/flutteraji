// ignore_for_file: avoid_print
import 'dart:math';
import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/chaturaji/move.dart';
import 'package:flutteraji/graph/graph.dart';
import 'package:flutteraji/graph/vertex.dart';

class MCTS {
  final Random _random = Random();

  void search(Board rootBoard, int iterations) {
    for (int i = 0; i < iterations; i++) {
      Board board = Board.copy(rootBoard);
      List<String> path = [];
      path.add(board.generateFen());

      // 1. Selection
      while (true) {
        String fen = board.generateFen();
        Vertex vertex = graph.addVertex(fen);
        List<Move> legalMoves = board.generateMoves();

        // Check if node is terminal or not fully expanded
        if (board.turn == gameOver || vertex.edges.length < legalMoves.length) {
          break;
        }

        // UCT Selection
        Move bestMove = _selectMove(board, vertex, legalMoves);
        board.makeMove(bestMove);
        path.add(board.generateFen());
      }

      // 2. Expansion
      if (board.turn != gameOver) {
        String fen = board.generateFen();
        Vertex vertex = graph.addVertex(fen);
        List<Move> legalMoves = board.generateMoves();

        // Find moves not yet in the graph
        List<Move> unexpandedMoves = legalMoves
            .where((m) => !vertex.edges.containsKey(m))
            .toList();
        if (unexpandedMoves.isNotEmpty) {
          Move move = unexpandedMoves[_random.nextInt(unexpandedMoves.length)];
          vertex.edges[move] = 0; // Initialize edge
          board.makeMove(move);
          path.add(board.generateFen());
        }
      }

      // 3. Simulation
      List<int> rankPoints = _simulate(board);

      // 4. Backpropagation
      _backpropagate(path, rankPoints);
    }
  }

  Move _selectMove(Board board, Vertex vertex, List<Move> legalMoves) {
    double bestVal = -double.infinity;
    Move? bestMove;
    int turn = board.turn;

    for (Move move in legalMoves) {
      Board nextBoard = Board.copy(board);
      nextBoard.makeMove(move);
      String nextFen = nextBoard.generateFen();
      Vertex? child = graph.v[nextFen];

      double uctValue;
      if (child == null || child.N == 0) {
        uctValue = double.infinity;
      } else {
        // Maxn UCT: maximize the current player's Q
        double exploitation = child.Q[turn] / child.N.toDouble();
        double exploration = sqrt(2 * log(vertex.N) / child.N);
        uctValue = exploitation + exploration;
      }

      if (uctValue > bestVal) {
        bestVal = uctValue;
        bestMove = move;
      }
    }

    return bestMove ?? legalMoves[_random.nextInt(legalMoves.length)];
  }

  List<int> _simulate(Board board) {
    Board simBoard = Board.copy(board);
    while (simBoard.turn != gameOver) {
      List<Move> moves = simBoard.generateMoves();
      if (moves.isEmpty) break;
      simBoard.makeMove(moves[_random.nextInt(moves.length)]);
    }
    return _calculateRankPoints(simBoard.points);
  }

  void _backpropagate(List<String> path, List<int> rankPoints) {
    for (int i = 0; i < path.length; i++) {
      String fen = path[i];
      Vertex vertex = graph.addVertex(fen);
      vertex.N++;
      for (int color = 0; color < 4; color++) {
        vertex.Q[color] += rankPoints[color];
      }

      // Update edge info if possible (count transitions)
      if (i < path.length - 1) {
        // Technically we need to know WHICH move was taken to reach path[i+1]
        // In a more robust implementation, path would store (FEN, Move) pairs.
        // For now, we'll just increment N and Q on the vertices.
        // The existing GUI uses vertex.edges mostly for visualization.
      }
    }
  }

  // Copied from game.dart for consistency
  List<int> _calculateRankPoints(List<int> finalPoints) {
    const List<int> placePoints = [6, 4, 2, 0];
    final indexed = List.generate(4, (i) => MapEntry(i, finalPoints[i]));
    indexed.sort((a, b) => b.value.compareTo(a.value));
    List<int> result = List.filled(4, 0);
    int i = 0;
    while (i < 4) {
      int j = i;
      while (j < 4 && indexed[j].value == indexed[i].value) {
        j++;
      }
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
}
