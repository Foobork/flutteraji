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
          // Sort unexpanded moves so that highest tactical score is picked first
          unexpandedMoves.sort((a, b) =>
              _scoreMove(board, b).compareTo(_scoreMove(board, a)));
          Move move = unexpandedMoves.first;
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

  double _scoreMove(Board board, Move move) {
    if (move.from < 0 || move.to < 0) return 0.0001; // RESIGN_MOVE

    double score = 1.0;
    int movingPiece = board.board[move.from];
    int targetPiece = board.board[move.to];
    int movingType = movingPiece & pieceMask;
    int targetType = targetPiece & pieceMask;

    // 1. Captures (MVV-LVA)
    if (targetPiece != empty) {
      int victimVal = capturePoints[targetPiece] ?? 0;
      int attackerVal = capturePoints[movingPiece] ?? 0;
      score += 50.0 + (victimVal * 20.0) - (attackerVal * 1.0);
      if (targetType == king) {
        score += 100.0;
      }
    }

    // 2. Pawn Promotions
    if (movingType == pawn) {
      int to = move.to;
      bool isPromotion = false;
      switch (board.turn) {
        case red:
          isPromotion = (to <= 7);
          break;
        case blue:
          isPromotion = (to % 8 == 7);
          break;
        case yellow:
          isPromotion = (to >= 112);
          break;
        case green:
          isPromotion = (to % 8 == 0);
          break;
      }
      if (isPromotion) {
        score += 40.0;
      }
    }

    // 3. Center Control
    int toRow = move.to >> 4;
    int toCol = move.to & 0x07;
    if ((toRow == 3 || toRow == 4) && (toCol == 3 || toCol == 4)) {
      score += 2.0;
    } else if ((toRow >= 2 && toRow <= 5) && (toCol >= 2 && toCol <= 5)) {
      score += 1.0;
    }

    // 4. King Defense
    if (board.isKingInCheck(board.turn)) {
      if (movingType == king) {
        score += 30.0;
      } else if (targetPiece != empty) {
        score += 25.0;
      }
    }

    return max(0.001, score);
  }

  Move _selectMove(Board board, Vertex vertex, List<Move> legalMoves) {
    double bestVal = -double.infinity;
    Move? bestMove;
    int turn = board.turn;

    // Compute tactical move scores and sum for normalized priors
    double scoreSum = 0.0;
    List<double> scores = [];
    for (Move m in legalMoves) {
      double s = _scoreMove(board, m);
      scores.add(s);
      scoreSum += s;
    }
    if (scoreSum <= 0.0) scoreSum = 1.0;

    double sqrtSumN = sqrt(max(1.0, vertex.N.toDouble()));

    for (int i = 0; i < legalMoves.length; i++) {
      Move move = legalMoves[i];
      double prior = scores[i] / scoreSum;

      Board nextBoard = Board.copy(board);
      nextBoard.makeMove(move);
      String nextFen = nextBoard.generateFen();
      Vertex? child = graph.v[nextFen];

      double puctValue;
      if (child == null || child.N == 0) {
        puctValue = 10000.0 + (prior * 1000.0) + (_random.nextDouble() * 0.01);
      } else {
        double exploitation = child.Q[turn] / child.N.toDouble();
        double exploration = 12.0 * prior * (sqrtSumN / (1.0 + child.N));
        puctValue = exploitation + exploration;
      }

      if (puctValue > bestVal) {
        bestVal = puctValue;
        bestMove = move;
      }
    }

    return bestMove ?? legalMoves.first;
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
