import 'dart:convert';
import 'package:flutteraji/chaturaji/move.dart';
import 'graph.dart';
import 'file_io.dart';

int importGraphFromString(String content) {
  int initialCount = graph.v.length;
  try {
    final vertexRegex = RegExp(r"^N (.*) (.*) (.*)$");
    final edgeRegex = RegExp(r"^E (.*) (\d+)$");
    final lines = const LineSplitter().convert(content);
    String currentFen = "";

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final vertexMatch = vertexRegex.firstMatch(line);
      if (vertexMatch != null) {
        currentFen = vertexMatch.group(1)!;
        final qStr = vertexMatch.group(2)!;
        final nStr = vertexMatch.group(3)!;

        final vertex = graph.addVertex(currentFen);
        vertex.N = int.parse(nStr);
        vertex.Q = qStr.split('/').map(double.parse).toList();
      } else {
        final edgeMatch = edgeRegex.firstMatch(line);
        if (edgeMatch != null) {
          final moveSan = edgeMatch.group(1)!;
          final count = int.parse(edgeMatch.group(2)!);
          final move = sanToMove(moveSan);
          graph.addEdge(currentFen, move, count);
        }
      }
    }
  } catch (e) {
    print("Error during importGraphFromString: $e");
  }
  return graph.v.length - initialCount;
}

void importGraph(String filename) {
  final content = readFileDirect(filename);
  if (content != null) {
    importGraphFromString(content);
  }
}
