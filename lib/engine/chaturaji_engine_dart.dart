import 'dart:math';
import 'dart:typed_data';
import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/chaturaji/move.dart';
import 'package:flutteraji/chaturaji/nnue.dart';
import 'chaturaji_engine_interface.dart';

class _MoveResult {
  final String moveStr;
  final int n;
  final List<double> q;
  _MoveResult(this.moveStr, this.n, this.q);
}

class _MCTSNode {
  int visitCount = 0;
  List<double> qSum = [0.0, 0.0, 0.0, 0.0];
  final Move? move;
  final _MCTSNode? parent;
  List<_MCTSNode> children = [];
  bool expanded = false;
  double prior = 1.0;

  _MCTSNode({this.move, this.parent, this.prior = 1.0});
}

class ChaturajiEngineDart implements ChaturajiEngine {
  final Board _board = Board();
  final NNUEModel _nnue = NNUEModel();
  final Random _rng = Random(42);

  List<double> _evalScores = [0.0, 0.0, 0.0, 0.0];
  String _bestMoveStr = "resign";
  final List<_MoveResult> _lastChildStats = [];

  ChaturajiEngineDart() {
    _board.load(startPosition);
  }

  bool loadFromBytes(Uint8List bytes) {
    return _nnue.loadFromBytes(bytes);
  }

  @override
  void dispose() {}

  @override
  bool setPosition(String fen) {
    bool ok = _board.load(fen);
    if (ok) {
      _evalScores = [0.0, 0.0, 0.0, 0.0];
      _bestMoveStr = "resign";
      _lastChildStats.clear();
    }
    return ok;
  }

  @override
  String getFen() => _board.generateFen();

  @override
  bool loadNNUE(String path) => false; // Path loading handled via asset loader

