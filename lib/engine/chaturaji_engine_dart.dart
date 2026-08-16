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

  _MCTSNode({this.move, this.parent});
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
      for (final m in legalMoves) {
        node.children.add(_MCTSNode(move: m, parent: node));
      }
      node.expanded = true;

      if (node.children.isNotEmpty) {
        final pick = _rng.nextInt(node.children.length);
        node = node.children[pick];
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
    double bestUct = -double.infinity;
    final logN = log(max(1, parent.visitCount));

    for (final child in parent.children) {
      double uct;
      if (child.visitCount == 0) {
        uct = 10000.0 + _rng.nextDouble();
      } else {
        final double q = child.qSum[turn] / child.visitCount;
        final double u = 12.0 * sqrt(logN / child.visitCount);
        uct = q + u;
      }
      if (uct > bestUct) {
        bestUct = uct;
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
