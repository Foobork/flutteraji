// ignore_for_file: avoid_print
import 'dart:math';
import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/chaturaji/eval.dart';
import 'package:flutteraji/chaturaji/move.dart';
import 'package:flutteraji/graph/graph.dart';
import 'package:flutteraji/graph/vertex.dart';

class MCTS {
  final Random _random = Random();

  void search(Board rootBoard, int iterations) {
    for (int i = 0; i < iterations; i++) {
      Board board = Board.copy(rootBoard);
      List<SearchStep> path = [];

      // 1. Selection
      while (true) {
        String fen = board.generateFen();
        Vertex vertex = graph.addVertex(fen);
        List<Move> legalMoves = board.generateMoves();

        // Check if node is terminal or not fully expanded
        if (board.turn == gameOver || vertex.edges.length < legalMoves.length) {
          path.add(SearchStep(fen, null));
          break;
        }

        // UCT Selection
        Move bestMove = _selectMove(board, vertex, legalMoves);
        path.add(SearchStep(fen, bestMove));
        board.makeMove(bestMove);
      }

      // 2. Expansion
      if (board.turn != gameOver) {
        String fen = path.last.fen;
        Vertex vertex = graph.v[fen]!;
        List<Move> legalMoves = board.generateMoves();

        List<Move> unexpandedMoves = legalMoves
            .where((m) => !vertex.edges.containsKey(m))
            .toList();
        if (unexpandedMoves.isNotEmpty) {
          Move move = unexpandedMoves[_random.nextInt(unexpandedMoves.length)];
          vertex.edges[move] = 0; // Initialize edge
          // Update path with the move taken from the LAST fen
          path.last.move = move;
          board.makeMove(move);
          // Add the NEW fen to path
          path.add(SearchStep(board.generateFen(), null));
        }
      }

      // 3. Evaluation (direct — no rollout, AlphaZero-style)
      List<int> rankPoints;
      if (board.turn == gameOver) {
        rankPoints = _calculateRankPoints(board.points);
      } else {
        final evalScores = evaluate(board);
        rankPoints = _calculateRankPoints(
            List.generate(4, (i) => evalScores[i].round()));
      }

      // 4. Backpropagation
      _backpropagate(path, rankPoints);
    }
  }

  Move _selectMove(Board board, Vertex vertex, List<Move> legalMoves) {
    double bestVal = -double.infinity;
    Move? bestMove;
    int turn = board.turn;

    // Pre-calculate to avoid redundant math
    double logN = log(max(1, vertex.N));

    for (Move move in legalMoves) {
      Board nextBoard = Board.copy(board);
      nextBoard.makeMove(move);
      String nextFen = nextBoard.generateFen();
      Vertex? child = graph.v[nextFen];

      double uctValue;
      if (child == null || child.N == 0) {
        uctValue = 10000.0 + _random.nextDouble(); // High value for unvisited
      } else {
        double exploitation = child.Q[turn] / child.N.toDouble();
        double exploration = 12.0 * sqrt(logN / child.N);
        uctValue = exploitation + exploration;
      }

      if (uctValue > bestVal) {
        bestVal = uctValue;
        bestMove = move;
      }
    }

    return bestMove ?? legalMoves[_random.nextInt(legalMoves.length)];
  }

  void _backpropagate(List<SearchStep> path, List<int> rankPoints) {
    for (int i = 0; i < path.length; i++) {
      String fen = path[i].fen;
      Vertex vertex = graph.addVertex(fen);
      vertex.N++;
      for (int color = 0; color < 4; color++) {
        vertex.Q[color] += rankPoints[color];
      }

      // Update edge statistics
      Move? moveTaken = path[i].move;
      if (moveTaken != null) {
        vertex.edges[moveTaken] = (vertex.edges[moveTaken] ?? 0) + 1;
      }
    }
  }

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

class SearchStep {
  String fen;
  Move? move;
  SearchStep(this.fen, this.move);
}
