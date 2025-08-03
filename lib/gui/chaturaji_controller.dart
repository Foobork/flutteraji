// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutteraji/chaturaji/chaturaji_game.dart';
import 'package:flutteraji/chaturaji/move.dart';

class ChaturajiController extends ValueNotifier<ChaturajiGame> {
  late ChaturajiGame game;

  factory ChaturajiController() => ChaturajiController._(ChaturajiGame());

  ChaturajiController._(this.game) : super(game);

  void makeChaturajiMove(Move move) {
    List<Move> moves = game.board.generateMoves();
    if (moves.contains(move)) {
      game.makeChaturajiMove(move);
      notifyListeners();
    }
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

  List<Move> getPossibleMoves() {
    return game.board.generateMoves();
  }
}
