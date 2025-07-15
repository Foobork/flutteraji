import 'dart:math';

import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';

import '../chaturaji/chaturaji.dart';
import 'board_arrow.dart';
import 'chess_board_controller.dart';

/// Enum which stores board types
enum BoardColor { brown, darkBrown, orange, green }

const _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

class ChessBoard extends StatefulWidget {
  /// An instance of [ChessBoardController] which holds the game and allows
  /// manipulating the board programmatically.
  final ChessBoardController controller;

  /// Size of chessboard
  final double? size;

  /// A boolean which checks if the user should be allowed to make moves
  final bool enableUserMoves;

  /// The color type of the board
  final BoardColor boardColor;

  final PlayerColor boardOrientation;

  final VoidCallback? onMove;

  final List<BoardArrow> arrows;

  const ChessBoard({
    super.key,
    required this.controller,
    this.size,
    this.enableUserMoves = true,
    this.boardColor = BoardColor.brown,
    this.boardOrientation = red,
    this.onMove,
    this.arrows = const [],
  });

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Chess>(
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

                            if (pieceMoveData.pieceType == "P" &&
                                ((pieceMoveData.squareName[1] == "7" &&
                                        squareName[1] == "8" &&
                                        pieceMoveData.pieceColor == red) ||
                                    (pieceMoveData.squareName[1] == "2" &&
                                        squareName[1] == "1" &&
                                        pieceMoveData.pieceColor == yellow))) {
                              var val = await _promotionDialog(context);

                              if (val != null) {
                                widget.controller.makeMoveWithPromotion(
                                  from: pieceMoveData.squareName,
                                  to: squareName,
                                  pieceToPromoteTo: val,
                                );
                              } else {
                                return;
                              }
                            } else {
                              widget.controller.makeMove(
                                from: pieceMoveData.squareName,
                                to: squareName,
                              );
                            }
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
              if (widget.arrows.isNotEmpty)
                IgnorePointer(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: CustomPaint(
                      painter: _ArrowPainter(
                        widget.arrows,
                        widget.boardOrientation,
                      ),
                      child: Container(),
                    ),
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

  /// Show dialog when pawn reaches last square
  Future<String?> _promotionDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose promotion'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              InkWell(
                child: WhiteQueen(),
                onTap: () {
                  Navigator.of(context).pop("q");
                },
              ),
              InkWell(
                child: WhiteRook(),
                onTap: () {
                  Navigator.of(context).pop("r");
                },
              ),
              InkWell(
                child: WhiteBishop(),
                onTap: () {
                  Navigator.of(context).pop("b");
                },
              ),
              InkWell(
                child: WhiteKnight(),
                onTap: () {
                  Navigator.of(context).pop("n");
                },
              ),
            ],
          ),
        );
      },
    ).then((value) {
      return value;
    });
  }
}

final class BoardPiece extends StatelessWidget {
  final String squareName;
  final Chess game;

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

class _ArrowPainter extends CustomPainter {
  List<BoardArrow> arrows;
  PlayerColor boardOrientation;

  _ArrowPainter(this.arrows, this.boardOrientation);

  @override
  void paint(Canvas canvas, Size size) {
    var blockSize = size.width / 8;
    var halfBlockSize = size.width / 16;

    for (var arrow in arrows) {
      var startFile = _files.indexOf(arrow.from[0]);
      var startRank = int.parse(arrow.from[1]) - 1;
      var endFile = _files.indexOf(arrow.to[0]);
      var endRank = int.parse(arrow.to[1]) - 1;

      int effectiveRowStart = 0;
      int effectiveColumnStart = 0;
      int effectiveRowEnd = 0;
      int effectiveColumnEnd = 0;

      if (boardOrientation == yellow) {
        effectiveColumnStart = 7 - startFile;
        effectiveColumnEnd = 7 - endFile;
        effectiveRowStart = startRank;
        effectiveRowEnd = endRank;
      } else {
        effectiveColumnStart = startFile;
        effectiveColumnEnd = endFile;
        effectiveRowStart = 7 - startRank;
        effectiveRowEnd = 7 - endRank;
      }

      var startOffset = Offset(
        ((effectiveColumnStart + 1) * blockSize) - halfBlockSize,
        ((effectiveRowStart + 1) * blockSize) - halfBlockSize,
      );
      var endOffset = Offset(
        ((effectiveColumnEnd + 1) * blockSize) - halfBlockSize,
        ((effectiveRowEnd + 1) * blockSize) - halfBlockSize,
      );

      var yDist = 0.8 * (endOffset.dy - startOffset.dy);
      var xDist = 0.8 * (endOffset.dx - startOffset.dx);

      var paint = Paint()
        ..strokeWidth = halfBlockSize * 0.8
        ..color = arrow.color;

      canvas.drawLine(
        startOffset,
        Offset(startOffset.dx + xDist, startOffset.dy + yDist),
        paint,
      );

      var slope =
          (endOffset.dy - startOffset.dy) / (endOffset.dx - startOffset.dx);

      var newLineSlope = -1 / slope;

      var points = _getNewPoints(
        Offset(startOffset.dx + xDist, startOffset.dy + yDist),
        newLineSlope,
        halfBlockSize,
      );
      var newPoint1 = points[0];
      var newPoint2 = points[1];

      var path = Path();

      path.moveTo(endOffset.dx, endOffset.dy);
      path.lineTo(newPoint1.dx, newPoint1.dy);
      path.lineTo(newPoint2.dx, newPoint2.dy);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  List<Offset> _getNewPoints(Offset start, double slope, double length) {
    if (slope == double.infinity || slope == double.negativeInfinity) {
      return [
        Offset(start.dx, start.dy + length),
        Offset(start.dx, start.dy - length),
      ];
    }

    return [
      Offset(
        start.dx + (length / sqrt(1 + (slope * slope))),
        start.dy + ((length * slope) / sqrt(1 + (slope * slope))),
      ),
      Offset(
        start.dx - (length / sqrt(1 + (slope * slope))),
        start.dy - ((length * slope) / sqrt(1 + (slope * slope))),
      ),
    ];
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) {
    return arrows != oldDelegate.arrows;
  }
}