  @override
  void search(int iterations) {
    if (_board.turn == gameOver) return;

    final root = _MCTSNode();
    for (int i = 0; i < iterations; i++) {
      final simBoard = Board.copy(_board);
      _simulate(root, simBoard);
    }

    // Best move
    _MCTSNode? best;
    for (final child in root.children) {
      if (best == null || child.visitCount > best.visitCount) {
        best = child;
      }
    }
    _bestMoveStr = best?.move?.toCoordinate() ?? "resign";

    // Cache child stats
    _lastChildStats.clear();
    for (final child in root.children) {
      final moveStr = child.move?.toCoordinate() ?? "resign";
      final n = child.visitCount;
      final q = n > 0
          ? List.generate(4, (c) => child.qSum[c] / n)
          : [0.0, 0.0, 0.0, 0.0];
      _lastChildStats.add(_MoveResult(moveStr, n, q));
    }

    if (root.visitCount > 0) {
      _evalScores = List.generate(4, (c) => root.qSum[c] / root.visitCount);
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

  void _simulate(_MCTSNode root, Board board) {
    _MCTSNode node = root;
    while (node.expanded && board.turn != gameOver && node.children.isNotEmpty) {
      node = _selectChild(node, board.turn);
      if (node.move != null) {
        board.makeMove(node.move!);
      }
    }

    if (board.turn != gameOver && !node.expanded) {
      final legalMoves = board.generateMoves();
      if (legalMoves.isNotEmpty) {
        double scoreSum = 0.0;
        final scores = <double>[];
        for (final m in legalMoves) {
          final s = _scoreMove(board, m);
          scores.add(s);
          scoreSum += s;
        }
        if (scoreSum <= 0.0) scoreSum = 1.0;

        for (int i = 0; i < legalMoves.length; i++) {
          node.children.add(_MCTSNode(
            move: legalMoves[i],
            parent: node,
            prior: scores[i] / scoreSum,
          ));
        }

        // Sort children so highest tactical prior is first
        node.children.sort((a, b) => b.prior.compareTo(a.prior));
      }
      node.expanded = true;

      if (node.children.isNotEmpty) {
        node = node.children.first;
        if (node.move != null) {
          board.makeMove(node.move!);
        }
      }
    }

    // Evaluation
    final evalPoints = [0.0, 0.0, 0.0, 0.0];
    if (board.turn == gameOver) {
      final rp = _calculateRankPoints(board.points);
      for (int c = 0; c < 4; c++) {
        evalPoints[c] = rp[c].toDouble();
      }
    } else if (_nnue.isLoaded) {
      final probs = _nnue.evaluateCanonical(board);
      for (int c = 0; c < 4; c++) {
        final rel = NNUEModel.relation[board.turn][c];
        evalPoints[c] = probs[rel] * 12.0;
      }
    } else {
      // Fallback
      for (int c = 0; c < 4; c++) {
        evalPoints[c] = 3.0;
      }
    }

    // Backprop
    _MCTSNode? curr = node;
    while (curr != null) {
      curr.visitCount++;
      for (int c = 0; c < 4; c++) {
        curr.qSum[c] += evalPoints[c];
      }
      curr = curr.parent;
    }
  }

  _MCTSNode _selectChild(_MCTSNode parent, int turn) {
    _MCTSNode? best;
    double bestPuct = -double.infinity;
    double sumN = 0.0;
    for (final child in parent.children) {
      sumN += child.visitCount;
    }
    final sqrtSumN = sqrt(max(1.0, sumN));

    for (final child in parent.children) {
      double puct;
      if (child.visitCount == 0) {
        puct = 10000.0 + (child.prior * 1000.0) + (_rng.nextDouble() * 0.01);
      } else {
        final double q = child.qSum[turn] / child.visitCount;
        final double u = 12.0 * child.prior * (sqrtSumN / (1.0 + child.visitCount));
        puct = q + u;
      }
      if (puct > bestPuct) {
        bestPuct = puct;
        best = child;
      }
    }
    return best ?? parent.children.first;
  }

  List<int> _calculateRankPoints(List<int> points) {
    const placePoints = [6, 4, 2, 0];
    final indexed = List.generate(4, (i) => MapEntry(i, points[i]));
    indexed.sort((a, b) => b.value.compareTo(a.value));
    final result = List<int>.filled(4, 0);
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

  @override
  String getBestMove() => _bestMoveStr;

  @override
  Map<String, dynamic>? getMoveStats(String moveStr) {
    for (final res in _lastChildStats) {
      if (res.moveStr == moveStr) {
        return {
          'n': res.n,
          'q': res.q,
        };
      }
    }
    return null;
  }

  @override
  double getEval(int player) {
    if (player < 0 || player > 3) return 0.0;
    return _evalScores[player];
  }

  @override
  void evaluate() {
    if (_board.turn == gameOver) {
      double total = 0;
      for (int c = 0; c < 4; c++) {
        total += _board.points[c];
      }
      for (int c = 0; c < 4; c++) {
        _evalScores[c] = total > 0 ? (_board.points[c] / total) * 12.0 : 3.0;
      }
      return;
    }

    if (_nnue.isLoaded) {
      final probs = _nnue.evaluateCanonical(_board);
      for (int c = 0; c < 4; c++) {
        final rel = NNUEModel.relation[_board.turn][c];
        _evalScores[c] = probs[rel] * 12.0;
      }
    } else {
      _evalScores = [3.0, 3.0, 3.0, 3.0];
    }
  }

  @override
  bool applyMove(String moveStr) {
    if (_board.turn == gameOver) return false;
    for (final m in _board.generateMoves()) {
      if (m.toCoordinate() == moveStr || (moveStr == 'resign' && m.from == 0 && m.to == 0)) {
        _board.makeMove(m);
        _evalScores = [0.0, 0.0, 0.0, 0.0];
        _bestMoveStr = "resign";
        return true;
      }
    }
    return false;
  }

  @override
  int getTurn() => _board.turn == gameOver ? -1 : _board.turn;

  @override
  int getPoints(int player) {
    if (player < 0 || player > 3) return 0;
    return _board.points[player];
  }
}
