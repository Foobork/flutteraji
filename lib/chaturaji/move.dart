import 'package:equatable/equatable.dart';

class Move extends Equatable {
  final int from;
  final int to;

  const Move(this.from, this.to);

  @override
  // List all properties that should be considered for equality.
  List<Object?> get props => [from, to];

  String toSan() {
    if (from == -1 && to == -1) {
      return "resign"; // Special case for resign move
    }
    return "${squareToSan[from]}-${squareToSan[to]}";
  }

  String toCoordinate() {
    if (from == -1 && to == -1) {
      return "resign";
    }
    return "${squareToSan[from]}${squareToSan[to]}";
  }
}

Move sanToMove(String san) {
  if (san == "resign") {
    return resignMove; // Special case for resign move
  }
  final parts = san.split('-');
  final int from = sanToSquare[parts[0]]!;
  final int to = sanToSquare[parts[1]]!;
  return Move(from, to);
}

const resignMove = Move(-1, -1);

const Map<String, int> sanToSquare = {
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

const Map<int, String> squareToSan = {
  0: 'a8',
  1: 'b8',
  2: 'c8',
  3: 'd8',
  4: 'e8',
  5: 'f8',
  6: 'g8',
  7: 'h8',
  16: 'a7',
  17: 'b7',
  18: 'c7',
  19: 'd7',
  20: 'e7',
  21: 'f7',
  22: 'g7',
  23: 'h7',
  32: 'a6',
  33: 'b6',
  34: 'c6',
  35: 'd6',
  36: 'e6',
  37: 'f6',
  38: 'g6',
  39: 'h6',
  48: 'a5',
  49: 'b5',
  50: 'c5',
  51: 'd5',
  52: 'e5',
  53: 'f5',
  54: 'g5',
  55: 'h5',
  64: 'a4',
  65: 'b4',
  66: 'c4',
  67: 'd4',
  68: 'e4',
  69: 'f4',
  70: 'g4',
  71: 'h4',
  80: 'a3',
  81: 'b3',
  82: 'c3',
  83: 'd3',
  84: 'e3',
  85: 'f3',
  86: 'g3',
  87: 'h3',
  96: 'a2',
  97: 'b2',
  98: 'c2',
  99: 'd2',
  100: 'e2',
  101: 'f2',
  102: 'g2',
  103: 'h2',
  112: 'a1',
  113: 'b1',
  114: 'c1',
  115: 'd1',
  116: 'e1',
  117: 'f1',
  118: 'g1',
  119: 'h1',
};
