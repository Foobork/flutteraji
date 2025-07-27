import 'dart:typed_data';

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

class ChaturajiBoard {
  Uint8List board = Uint8List(128);
  int turn = red;

  /// empty constructor
  ChaturajiBoard();

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

  // assume String is length 1
  bool _isDigit(String s) {
    final intChar = s.codeUnitAt(0);
    return intChar >= 0x30 && intChar <= 0x39; // ASCII values for '0' to '9'
  }
}
