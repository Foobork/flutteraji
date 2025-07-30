// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutteraji/chaturaji/chaturaji_game.dart';
import 'package:flutteraji/chaturaji/chaturaji_move.dart';

class ChaturajiController extends ValueNotifier<ChaturajiGame> {
  late ChaturajiGame game;

  factory ChaturajiController() => ChaturajiController._(ChaturajiGame());

  ChaturajiController._(this.game) : super(game);

  /// Makes move on the board
  void makeMove({required String from, required String to}) {
    game.makeMove({"from": from, "to": to});
    notifyListeners();
  }

  /// Makes move on the board
  void makeMoveWithNormalNotation(String move) {
    game.makeMove(move);
    notifyListeners();
  }

  void undoMove() {
    game.undoMove();
    notifyListeners();
  }

  void resetBoard() {
    game.board.reset();
    notifyListeners();
  }

  List<ChaturajiMove> getPossibleMoves() {
    return game.board.generateMoves();
  }
}
