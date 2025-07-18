// ignore_for_file: avoid_print

import 'package:flutter/material.dart';

import '../chaturaji/chaturaji.dart';

class ChaturajiBoardController extends ValueNotifier<Chaturaji> {
  late Chaturaji game;

  factory ChaturajiBoardController() => ChaturajiBoardController._(Chaturaji());

  factory ChaturajiBoardController.fromGame(Chaturaji game) =>
      ChaturajiBoardController._(game);

  factory ChaturajiBoardController.fromFEN(String fen) =>
      ChaturajiBoardController._(Chaturaji.fromFEN(fen));

  ChaturajiBoardController._(this.game) : super(game);

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
