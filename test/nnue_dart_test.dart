import 'dart:io';
import 'dart:typed_data';
import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/chaturaji/nnue.dart';
import 'package:test/test.dart';

void main() {
  test('Pure Dart NNUE inference matches C++ on start position', () {
    final model = NNUEModel();
    final file = File('nnue/checkpoints/gen4.nnue');
    expect(file.existsSync(), isTrue);

    final bytes = file.readAsBytesSync();
    expect(model.loadFromBytes(bytes), isTrue);

    final board = Board();
    board.load(startPosition);

    final probs = model.evaluateColors(board);
    print('Dart NNUE Start Position: $probs');

    // C++ output was: [0.266882, 0.239560, 0.257705, 0.235854]
    expect(probs[red], closeTo(0.26688, 0.001));
    expect(probs[blue], closeTo(0.23956, 0.001));
    expect(probs[yellow], closeTo(0.25770, 0.001));
    expect(probs[green], closeTo(0.23585, 0.001));
  });
}
