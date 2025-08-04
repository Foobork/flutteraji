// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:flutteraji/chaturaji/move.dart';

const int colorMask = 0x30;
const int pieceMask = 0x07;

const int empty = 0x00;
const int pawn = 0x01;
const int knight = 0x02;
const int bishop = 0x03;
const int rook = 0x04;
const int king = 0x05;

const int red = 0x00;
const int blue = 0x10;
const int yellow = 0x20;
const int green = 0x30;

const int dead = 0x40;

const int gameOver = 0x80;

Map<String, int> colors = {'r': red, 'b': blue, 'y': yellow, 'g': green};
Map<int, String> colorSymbols = {
  red: 'r',
  blue: 'b',
  yellow: 'y',
  green: 'g',
  gameOver: '*',
};

Map<String, int> pieceTypes = {
  'P': pawn,
  'N': knight,
  'B': bishop,
  'R': rook,
  'K': king,
};

Map<int, String> pieceSymbols = {
  pawn: 'P',
  knight: 'N',
  bishop: 'B',
  rook: 'R',
  king: 'K',
};

const String startPosition =
    'bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r';

const int squaresA8 = 0;
const int squaresH1 = 119;

const Map<int, List<int>> pawnOffsets = {
  red: [-16, -17, -15],
  blue: [1, -15, 17],
  yellow: [16, 17, 15],
  green: [-1, 15, -17],
};

const Map<int, List<int>> pieceOffsets = {
  knight: [-18, -33, -31, -14, 18, 33, 31, 14],
  bishop: [-17, -15, 17, 15],
  rook: [-16, 1, 16, -1],
  king: [-17, -16, -15, 1, 17, 16, 15, -1],
};

class Board {
  Uint8List board = Uint8List(128);
  Map<int, int> points = {red: 0, blue: 0, yellow: 0, green: 0};
  Set<int> liveColors = {red, blue, yellow, green};
  int turn = red;

  /// empty constructor
  Board();

  /// copy another board
  Board.copy(Board other) {
    board.setAll(0, other.board);
    points = Map<int, int>.from(other.points);
    liveColors = Set<int>.from(other.liveColors);
    turn = other.turn;
  }

  /// reset to start position
  void reset() {
    load(startPosition);
  }

  /// Load a position from a FEN String
  bool load(String fen) {
    List tokens = fen.split(RegExp(r'\s+'));
    String position = tokens[0];
    var square = 0;

    clear();

    for (var i = 0; i < position.length; i++) {
      final c = position[i];

      if (c == '/') {
        square += 8;
      } else if (_isDigit(c)) {
        square += int.parse(c);
      } else {
        final color = colors[c]!;
        final piece = pieceTypes[position[++i]]!;
        if (piece == king) {
          liveColors.add(color);
        }
        board[square] = color | piece;
        square++;
      }
    }

    final pointStr = tokens[1].split('/');
    points[red] = int.parse(pointStr[0]);
    points[blue] = int.parse(pointStr[1]);
    points[yellow] = int.parse(pointStr[2]);
    points[green] = int.parse(pointStr[3]);

    turn = colors[tokens[2]]!;

    return true;
  }

  /// Returns a FEN String representing the current position
  String generateFen() {
    var emptyCount = 0;
    var fen = '';

    for (var i = squaresA8; i <= squaresH1; i++) {
      if (board[i] == empty) {
        emptyCount++;
      } else {
        if (emptyCount > 0) {
          fen += emptyCount.toString();
          emptyCount = 0;
        }
        var color = colorSymbols[board[i] & colorMask]!;
        var type = pieceSymbols[board[i] & pieceMask]!;
        fen += color + type;
      }

      if (((i + 1) & 0x88) != 0) {
        if (emptyCount > 0) {
          fen += emptyCount.toString();
        }

        if (i != squaresH1) {
          fen += '/';
        }

        emptyCount = 0;
        i += 8;
      }
    }

    final pointsStr =
        "${points[red]}/${points[blue]}/${points[yellow]}/${points[green]}";

    final turnStr = colorSymbols[turn]!;

    return [fen, pointsStr, turnStr].join(' ');
  }

