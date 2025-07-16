// ignore_for_file: avoid_print

/*  Based on chess.dart
 *  Copyright (c) 2014, David Kopec (my first name at oaksnow dot com)
 *  Released under the MIT license
 *  https://github.com/davecom/chess.dart/blob/master/LICENSE
 *
 *  Based on chess.js
 *  Copyright (c) 2013, Jeff Hlywa (jhlywa@gmail.com)
 *  Released under the BSD license
 *  https://github.com/jhlywa/chess.js/blob/master/LICENSE
 */

enum PlayerColor { red, blue, yellow, green }

const PlayerColor red = PlayerColor.red;
const PlayerColor blue = PlayerColor.blue;
const PlayerColor yellow = PlayerColor.yellow;
const PlayerColor green = PlayerColor.green;

const Map<String, PlayerColor> colors = {
  'r': red,
  'b': blue,
  'y': yellow,
  'g': green,
};

const Map<PlayerColor, String> colorNames = {
  red: 'Red',
  blue: 'Blue',
  yellow: 'Yellow',
  green: 'Green',
};

const Map<PlayerColor, PlayerColor> nextColor = {
  red: blue,
  blue: yellow,
  yellow: green,
  green: red,
};

const PieceType pawn = PieceType.pawn;
const PieceType knight = PieceType.knight;
const PieceType bishop = PieceType.bishop;
const PieceType rook = PieceType.rook;
const PieceType king = PieceType.king;

class Chaturaji {
  // Constants/Class Variables

  static const Map<String, PieceType> pieceTypes = {
    'p': pawn,
    'n': knight,
    'b': bishop,
    'r': rook,
    'k': king,
  };

  static const String defaultPosition =
      'bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR r';

  static const Map<PlayerColor, List<int>> pawnOffsets = {
    red: [-16, -17, -15],
    blue: [1, -15, 17],
    yellow: [16, 17, 15],
    green: [-1, 15, -17],
  };

  static const Map<PieceType, List<int>> pieceOffsets = {
    knight: [-18, -33, -31, -14, 18, 33, 31, 14],
    bishop: [-17, -15, 17, 15],
    rook: [-16, 1, 16, -1],
    king: [-17, -16, -15, 1, 17, 16, 15, -1],
  };

  static const List attacks = [
    // prevent aggressive reformat
    20, 0, 0, 0, 0, 0, 0, 24, 0, 0, 0, 0, 0, 0, 20, 0,
    0, 20, 0, 0, 0, 0, 0, 24, 0, 0, 0, 0, 0, 20, 0, 0,
    0, 0, 20, 0, 0, 0, 0, 24, 0, 0, 0, 0, 20, 0, 0, 0,
    0, 0, 0, 20, 0, 0, 0, 24, 0, 0, 0, 20, 0, 0, 0, 0,
    0, 0, 0, 0, 20, 0, 0, 24, 0, 0, 20, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 20, 2, 24, 2, 20, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 2, 53, 56, 53, 2, 0, 0, 0, 0, 0, 0,
    24, 24, 24, 24, 24, 24, 56, 0, 56, 24, 24, 24, 24, 24, 24, 0,
    0, 0, 0, 0, 0, 2, 53, 56, 53, 2, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 20, 2, 24, 2, 20, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 20, 0, 0, 24, 0, 0, 20, 0, 0, 0, 0, 0,
    0, 0, 0, 20, 0, 0, 0, 24, 0, 0, 0, 20, 0, 0, 0, 0,
    0, 0, 20, 0, 0, 0, 0, 24, 0, 0, 0, 0, 20, 0, 0, 0,
    0, 20, 0, 0, 0, 0, 0, 24, 0, 0, 0, 0, 0, 20, 0, 0,
    20, 0, 0, 0, 0, 0, 0, 24, 0, 0, 0, 0, 0, 0, 20,
  ];

