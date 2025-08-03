// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutteraji/chaturaji/game.dart';
import 'package:flutteraji/chaturaji/move.dart';

class ChaturajiController extends ValueNotifier<ChaturajiGame> {
  late ChaturajiGame game;

  factory ChaturajiController() => ChaturajiController._(ChaturajiGame());

  ChaturajiController._(this.game) : super(game);

  void makeMove(Move move) {
    List<Move> moves = game.generateMoves();
    if (moves.contains(move)) {
      game.makeMove(move);
      notifyListeners();
    }
  }

  /// Makes move on the board
  void makeSanMove(String move) {
    game.makeSanMove(move);
    notifyListeners();
  }

  void undoMove() {
    game.undoMove();
    notifyListeners();
  }

  void resetBoard() {
    game.reset();
    notifyListeners();
  }

  List<Move> getPossibleMoves() {
    return game.generateMoves();
  }
}
