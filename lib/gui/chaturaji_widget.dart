// ignore_for_file: avoid_print

import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/chaturaji/game.dart';
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
                            widget.controller.makeMove(
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
    final fillColor = switch (piece & (dead | colorMask)) {
      red => Colors.red,
      blue => Colors.blue,
      yellow => Colors.yellow,
      green => Colors.green,
      _ => Colors.grey,
    };

    final int turns = switch (piece & colorMask) {
      blue => 1,
      yellow => 2,
      green => 3,
      _ => 0,
    };

    final Widget pieceWidget = switch (piece & pieceMask) {
      pawn => WhitePawn(fillColor: fillColor),
      rook => WhiteRook(fillColor: fillColor),
      knight => WhiteKnight(fillColor: fillColor),
      bishop => WhiteBishop(fillColor: fillColor),
      king => WhiteKing(fillColor: fillColor),
      _ => Container(),
    };

    return RotatedBox(quarterTurns: turns, child: pieceWidget);
  }
}

class PieceMoveData {
  final int squareIndex;
  final int piece;

  PieceMoveData({required this.squareIndex, required this.piece});
}
