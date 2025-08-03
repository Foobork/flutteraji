import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutteraji/chaturaji/chaturaji_board.dart';
import 'package:flutteraji/chaturaji/chaturaji_game.dart';
import 'package:flutteraji/chaturaji/move.dart';

import 'chaturaji_controller.dart';

const _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

class ChaturajiWidget extends StatefulWidget {
  /// An instance of [ChaturajiController] which holds the game and allows
  /// manipulating the board programmatically.
  final ChaturajiController controller;

  /// Size of board
  final double? size;

  final VoidCallback? onMove;

  const ChaturajiWidget({
    super.key,
    required this.controller,
    this.size,
    this.onMove,
  });

  @override
  State<ChaturajiWidget> createState() => _ChaturajiWidgetState();
}

class _ChaturajiWidgetState extends State<ChaturajiWidget> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChaturajiGame>(
      valueListenable: widget.controller,
      builder: (context, game, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.0,
                child: Image.asset("images/chess_board.png", fit: BoxFit.cover),
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
                    var boardRank = '${8 - row}';
                    var boardFile = _files[column];
                    var squareName = '$boardFile$boardRank';
                    int squareIndex = row * 16 + column;
                    var pieceOnSquare = game.board.board[squareIndex];

                    var piece = BoardPiece(
                      key: ValueKey('${squareName}_$pieceOnSquare'),
                      piece: pieceOnSquare,
                    );

                    var draggable = pieceOnSquare != empty
                        ? Draggable<PieceMoveData>(
                            feedback: piece,
                            childWhenDragging: const SizedBox(),
                            data: PieceMoveData(
                              squareIndex: squareIndex,
                              piece: pieceOnSquare,
                            ),
                            child: piece,
                          )
                        : Container();

                    var dragTarget = DragTarget<PieceMoveData>(
                      builder: (context, list, _) {
                        return draggable;
                      },
                      onWillAcceptWithDetails: (pieceMoveData) {
                        return true;
                      },
                      onAcceptWithDetails:
                          (
                            DragTargetDetails<PieceMoveData> dragTargetDetails,
                          ) async {
                            PieceMoveData pieceMoveData =
                                dragTargetDetails.data;
                            // A way to check if move occurred.
                            widget.controller.makeChaturajiMove(
                              Move(pieceMoveData.squareIndex, squareIndex),
                            );
                            widget.onMove?.call();
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
}

final class BoardPiece extends StatelessWidget {
  final int piece;

  const BoardPiece({super.key, required this.piece});

  @override
  Widget build(BuildContext context) {
    return switch (piece) {
      const (red | pawn) => WhitePawn(fillColor: Colors.red),
      const (red | rook) => WhiteRook(fillColor: Colors.red),
      const (red | knight) => WhiteKnight(fillColor: Colors.red),
      const (red | bishop) => WhiteBishop(fillColor: Colors.red),
      const (red | king) => WhiteKing(fillColor: Colors.red),
      const (yellow | pawn) => WhitePawn(fillColor: Colors.yellow),
      const (yellow | rook) => WhiteRook(fillColor: Colors.yellow),
      const (yellow | knight) => WhiteKnight(fillColor: Colors.yellow),
      const (yellow | bishop) => WhiteBishop(fillColor: Colors.yellow),
      const (yellow | king) => WhiteKing(fillColor: Colors.yellow),
      const (blue | pawn) => WhitePawn(fillColor: Colors.blue),
      const (blue | rook) => WhiteRook(fillColor: Colors.blue),
      const (blue | knight) => WhiteKnight(fillColor: Colors.blue),
      const (blue | bishop) => WhiteBishop(fillColor: Colors.blue),
      const (blue | king) => WhiteKing(fillColor: Colors.blue),
      const (green | pawn) => WhitePawn(fillColor: Colors.green),
      const (green | rook) => WhiteRook(fillColor: Colors.green),
      const (green | knight) => WhiteKnight(fillColor: Colors.green),
      const (green | bishop) => WhiteBishop(fillColor: Colors.green),
      const (green | king) => WhiteKing(fillColor: Colors.green),
      _ => Container(),
    };
  }
}

class PieceMoveData {
  final int squareIndex;
  final int piece;

  PieceMoveData({required this.squareIndex, required this.piece});
}
