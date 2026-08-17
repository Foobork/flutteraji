import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/chaturaji/game.dart';
import 'package:flutteraji/chaturaji/move.dart';
import 'package:flutteraji/graph/graph.dart';
import 'package:flutteraji/engine/chaturaji_engine.dart';
import 'package:flutteraji/engine/engine_loader.dart';
import 'package:flutteraji/engine/chaturaji_engine_dart.dart';

class ChaturajiController extends ValueNotifier<ChaturajiGame> {
  late ChaturajiGame game;
  ChaturajiEngine? engine;
  bool useNNUE = false;

  factory ChaturajiController() => ChaturajiController._(ChaturajiGame());

  ChaturajiController._(this.game) : super(game) {
    try {
      loadPreferences();
    } catch (_) {}
    try {
      final result = initPlatformEngine();
      engine = result.engine;
      useNNUE = result.useNNUE;
      _syncEngine();
    } catch (e) {
      print("Failed to initialize engine: $e");
    }

    if (!useNNUE) {
      _loadNNUEFromBundle();
    }
  }

  Future<void> _loadNNUEFromBundle() async {
    try {
      ByteData? byteData;
      try {
        byteData = await rootBundle.load('nnue/checkpoints/gen4.nnue');
      } catch (_) {
        byteData = await rootBundle.load('assets/nnue/checkpoints/gen4.nnue');
      }
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      engine ??= ChaturajiEngineDart();
      if (engine is ChaturajiEngineDart) {
        if ((engine as ChaturajiEngineDart).loadFromBytes(bytes)) {
          useNNUE = true;
          _syncEngine();
          notifyListeners();
          print("NNUE model loaded from bundle assets (Gen 4)");
        }
      }
    } catch (e) {
      print("Bundle NNUE load: $e");
    }
  }

  void _syncEngine() {
    if (engine != null) {
      engine!.setPosition(game.generateFen());
    }
  }

  void makeMove(Move move) {
    List<Move> moves = game.generateMoves();
    if (moves.contains(move)) {
      String fen = game.generateFen();
      graph.addEdge(fen, move);
      game.makeMove(move);
      _syncEngine();
      notifyListeners();
    }
  }

  /// Makes move on the board
  void makeSanMove(String move) {
    Move moveObj = sanToMove(move);
    String fen = game.generateFen();
    graph.addEdge(fen, moveObj);
    game.makeSanMove(move);
    _syncEngine();
    notifyListeners();
  }

  void undoMove() {
    game.undoMove();
    _syncEngine();
    notifyListeners();
  }

  void reset() {
    game.reset();
    _syncEngine();
    notifyListeners();
  }

  List<Move> generateMoves() {
    return game.generateMoves();
  }

  ValueNotifier<int> rotation = ValueNotifier<int>(0);
  ValueNotifier<bool> rotatePieces = ValueNotifier<bool>(true);

  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getBool('rotate_pieces');
      if (val != null) {
        rotatePieces.value = val;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setRotatePieces(bool value) async {
    rotatePieces.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rotate_pieces', value);
    } catch (_) {}
    notifyListeners();
  }

  void rotate() {
    rotation.value = (rotation.value + 1) % 4;
    notifyListeners();
  }

  void runMCTS(int iterations) {
    if (game.board.turn == gameOver) {
      print("Game is over, search cancelled.");
      return;
    }
    // Ensure all legal moves are in the graph so they show up in the UI
    String fen = game.generateFen();
    var vertex = graph.addVertex(fen);
    for (var move in game.generateMoves()) {
      if (!vertex.edges.containsKey(move)) {
        vertex.edges[move] = 0;
      }
    }

    if (useNNUE && engine != null) {
      engine!.search(iterations);
      
      // Update root vertex
      vertex.N += iterations;
      for (int i = 0; i < 4; i++) {
        vertex.Q[i] += (engine!.getEval(i) * iterations);
      }

      // Update child vertices with move-specific stats
      for (var move in game.generateMoves()) {
        final stats = engine!.getMoveStats(move.toCoordinate());
        if (stats != null) {
          // Get or create child vertex
          final nextBoard = Board.copy(game.board);
          nextBoard.makeMove(move);
          final childFen = nextBoard.generateFen();
          final childVertex = graph.addVertex(childFen);

          // Update stats
          int n = stats['n'];
          List<double> qMeans = stats['q'];
          
          childVertex.N += n;
          for (int i = 0; i < 4; i++) {
            childVertex.Q[i] += (qMeans[i] * n);
          }

          // Also update the edge count from parent
          vertex.edges[move] = (vertex.edges[move] ?? 0) + n;
        }
      }
    } else {
      game.runMCTS(iterations);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    engine?.dispose();
    super.dispose();
  }
}
