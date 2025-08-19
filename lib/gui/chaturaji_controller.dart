// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutteraji/chaturaji/game.dart';
import 'package:flutteraji/chaturaji/move.dart';
import 'package:flutteraji/graph/graph.dart';

class ChaturajiController extends ValueNotifier<ChaturajiGame> {
  late ChaturajiGame game;

  factory ChaturajiController() => ChaturajiController._(ChaturajiGame());

  ChaturajiController._(this.game) : super(game);

  void makeMove(Move move) {
    List<Move> moves = game.generateMoves();
    if (moves.contains(move)) {
      String fen = game.generateFen();
      graph.addEdge(fen, move);
      game.makeMove(move);
      notifyListeners();
    }
  }

  /// Makes move on the board
  void makeSanMove(String move) {
    Move moveObj = sanToMove(move);
    String fen = game.generateFen();
    graph.addEdge(fen, moveObj);
    game.makeSanMove(move);
    notifyListeners();
  }

  void undoMove() {
    game.undoMove();
    notifyListeners();
  }

  void reset() {
    game.reset();
    notifyListeners();
  }

  List<Move> generateMoves() {
    return game.generateMoves();
  }
}
