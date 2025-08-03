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

Map<String, int> colors = {'r': red, 'b': blue, 'y': yellow, 'g': green};

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

Map<int, String> colorSymbols = {red: 'r', blue: 'b', yellow: 'y', green: 'g'};

const String startPosition =
    'bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR r';

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
  int turn = red;

  /// empty constructor
  Board();

  /// copy another board
  Board.copy(Board other) {
    board.setAll(0, other.board);
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
        board[square] = color | piece;
        square++;
      }
    }

    turn = colors[tokens[1]]!;

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

    final turnStr = colorSymbols[turn]!;

    return [fen, turnStr].join(' ');
  }

  void clear() {
    board.fillRange(0, 128, empty);
    turn = red;
  }

  List<Move> generateMoves() {
    final moves = <Move>[];
    final us = turn;

    for (int from = squaresA8; from <= squaresH1; from++) {
      // --- did we run off the end of the board
      if ((from & 0x88) != 0) {
        from += 7;
        continue;
      }

      final int piece = board[from];
      if (piece == empty || piece & colorMask != us) {
        continue;
      }

      final int pieceType = piece & pieceMask;

      if (pieceType == pawn) {
        // single square, non-capturing
        final int to = from + pawnOffsets[us]![0];
        if (board[to] == empty) {
          moves.add(Move(from, to));
        }

        // pawn captures
        for (var j = 1; j < 3; j++) {
          int to = from + pawnOffsets[us]![j];
          if ((to & 0x88) != 0) continue;
          if (board[to] != empty && board[to] & colorMask != us) {
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
              if (board[to] & colorMask != us) {
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

  bool move(Move move) {
    final from = move.from;
    final to = move.to;

    print("Moving from $from to $to");

    // Move the piece
    board[to] = board[from];
    board[from] = empty;

    print(generateFen());

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
    turn = (turn + 0x10) & colorMask;

    return true;
  }

  // assume String is length 1
  bool _isDigit(String s) {
    final intChar = s.codeUnitAt(0);
    return intChar >= 0x30 && intChar <= 0x39; // ASCII values for '0' to '9'
  }
}
