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

  /// Makes move and promotes pawn to piece
  /// from is a square like d4
  /// to is also a square like e3
  /// pieceToPromoteTo is a String like "Q".
  void makeMoveWithPromotion({
    required String from,
    required String to,
    required String pieceToPromoteTo,
  }) {
    game.move({"from": from, "to": to, "promotion": pieceToPromoteTo});
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

  bool isInCheck() {
    return game.inCheck;
  }

  bool isCheckMate() {
    return game.inCheckmate;
  }

  bool isDraw() {
    return game.inDraw;
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

  String getFen() {
    return game.fen;
  }

  List<String?> getSan() {
    return game.sanMoves();
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