  static const List<int> rays = [
    // prevent aggressive reformat
    17, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 15, 0,
    0, 17, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 15, 0, 0,
    0, 0, 17, 0, 0, 0, 0, 16, 0, 0, 0, 0, 15, 0, 0, 0,
    0, 0, 0, 17, 0, 0, 0, 16, 0, 0, 0, 15, 0, 0, 0, 0,
    0, 0, 0, 0, 17, 0, 0, 16, 0, 0, 15, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 17, 0, 16, 0, 15, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 17, 16, 15, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 1, 1, 1, 0, -1, -1, -1, -1, -1, -1, -1, 0,
    0, 0, 0, 0, 0, 0, -15, -16, -17, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, -15, 0, -16, 0, -17, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, -15, 0, 0, -16, 0, 0, -17, 0, 0, 0, 0, 0,
    0, 0, 0, -15, 0, 0, 0, -16, 0, 0, 0, -17, 0, 0, 0, 0,
    0, 0, -15, 0, 0, 0, 0, -16, 0, 0, 0, 0, -17, 0, 0, 0,
    0, -15, 0, 0, 0, 0, 0, -16, 0, 0, 0, 0, 0, -17, 0, 0,
    -15, 0, 0, 0, 0, 0, 0, -16, 0, 0, 0, 0, 0, 0, -17,
  ];

  static const Map<String, String> moveFlags = {
    'NORMAL': 'n',
    'CAPTURE': 'c',
    'PROMOTION': 'p',
  };

  static const Map<String, int> bits = {
    'NORMAL': bitsNormal,
    'CAPTURE': bitsCapture,
    'PROMOTION': bitsPromotion,
  };

  static const int bitsNormal = 1;
  static const int bitsCapture = 2;
  static const int bitsPromotion = 16;

  static const int rank1 = 7;
  static const int rank2 = 6;
  static const int rank3 = 5;
  static const int rank4 = 4;
  static const int rank5 = 3;
  static const int rank6 = 2;
  static const int rank7 = 1;
  static const int rank8 = 0;

  static const Map squares = {
    'a8': 0,
    'b8': 1,
    'c8': 2,
    'd8': 3,
    'e8': 4,
    'f8': 5,
    'g8': 6,
    'h8': 7,
    'a7': 16,
    'b7': 17,
    'c7': 18,
    'd7': 19,
    'e7': 20,
    'f7': 21,
    'g7': 22,
    'h7': 23,
    'a6': 32,
    'b6': 33,
    'c6': 34,
    'd6': 35,
    'e6': 36,
    'f6': 37,
    'g6': 38,
    'h6': 39,
    'a5': 48,
    'b5': 49,
    'c5': 50,
    'd5': 51,
    'e5': 52,
    'f5': 53,
    'g5': 54,
    'h5': 55,
    'a4': 64,
    'b4': 65,
    'c4': 66,
    'd4': 67,
    'e4': 68,
    'f4': 69,
    'g4': 70,
    'h4': 71,
    'a3': 80,
    'b3': 81,
    'c3': 82,
    'd3': 83,
    'e3': 84,
    'f3': 85,
    'g3': 86,
    'h3': 87,
    'a2': 96,
    'b2': 97,
    'c2': 98,
    'd2': 99,
    'e2': 100,
    'f2': 101,
    'g2': 102,
    'h2': 103,
    'a1': 112,
    'b1': 113,
    'c1': 114,
    'd1': 115,
    'e1': 116,
    'f1': 117,
    'g1': 118,
    'h1': 119,
  };

  static const int squaresA1 = 112;
  static const int squaresA8 = 0;
  static const int squaresH1 = 119;
  static const int squaresH8 = 7;

  // Instance Variables
  List<Piece?> board = []..length = 128;
  ColorMap<int> kings = ColorMap(-1);
  PlayerColor turn = red;
  int halfMoves = 0;
  int moveNumber = 1;
  List<GameState> history = [];

  /// By default start with the standard starting position
  Chaturaji() {
    load(defaultPosition);
  }

  /// Start with a position from a FEN
  Chaturaji.fromFEN(String fen) {
    load(fen);
  }

  /// Deep copy of the current Chess instance
  Chaturaji copy() {
    return Chaturaji()
      ..board = List<Piece?>.from(board)
      ..kings = ColorMap<int>.clone(kings)
      ..turn = turn
      ..halfMoves = halfMoves
      ..moveNumber = moveNumber
      ..history = List<GameState>.from(history);
  }

  /// Reset all of the instance variables
  void clear() {
    board = []..length = 128;
    kings = ColorMap(-1);
    turn = red;
    halfMoves = 0;
    moveNumber = 1;
    history = [];
  }