  void clear() {
    board.fillRange(0, 128, empty);
    points = {red: 0, blue: 0, yellow: 0, green: 0};
    liveColors = {};
    turn = red;
  }

  List<Move> generateMoves() {
    final moves = <Move>[];

    for (int from = squaresA8; from <= squaresH1; from++) {
      // --- did we run off the end of the board
      if ((from & 0x88) != 0) {
        from += 7;
        continue;
      }

      final int piece = board[from];
      if (piece == empty || piece & colorMask != turn) {
        continue;
      }

      final int pieceType = piece & pieceMask;

      if (pieceType == pawn) {
        // single square, non-capturing
        final int to = from + pawnOffsets[turn]![0];
        if (board[to] == empty) {
          moves.add(Move(from, to));
        }

        // pawn captures
        for (var j = 1; j < 3; j++) {
          int to = from + pawnOffsets[turn]![j];
          if ((to & 0x88) != 0) continue;
          if (board[to] != empty && board[to] & colorMask != turn) {
            moves.add(Move(from, to));
          }
        }
      } else {
        for (final offset in pieceOffsets[pieceType]!) {
          int to = from;

          while (true) {
            to += offset;
            if ((to & 0x88) != 0) break;

            if (board[to] == empty) {
              moves.add(Move(from, to));
            } else {
              if (board[to] & colorMask != turn) {
                moves.add(Move(from, to));
              }
              break;
            }

            // break, if knight or king
            if (pieceType == knight || pieceType == king) break;
          }
        }
      }
    }

    return moves;
  }

  void makeMove(Move move) {
    final from = move.from;
    final to = move.to;

    // Points for capture
    points[turn] = points[turn]! + (capturePoints[board[to]] ?? 0);

    // King capture
    if (board[to] & (dead | pieceMask) == king) {
      markDead(board[to] & colorMask);
    }

    // Move the piece
    board[to] = board[from];
    board[from] = empty;

    // Check for promotion
    if (board[to] & pieceMask == pawn) {
      switch (board[to] & colorMask) {
        case red:
          if (to <= 7) board[to] = red | rook;
          break;
        case blue:
          if (to % 8 == 7) board[to] = blue | rook;
          break;
        case yellow:
          if (to >= 112) board[to] = yellow | rook;
          break;
        case green:
          if (to % 8 == 0) board[to] = green | rook;
          break;
      }
    }

    // Change turn
    if (liveColors.length == 1) {
      turn = gameOver;
    } else {
      do {
        turn = (turn + 0x10) & colorMask;
      } while (!liveColors.contains(turn));
    }
  }

  // mark a color dead
  void markDead(int deadColor) {
    for (int i = squaresA8; i <= squaresH1; i++) {
      if ((i & 0x88) != 0) {
        i += 7; // skip to next row
        continue;
      }
      if (board[i] != empty && board[i] & colorMask == deadColor) {
        board[i] |= dead;
      }
    }
    liveColors.remove(deadColor);
  }

  // assume String is length 1
  bool _isDigit(String s) {
    final intChar = s.codeUnitAt(0);
    return intChar >= 0x30 && intChar <= 0x39; // ASCII values for '0' to '9'
  }
}

Map<int, int> capturePoints = {
  red | pawn: 1,
  red | knight: 3,
  red | bishop: 5,
  red | rook: 5,
  red | king: 3,
  blue | pawn: 1,
  blue | knight: 3,
  blue | bishop: 5,
  blue | rook: 5,
  blue | king: 3,
  yellow | pawn: 1,
  yellow | knight: 3,
  yellow | bishop: 5,
  yellow | rook: 5,
  yellow | king: 3,
  green | pawn: 1,
  green | knight: 3,
  green | bishop: 5,
  green | rook: 5,
  green | king: 3,
  dead | red | king: 3,
  dead | blue | king: 3,
  dead | yellow | king: 3,
  dead | green | king: 3,
};
