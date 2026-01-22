import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutteraji/graph/graph.dart';
import 'package:flutteraji/graph/graph_export.dart';
import 'package:flutteraji/graph/graph_import.dart';
import 'package:flutteraji/chaturaji/move.dart';

void main() {
  test('Graph export and import maintains all data', () {
    // 1. Setup a test graph
    graph.v.clear();
    var fen = "test_fen";
    var vertex = graph.addVertex(fen);
    vertex.N = 42;
    vertex.Q = [1, 2, 3, 4];

    var move1 = const Move(112, 113); // a1-b1
    var move2 = const Move(114, 115); // c1-d1
    graph.addEdge(fen, move1, 10);
    graph.addEdge(fen, move2, 20);

    // 2. Export to a temp file
    var tempFile = "test_graph.txt";
    exportGraph(tempFile);

    // 3. Clear graph and import back
    graph.v.clear();
    importGraph(tempFile);

    // 4. Verify data
    expect(graph.v.containsKey(fen), isTrue);
    var importedVertex = graph.v[fen]!;
    expect(importedVertex.N, equals(42));
    expect(importedVertex.Q, equals([1, 2, 3, 4]));
    expect(importedVertex.edges.length, equals(2));
    expect(importedVertex.edges[move1], equals(10));
    expect(importedVertex.edges[move2], equals(20));

    // Cleanup
    File(tempFile).deleteSync();
  });
}