  /// Go back to the starting position
  void reset() {
    load(defaultPosition);
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
      } else if (isDigit(c)) {
        square += int.parse(c);
      } else {
        var color = colors[c]!;
        final piece = position[++i];
        var type = pieceTypes[piece.toLowerCase()]!;
        put(Piece(type, color), algebraic(square));
        square++;
      }
    }

    turn = colors[tokens[1]]!;

    return true;
  }

  /// Returns a bookup FEN String representing the current position
  String generateBfen() {
    var empty = 0;
    var fen = '';

    for (var i = squaresA8; i <= squaresH1; i++) {
      if (board[i] == null) {
        empty++;
      } else {
        if (empty > 0) {
          fen += empty.toString();
          empty = 0;
        }
        var color = board[i]!.color;
        PieceType? type = board[i]!.type;

        fen += (color == red) ? type.toUpperCase() : type.toLowerCase();
      }

      if (((i + 1) & 0x88) != 0) {
        if (empty > 0) {
          fen += empty.toString();
        }

        if (i != squaresH1) {
          fen += '/';
        }

        empty = 0;
        i += 8;
      }
    }

    final turnStr = (turn == red) ? 'r' : 'y';

    return [fen, turnStr].join(' ');
  }

  /// Returns a FEN String representing the current position
  String generateFen() {
    return [generateBfen, halfMoves, moveNumber].join(' ');
  }

  /// Returns the piece at the square in question or null
  /// if there is none
  Piece? get(String square) {
    return board[squares[square]];
  }

  /// Put [piece] on [square]
  bool put(Piece piece, String square) {
    /* check for valid square */
    if (!(squares.containsKey(square))) {
      return false;
    }

    int sq = squares[square];
    board[sq] = piece;
    if (piece.type == king) {
      kings[piece.color] = sq;
    }

    return true;
  }

  /// Removes a piece from a square and returns it,
  /// or null if none is present
  Piece? remove(String square) {
    final piece = get(square);
    board[squares[square]] = null;
    if (piece != null && piece.type == king) {
      kings[piece.color] = -1;
    }

    return piece;
  }

  Move buildMove(List<Piece?> board, from, to, flags, [PieceType? promotion]) {
    if (promotion != null) {
      flags |= bitsPromotion;
    }
    return Move(turn, from, to, flags, board[from]!.type, board[to], promotion);
  }

  List<Move> generateMoves() {
    void addMove(List<Piece?> board, List<Move> moves, from, to, flags) {
      if (board[from]!.type == pawn) {
        switch (board[from]!.color) {
          case red:
            if (to <= 7) flags |= bitsPromotion;
            break;
          case blue:
            if (to % 8 == 7) flags |= bitsPromotion;
            break;
          case yellow:
            if (to >= 112) flags |= bitsPromotion;
            break;
          case green:
            if (to % 8 == 0) flags |= bitsPromotion;
            break;
        }
      }
      PieceType? promotion = flags & bitsPromotion != 0 ? rook : null;
      moves.add(buildMove(board, from, to, flags, promotion));
    }

    final moves = <Move>[];
    final us = turn;
    final secondRank = ColorMap<int>(0);
    secondRank[yellow] = rank7;
    secondRank[red] = rank2;

    var firstSq = squaresA8;
    var lastSq = squaresH1;

    for (var i = firstSq; i <= lastSq; i++) {
      /* did we run off the end of the board */
      if ((i & 0x88) != 0) {
        i += 7;
        continue;
      }

      final piece = board[i];
      if (piece == null || piece.color != us) {
        continue;
      }

      if (piece.type == pawn) {
        /* single square, non-capturing */
        final square = i + pawnOffsets[us]![0];
        if (board[square] == null) {
          addMove(board, moves, i, square, bitsNormal);
        }

        /* pawn captures */
        for (var j = 1; j < 3; j++) {
          var square = i + pawnOffsets[us]![j];
          if ((square & 0x88) != 0) continue;

          if (board[square] != null && board[square]!.color != us) {
            addMove(board, moves, i, square, bitsCapture);
          }
        }
      } else {
        for (var j = 0, len = pieceOffsets[piece.type]!.length; j < len; j++) {
          final offset = pieceOffsets[piece.type]![j];
          var square = i;

          while (true) {
            square += offset;
            if ((square & 0x88) != 0) break;

            if (board[square] == null) {
              addMove(board, moves, i, square, bitsNormal);
            } else {
              if (board[square]!.color == us) {
                break;
              }
              addMove(board, moves, i, square, bitsCapture);
              break;
            }

            /* break, if knight or king */
            if (piece.type == knight || piece.type == king) break;
          }
        }
      }
    }

    return moves;
  }

  /// Convert a move from 0x88 coordinates to Standard Algebraic Notation(SAN)
  String moveToSan(Move move) {
    var output = '';
    final flags = move.flags;

    var disambiguator = getDisambiguator(move);

    if (move.piece != pawn) {
      output += move.piece.toUpperCase() + disambiguator;
    }

    if ((flags & bitsCapture) != 0) {
      if (move.piece == pawn) {
        output += move.fromAlgebraic[0];
      }
      output += 'x';
    }

    output += move.toAlgebraic;

    if ((flags & bitsPromotion) != 0) {
      output += '=${move.promotion!.toUpperCase()}';
    }

    return output;
  }

  bool attacked(PlayerColor color, int square) {
    for (var i = squaresA8; i <= squaresH1; i++) {
      /* did we run off the end of the board */
      if ((i & 0x88) != 0) {
        i += 7;
        continue;
      }

      /* if empty square or wrong color */
      final piece = board[i];
      if (piece == null || piece.color != color) continue;

      final difference = i - square;
      final index = difference + 119;
      final type = piece.type;

      if ((attacks[index] & (1 << type.shift)) != 0) {
        if (type == pawn) {
          if (difference > 0) {
            if (color == red) return true;
          } else {
            if (color == yellow) return true;
          }
          continue;
        }

        /* if the piece is a knight or a king */
        if (type == knight || type == king) return true;

        final offset = rays[index];
        var j = i + offset;

        var blocked = false;
        while (j != square) {
          if (board[j] != null) {
            blocked = true;
            break;
          }
          j += offset;
        }

        if (!blocked) return true;
      }
    }

    return false;
  }

  bool kingAttacked(PlayerColor color) {
    return attacked(color, kings[color]);
  }

  bool get inCheck {
    return kingAttacked(turn);
  }

  bool get inCheckmate {
    return inCheck && generateMoves().isEmpty;
  }

  bool get inStalemate {
    return !inCheck && generateMoves().isEmpty;
  }

  bool get inThreefoldRepetition {
    /* A better implementation would use a Zobrist key (instead of FEN).
     * The Zobrist key would be maintained in the make_move/undo_move functions.
     */
    final positions = {};
    var moves = [];
    var repetition = false;

    while (true) {
      var move = undoMove();
      if (move == null) {
        break;
      }
      moves.add(move);
    }

    while (true) {
      /* remove the last two fields in the FEN string, they're not needed
       * when checking for draw by rep */
      var fen = generateFen().split(' ').sublist(0, 4).join(' ');

      /* has the position occurred three or move times */
      positions[fen] = (positions.containsKey(fen)) ? positions[fen] + 1 : 1;
      if (positions[fen] >= 3) {
        repetition = true;
      }

      if (moves.isEmpty) {
        break;
      }
      makeMove(moves.removeLast());
    }

    return repetition;
  }

  void push(Move move) {
    history.add(
      GameState(move, ColorMap.clone(kings), turn, halfMoves, moveNumber),
    );
  }

  void makeMove(Move move) {
    final us = turn;
    push(move);

    board[move.to] = board[move.from];
    board[move.from] = null;

    /* if pawn promotion, replace with new piece */
    if ((move.flags & bitsPromotion) != 0) {
      board[move.to] = Piece(move.promotion!, us);
    }

    /* if we moved the king */
    if (board[move.to]!.type == king) {
      kings[board[move.to]!.color] = move.to;
    }

    /* reset the 50 move counter if a pawn is moved or a piece is captured */
    if (move.piece == pawn) {
      halfMoves = 0;
    } else if ((move.flags & bitsCapture) != 0) {
      halfMoves = 0;
    } else {
      halfMoves++;
    }

    if (turn == green) {
      moveNumber++;
    }
    turn = nextColor[turn]!;
  }

  /// Undoes a move and returns it, or null if move history is empty
  Move? undoMove() {
    if (history.isEmpty) {
      return null;
    }
    final old = history.removeLast();

    final move = old.move;
    kings = old.kings;
    turn = old.turn;
    halfMoves = old.halfMoves;
    moveNumber = old.moveNumber;

    board[move.from] = board[move.to];
    board[move.from]!.type = move.piece; // to undo any promotions
    board[move.to] = null;

    if ((move.flags & bitsCapture) != 0) {
      board[move.to] = move.captured!;
    }

    return move;
  }

  /* this function is used to uniquely identify ambiguous moves */
  String getDisambiguator(Move move) {
    var moves = generateMoves();

    var from = move.from;
    var to = move.to;
    var piece = move.piece;

    var ambiguities = 0;
    var sameRank = 0;
    var sameFile = 0;

    for (var i = 0, len = moves.length; i < len; i++) {
      var ambigFrom = moves[i].from;
      var ambigTo = moves[i].to;
      var ambigPiece = moves[i].piece;

      /* if a move of the same piece type ends on the same to square, we'll
       * need to add a disambiguator to the algebraic notation
       */
      if (piece == ambigPiece && from != ambigFrom && to == ambigTo) {
        ambiguities++;

        if (rank(from) == rank(ambigFrom)) {
          sameRank++;
        }

        if (file(from) == file(ambigFrom)) {
          sameFile++;
        }
      }
    }

    if (ambiguities > 0) {
      /* if there exists a similar moving piece on the same rank and file as
       * the move in question, use the square as the disambiguator
       */
      if (sameRank > 0 && sameFile > 0) {
        return algebraic(from);
      } /* if the moving piece rests on the same file, use the rank symbol as the
       * disambiguator
       */ else if (sameFile > 0) {
        return algebraic(from)[1];
      } /* else use the file symbol */ else {
        return algebraic(from)[0];
      }
    }

    return '';
  }

  // Utility Functions
  static int rank(int i) {
    return i >> 4;
  }

  static int file(int i) {
    return i & 15;
  }

  static String algebraic(int i) {
    var f = file(i), r = rank(i);
    return 'abcdefgh'.substring(f, f + 1) + '87654321'.substring(r, r + 1);
  }

  static bool isDigit(String c) {
    return '0123456789'.contains(c);
  }

  /// pretty = external move object
  Map<String, dynamic> makePretty(Move uglyMove) {
    final map = <String, dynamic>{};
    map['san'] = moveToSan(uglyMove);
    map['to'] = uglyMove.toAlgebraic;
    map['from'] = uglyMove.fromAlgebraic;
    map['captured'] = uglyMove.captured;

    var flags = '';
    for (var flag in bits.keys) {
      if ((bits[flag]! & uglyMove.flags) != 0) {
        flags += moveFlags[flag]!;
      }
    }
    map['flags'] = flags;

    return map;
  }

  String trim(String str) {
    return str.replaceAll(RegExp(r'^\s+|\s+$'), '');
  }

  //Public APIs

  bool get inDraw {
    return halfMoves >= 100 || inStalemate || inThreefoldRepetition;
  }

  bool get gameOver {
    return inDraw || inCheckmate;
  }

  String get fen {
    return generateFen();
  }

  String get bfen {
    return generateBfen();
  }

  /// The move function can be called with in the following parameters:
  /// .move('Nxb7')      <- where 'move' is a case-sensitive SAN string
  /// .move({ from: 'h7', <- where the 'move' is a move object (additional
  ///      to :'h8',      fields are ignored)
  ///      promotion: 'q',
  ///      })
  /// or it can be called with a Move object
  /// It returns true if the move was made, or false if it could not be.
  bool move(dynamic move) {
    Move? moveObj;
    final moves = generateMoves();

    if (move is String) {
      /* convert the move string to a move object */
      for (var i = 0; i < moves.length; i++) {
        if (move == moveToSan(moves[i])) {
          moveObj = moves[i];
          break;
        }
      }

      for (var i = 0; i < moves.length; i++) {
        String n = normalizeMoveString(moveToSan(moves[i]));
        if (move == n) {
          moveObj = moves[i];
          break;
        }
      }
      // try again with ambiguated move
      move = ambiguate(move);
      for (var i = 0; i < moves.length; i++) {
        String n = normalizeMoveString(moveToSan(moves[i]));
        if (move == n) {
          moveObj = moves[i];
          break;
        }
      }
    } else if (move is Map) {
      /* convert the pretty move object to an ugly move object */
      for (var i = 0; i < moves.length; i++) {
        if (move['from'] == moves[i].fromAlgebraic &&
            move['to'] == moves[i].toAlgebraic) {
          moveObj = moves[i];
          break;
        }
      }
    } else if (move is Move) {
      moveObj = move;
    }

    /* failed to find move */
    if (moveObj == null) {
      return false;
    }

    // need to make a copy of move because we can't generate SAN after the move is made
    makeMove(moveObj);

    return true;
  }

  String ambiguate(String s) {
    var r = RegExp(r"^[NRQ][a-h1-8][a-h][1-8]$");
    if (r.hasMatch(s)) {
      return s.substring(0, 1) + s.substring(2);
    }
    return s;
  }

  String normalizeMoveString(String s) {
    return s.replaceAll(RegExp(r"[x+=#]"), "");
  }

  /// Takeback the last half-move, returning a move Map if successful, otherwise null.
  Map<String, dynamic>? undo() {
    final move = undoMove();
    return (move != null) ? makePretty(move) : null;
  }

  /// Returns the color of the square ('light' or 'dark'), or null if [square] is invalid
  String? squareColor(dynamic square) {
    if (squares.containsKey(square)) {
      final sq_0x88 = squares[square];
      return ((rank(sq_0x88) + file(sq_0x88)) % 2 == 0) ? 'light' : 'dark';
    }

    return null;
  }

  List getHistory([Map? options]) {
    final reversedHistory = <Move?>[];
    final moveHistory = [];
    final verbose =
        (options != null &&
        options.containsKey('verbose') &&
        options['verbose'] == true);

    while (history.isNotEmpty) {
      reversedHistory.add(undoMove());
    }

    while (reversedHistory.isNotEmpty) {
      final move = reversedHistory.removeLast()!;
      if (verbose) {
        moveHistory.add(makePretty(move));
      } else {
        moveHistory.add(moveToSan(move));
      }
      makeMove(move);
    }

    return moveHistory;
  }
}

