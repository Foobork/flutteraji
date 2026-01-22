// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutteraji/chaturaji/move.dart';

import 'graph.dart';

void importGraph(String filename) {
  try {
    var file = File(filename);
    if (!file.existsSync()) {
      print("File $filename does not exist");
      return;
    }
    var vertexRegex = RegExp(r"^N (.*) (.*) (.*)$");
    var edgeRegex = RegExp(r"^E (.*) (\d+)$");
    var lines = file.readAsLinesSync();
    int lineNumber = 1;
    String currentFen = "";
    for (var line in lines) {
      if (lineNumber % 1000 == 0) print(lineNumber);
      var vertexMatch = vertexRegex.firstMatch(line);
      if (vertexMatch != null) {
        currentFen = vertexMatch.group(1)!;
        String qStr = vertexMatch.group(2)!;
        String nStr = vertexMatch.group(3)!;

        var vertex = graph.addVertex(currentFen);
        vertex.N = int.parse(nStr);
        vertex.Q = qStr.split('/').map(int.parse).toList();
      } else {
        var edgeMatch = edgeRegex.firstMatch(line);
        if (edgeMatch != null) {
          var moveSan = edgeMatch.group(1)!;
          int count = int.parse(edgeMatch.group(2)!);
          var move = sanToMove(moveSan);
          graph.addEdge(currentFen, move, count);
        } else {
          print("Can't match line $lineNumber: $line");
        }
      }
      lineNumber++;
    }
    print("importGraph done: ${graph.v.length} vertices");
  } catch (e) {
    print("Error during importGraph: $e");
  }
}
