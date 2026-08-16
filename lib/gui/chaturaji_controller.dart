// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/chaturaji/game.dart';
import 'package:flutteraji/chaturaji/move.dart';
import 'package:flutteraji/graph/graph.dart';
import 'package:flutteraji/engine/chaturaji_engine.dart';
import 'package:flutteraji/engine/engine_loader.dart';

class ChaturajiController extends ValueNotifier<ChaturajiGame> {
  late ChaturajiGame game;
  ChaturajiEngine? engine;
  bool useNNUE = false;

  factory ChaturajiController() => ChaturajiController._(ChaturajiGame());

  ChaturajiController._(this.game) : super(game) {
    try {
      final result = initPlatformEngine();
      engine = result.engine;
      useNNUE = result.useNNUE;
      _syncEngine();
    } catch (e) {
      print("Failed to initialize engine: $e");
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
