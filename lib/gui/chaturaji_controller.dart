// ignore_for_file: avoid_print

import 'package:flutter/material.dart';

import '../chaturaji/chaturaji.dart';

class ChaturajiController extends ValueNotifier<Chaturaji> {
  late Chaturaji game;

  factory ChaturajiController() => ChaturajiController._(Chaturaji());

  ChaturajiController._(this.game) : super(game);

  /// Makes move on the board
  void makeMove({required String from, required String to}) {
    game.move({"from": from, "to": to});
    notifyListeners();
  }

  /// Makes move on the board
  void makeMoveWithNormalNotation(String move) {
    game.move(move);
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