class Piece {
  PieceType type;
  final PlayerColor color;
  Piece(this.type, this.color);

  bool eq(Piece? piece) {
    return piece != null && type == piece.type && color == piece.color;
  }
}

class PieceType {
  final int shift;
  final String name;
  const PieceType._internal(this.shift, this.name);

  static const PieceType pawn = PieceType._internal(0, 'p');
  static const PieceType knight = PieceType._internal(1, 'n');
  static const PieceType bishop = PieceType._internal(2, 'b');
  static const PieceType rook = PieceType._internal(3, 'r');
  static const PieceType king = PieceType._internal(5, 'k');

  @override
  String toString() => name;
  String toLowerCase() => name;
  String toUpperCase() => name.toUpperCase();
}

class ColorMap<T> {
  T _white;
  T _black;
  ColorMap(T value) : _white = value, _black = value;
  ColorMap.clone(ColorMap other) : _white = other._white, _black = other._black;

  T operator [](PlayerColor color) {
    return (color == red) ? _white : _black;
  }

  void operator []=(PlayerColor color, T value) {
    if (color == red) {
      _white = value;
    } else {
      _black = value;
    }
  }
}

class Move {
  final PlayerColor color;
  final int from;
  final int to;
  final int flags;
  final PieceType piece;
  final Piece? captured;
  final PieceType? promotion;
  const Move(
    this.color,
    this.from,
    this.to,
    this.flags,
    this.piece,
    this.captured,
    this.promotion,
  );

  String get fromAlgebraic {
    return Chaturaji.algebraic(from);
  }

  String get toAlgebraic {
    return Chaturaji.algebraic(to);
  }
}

class GameState {
  final Move move;
  final ColorMap<int> kings;
  final PlayerColor turn;
  final int halfMoves;
  final int moveNumber;
  const GameState(
    this.move,
    this.kings,
    this.turn,
    this.halfMoves,
    this.moveNumber,
  );
}
