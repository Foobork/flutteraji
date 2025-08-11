// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutteraji/chaturaji/move.dart';

import 'graph.dart';

void importGraph(String filename) {
  try {
    var cwd = Directory.current;
    print("cwd $cwd");
    print("importGraph $filename");
    var vertexRegex = RegExp(r"^N (.* .* .*) (.*) (.*)$");
    var edgeRegex = RegExp(r"^E (.*) (\d+)$");
    var lines = File(filename).readAsLinesSync();
    int lineNumber = 1;
    String fen = "";
    for (var line in lines) {
      if (lineNumber % 1000 == 0) print(lineNumber);
      var vertexMatch = vertexRegex.firstMatch(line);
      if (vertexMatch != null) {
        fen = vertexMatch.group(1)!;
        graph.addVertex(fen);
      } else {
        var edgeMatch = edgeRegex.firstMatch(line);
        if (edgeMatch == null) {
          print("Can't match $line");
        } else {
          var move = sanToMove(edgeMatch.group(1)!);
          graph.addEdge(fen, move);
          continue;
        }
      }
      lineNumber++;
    }
    print("importGraph done");
  } catch (e) {
    print(e);
  }
}
