// ignore_for_file: avoid_print

import 'package:flutter/material.dart';

import '../chaturaji/chaturaji.dart';

class ChaturajiController extends ValueNotifier<Chaturaji> {
  late Chaturaji game;

  factory ChaturajiController() => ChaturajiController._(Chaturaji());

  factory ChaturajiController.fromGame(Chaturaji game) =>
      ChaturajiController._(game);

  factory ChaturajiController.fromFEN(String fen) =>
      ChaturajiController._(Chaturaji.fromFEN(fen));

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

  /// Clears board
  void clearBoard() {
    game.clear();
    notifyListeners();
  }

  /// Loads a PGN
  void loadFen(String fen) {
    game.load(fen);
    notifyListeners();
  }

  bool isStaleMate() {
    return game.inStalemate;
  }

  bool isThreefoldRepetition() {
    return game.inThreefoldRepetition;
  }

  bool isGameOver() {
    return game.gameOver;
  }

  List<Piece?> getBoard() {
    return game.board;
  }

  List<Move> getPossibleMoves() {
    return game.generateMoves();
  }

  int getMoveCount() {
    return game.moveNumber;
  }

  int getHalfMoveCount() {
    return game.halfMoves;
  }
}
