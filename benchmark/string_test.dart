// ignore_for_file: avoid_print

import 'package:test/test.dart';

void main() {
  int index = 4;
  int count = 1000000000; // 1 billion iterations
  final Stopwatch stopwatch = Stopwatch();

  test('List lookup', () {
    const List<String> alphabetList = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    String result = "";
    stopwatch.reset();
    stopwatch.start();
    for (int i = 0; i < count; i++) {
      result = alphabetList[index];
    }
    stopwatch.stop();
    print('List lookup took: ${stopwatch.elapsedMilliseconds} ms');
    expect(result, 'e');
  });

  test('Substring', () {
    const String alphabetString = "abcdefghijklmnopqrstuvwxyz";
    String result = "";
    stopwatch.reset();
    stopwatch.start();
    for (int i = 0; i < count; i++) {
      result = alphabetString.substring(index, index + 1);
    }
    stopwatch.stop();
    print('Substring took: ${stopwatch.elapsedMilliseconds} ms');
    expect(result, 'e');
  });

  test('Character arithmetic', () {
    int codeUnit = 'a'.codeUnitAt(0);
    String result = "";
    stopwatch.reset();
    stopwatch.start();
    for (int i = 0; i < count; i++) {
      result = String.fromCharCode(codeUnit + index);
    }
    stopwatch.stop();
    print('Character arithmetic took: ${stopwatch.elapsedMilliseconds} ms');
    expect(result, 'e');
  });
}
