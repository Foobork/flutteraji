import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';

import '../chaturaji/chaturaji.dart';
import '../chaturaji/player_color.dart';
import 'chaturaji_controller.dart';

/// Enum which stores board types
enum BoardColor { brown, darkBrown, orange, green }

const _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

class ChaturajiWidget extends StatefulWidget {
  /// An instance of [ChaturajiController] which holds the game and allows
  /// manipulating the board programmatically.
  final ChaturajiController controller;

  /// Size of board
  final double? size;

  /// A boolean which checks if the user should be allowed to make moves
  final bool enableUserMoves;

  /// The color type of the board
  final BoardColor boardColor;

  final PlayerColor boardOrientation;

  final VoidCallback? onMove;

  const ChaturajiWidget({
    super.key,
    required this.controller,
    this.size,
    this.enableUserMoves = true,
    this.boardColor = BoardColor.brown,
    this.boardOrientation = red,
    this.onMove,
  });

  @override
  State<ChaturajiWidget> createState() => _ChaturajiWidgetState();
}

class _ChaturajiWidgetState extends State<ChaturajiWidget> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Chaturaji>(
      valueListenable: widget.controller,
      builder: (context, game, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.0,
                child: _getBoardImage(widget.boardColor),
              ),
              AspectRatio(
                aspectRatio: 1.0,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                  ),
                  itemBuilder: (context, index) {
                    var row = index ~/ 8;
                    var column = index % 8;
                    var boardRank = widget.boardOrientation == yellow
                        ? '${row + 1}'
                        : '${(7 - row) + 1}';
                    var boardFile = widget.boardOrientation == red
                        ? _files[column]
                        : _files[7 - column];

                    var squareName = '$boardFile$boardRank';
                    var pieceOnSquare = game.get(squareName);

                    var piece = BoardPiece(
                      key: ValueKey(
                        '${squareName}_${pieceOnSquare?.type}_${pieceOnSquare?.color}',
                      ),
                      squareName: squareName,
                      game: game,
                    );

                    var draggable = game.get(squareName) != null
                        ? Draggable<PieceMoveData>(
                            feedback: piece,
                            childWhenDragging: const SizedBox(),
                            data: PieceMoveData(
                              squareName: squareName,
                              pieceType:
                                  pieceOnSquare?.type.toUpperCase() ?? 'P',
                              pieceColor: pieceOnSquare?.color ?? red,
                            ),
                            child: piece,
                          )
                        : Container();

                    var dragTarget = DragTarget<PieceMoveData>(
                      builder: (context, list, _) {
                        return draggable;
                      },
                      onWillAcceptWithDetails: (pieceMoveData) {
                        return widget.enableUserMoves ? true : false;
                      },
                      onAcceptWithDetails:
                          (
                            DragTargetDetails<PieceMoveData> dragTargetDetails,
                          ) async {
                            PieceMoveData pieceMoveData =
                                dragTargetDetails.data;
                            // A way to check if move occurred.
                            PlayerColor moveColor = game.turn;
                            widget.controller.makeMove(
                              from: pieceMoveData.squareName,
                              to: squareName,
                            );
                            if (game.turn != moveColor) {
                              widget.onMove?.call();
                            }
                          },
                    );

                    return dragTarget;
                  },
                  itemCount: 64,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Returns the board image
  Image _getBoardImage(BoardColor color) {
    switch (color) {
      case BoardColor.brown:
        return Image.asset("images/brown_board.png", fit: BoxFit.cover);
      case BoardColor.darkBrown:
        return Image.asset("images/dark_brown_board.png", fit: BoxFit.cover);
      case BoardColor.green:
        return Image.asset("images/green_board.png", fit: BoxFit.cover);
      case BoardColor.orange:
        return Image.asset("images/orange_board.png", fit: BoxFit.cover);
    }
  }
}

final class BoardPiece extends StatelessWidget {
  final String squareName;
  final Chaturaji game;

  const BoardPiece({super.key, required this.squareName, required this.game});

  @override
  Widget build(BuildContext context) {
    var square = game.get(squareName);

    if (game.get(squareName) == null) {
      return Container();
    }

    return switch (square) {
      Piece(type: pawn, color: red) => WhitePawn(fillColor: Colors.red),
      Piece(type: rook, color: red) => WhiteRook(fillColor: Colors.red),
      Piece(type: knight, color: red) => WhiteKnight(fillColor: Colors.red),
      Piece(type: bishop, color: red) => WhiteBishop(fillColor: Colors.red),
      Piece(type: king, color: red) => WhiteKing(fillColor: Colors.red),
      Piece(type: pawn, color: yellow) => WhitePawn(fillColor: Colors.yellow),
      Piece(type: rook, color: yellow) => WhiteRook(fillColor: Colors.yellow),
      Piece(type: knight, color: yellow) => WhiteKnight(
        fillColor: Colors.yellow,
      ),
      Piece(type: bishop, color: yellow) => WhiteBishop(
        fillColor: Colors.yellow,
      ),
      Piece(type: king, color: yellow) => WhiteKing(fillColor: Colors.yellow),
      Piece(type: pawn, color: blue) => WhitePawn(fillColor: Colors.blue),
      Piece(type: rook, color: blue) => WhiteRook(fillColor: Colors.blue),
      Piece(type: knight, color: blue) => WhiteKnight(fillColor: Colors.blue),
      Piece(type: bishop, color: blue) => WhiteBishop(fillColor: Colors.blue),
      Piece(type: king, color: blue) => WhiteKing(fillColor: Colors.blue),
      Piece(type: pawn, color: green) => WhitePawn(fillColor: Colors.green),
      Piece(type: rook, color: green) => WhiteRook(fillColor: Colors.green),
      Piece(type: knight, color: green) => WhiteKnight(fillColor: Colors.green),
      Piece(type: bishop, color: green) => WhiteBishop(fillColor: Colors.green),
      Piece(type: king, color: green) => WhiteKing(fillColor: Colors.green),
      _ => throw UnimplementedError(),
    };
  }
}

class PieceMoveData {
  final String squareName;
  final String pieceType;
  final PlayerColor pieceColor;

  PieceMoveData({
    required this.squareName,
    required this.pieceType,
    required this.pieceColor,
  });
}
