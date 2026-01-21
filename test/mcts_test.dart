// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/chaturaji/mcts.dart';
import 'package:flutteraji/graph/graph.dart';
import 'package:flutteraji/graph/vertex.dart';

void main() {
  test('MCTS search updates the graph', () {
    final board = Board()..reset();
    final initialFen = board.generateFen();

    // Ensure graph is clear
    graph.v.clear();

    final mcts = MCTS();
    const iterations = 10;
    mcts.search(board, iterations);

    // Check if initial vertex exists and has N == iterations
    expect(graph.v.containsKey(initialFen), isTrue);
    Vertex rootVertex = graph.v[initialFen]!;
    expect(rootVertex.N, equals(iterations));

    // Check if some children were created
    expect(graph.v.length, greaterThan(1));

    print('MCTS Test passed! Total vertices in graph: ${graph.v.length}');
    for (var entry in graph.v.entries) {
      if (entry.value.N > 0) {
        print(
          'FEN: ${entry.key.substring(0, 20)}... N: ${entry.value.N} Q: ${entry.value.Q}',
        );
      }
    }
  });
}
