import 'dart:math';
import 'dart:typed_data';
import 'board.dart';

class NNUEModel {
  static const int featSize = 1408;
  static const int accSize = 256;
  static const int denseSize = 9;
  static const int hiddenIn = accSize + denseSize; // 265
  static const int hiddenSize = 32;
  static const int outSize = 4;

  static const int aliveOffset = 0;
  static const int deadOffset = 1280;

  static const List<List<int>> relation = [
    [0, 1, 2, 3], // RED active
    [3, 0, 1, 2], // BLUE active
    [2, 3, 0, 1], // YELLOW active
    [1, 2, 3, 0], // GREEN active
  ];

  late Float32List accWeight;
  late Float32List accBias;
  late Float32List hidWeight;
  late Float32List hidBias;
  late Float32List outWeight;
  late Float32List outBias;

  bool isLoaded = false;

  bool loadFromBytes(Uint8List bytes) {
    if (bytes.length < 32) return false;
    final byteData = ByteData.sublistView(bytes);

    // Verify magic "CHATNNUE"
    final magic = String.fromCharCodes(bytes.sublist(0, 8));
    if (magic != "CHATNNUE") return false;

    // Read header
    int offset = 8;
    // version = byteData.getUint32(offset, Endian.little); offset += 4;
    offset += 4;
    final fSize = byteData.getUint32(offset, Endian.little);
    offset += 4;
    final aSize = byteData.getUint32(offset, Endian.little);
    offset += 4;
    // dSize = byteData.getUint32(offset, Endian.little); offset += 4;
    offset += 4;
    // hSize = byteData.getUint32(offset, Endian.little); offset += 4;
    offset += 4;
    // oSize = byteData.getUint32(offset, Endian.little); offset += 4;
    offset += 4;

    if (fSize != featSize || aSize != accSize) return false;

    // Helper to read float32 array
    Float32List readFloatArray(int count) {
      final list = Float32List(count);
      for (int i = 0; i < count; i++) {
        list[i] = byteData.getFloat32(offset, Endian.little);
        offset += 4;
      }
      return list;
    }

    accWeight = readFloatArray(featSize * accSize);
    accBias = readFloatArray(accSize);
    hidWeight = readFloatArray(hiddenSize * hiddenIn);
    hidBias = readFloatArray(hiddenSize);
    outWeight = readFloatArray(outSize * hiddenSize);
    outBias = readFloatArray(outSize);

    isLoaded = true;
    return true;
  }

  static int canonicalSq(int sq0x88, int active) {
    int r = sq0x88 >> 4;
    int c = sq0x88 & 0x0F;
    int nr, nc;
    switch (active) {
      case 0:
        nr = r;
        nc = c;
        break; // RED
      case 1:
        nr = 7 - c;
        nc = r;
        break; // BLUE
      case 2:
        nr = 7 - r;
        nc = 7 - c;
        break; // YELLOW
      case 3:
        nr = c;
        nc = 7 - r;
        break; // GREEN
      default:
        nr = r;
        nc = c;
        break;
    }
    return nr * 8 + nc;
  }

  static int pieceIdx(int ptype) => (ptype >> 2) - 1;

  /// Evaluates the position and returns [output] probabilities in CANONICAL order:
  /// [self, left, across, right] for the active player.
  List<double> evaluateCanonical(Board board) {
    if (!isLoaded) return [0.25, 0.25, 0.25, 0.25];

    final int active = board.turn == gameOver ? 0 : board.turn;

    // 1. Accumulator forward pass
    final acc = Float32List(accSize);
    for (int j = 0; j < accSize; j++) {
      acc[j] = accBias[j];
    }

    for (int sq = squaresA8; sq <= squaresH1; sq++) {
      if ((sq & 0x88) != 0) {
        sq += 7;
        continue;
      }
      final piece = board.board[sq];
      if (piece == empty) continue;

      final bool isDead = (piece & dead) != 0;
      final int ptype = piece & pieceMask;
      final int color = piece & colorMask;
      final int canonSq = canonicalSq(sq, active);

      int fi;
      if (!isDead) {
        final int rel = relation[active][color];
        final int pid = pieceIdx(ptype);
        fi = aliveOffset + rel * 5 * 64 + pid * 64 + canonSq;
      } else {
        final int dc = (ptype == king) ? 1 : 0;
        fi = deadOffset + dc * 64 + canonSq;
      }

      final int wOffset = fi * accSize;
      for (int j = 0; j < accSize; j++) {
        acc[j] += accWeight[wOffset + j];
      }
    }

    // 2. Clipped ReLU on accumulator + Dense input vector
    final x = Float32List(hiddenIn);
    for (int j = 0; j < accSize; j++) {
      final v = acc[j];
      x[j] = v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v);
    }

    // Check which kings are alive
    final alive = [false, false, false, false];
    for (int sq = squaresA8; sq <= squaresH1; sq++) {
      if ((sq & 0x88) != 0) {
        sq += 7;
        continue;
      }
      final p = board.board[sq];
      if (p != empty && (p & pieceMask) == king && (p & dead) == 0) {
        alive[p & colorMask] = true;
      }
    }

    for (int c = 0; c < 4; c++) {
      final int ci = relation[active][c];
      x[accSize + ci] = board.points[c] / 54.0;
      x[accSize + 4 + ci] = alive[c] ? 1.0 : 0.0;
    }
    x[accSize + 8] = board.ply / 512.0;

    // 3. Hidden layer (32) + Clipped ReLU
    final h = Float32List(hiddenSize);
    for (int i = 0; i < hiddenSize; i++) {
      double sum = hidBias[i];
      final int row = i * hiddenIn;
      for (int j = 0; j < hiddenIn; j++) {
        sum += hidWeight[row + j] * x[j];
      }
      h[i] = sum < 0.0 ? 0.0 : (sum > 1.0 ? 1.0 : sum);
    }

    // 4. Output layer (4) + Softmax
    final logits = Float32List(outSize);
    for (int i = 0; i < outSize; i++) {
      double sum = outBias[i];
      final int row = i * hiddenSize;
      for (int j = 0; j < hiddenSize; j++) {
        sum += outWeight[row + j] * h[j];
      }
      logits[i] = sum;
    }

    double maxL = logits[0];
    for (int i = 1; i < outSize; i++) {
      if (logits[i] > maxL) maxL = logits[i];
    }

    final output = List<double>.filled(outSize, 0.0);
    double expSum = 0.0;
    for (int i = 0; i < outSize; i++) {
      output[i] = exp(logits[i] - maxL);
      expSum += output[i];
    }
    for (int i = 0; i < outSize; i++) {
      output[i] /= expSum;
    }

    return output;
  }

  /// Returns probabilities per player in absolute color order:
  /// [red, blue, yellow, green].
  List<double> evaluateColors(Board board) {
    final canonProbs = evaluateCanonical(board);
    final int active = board.turn == gameOver ? 0 : board.turn;
    final colorProbs = List<double>.filled(4, 0.0);
    for (int c = 0; c < 4; c++) {
      colorProbs[c] = canonProbs[relation[active][c]];
    }
    return colorProbs;
  }
}
