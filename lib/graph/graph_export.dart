// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutteraji/graph/graph.dart';

void exportGraph(String filename) {
  print("exportGraph $filename");
  var file = File(filename).openSync(mode: FileMode.write);
  for (var entry in graph.v.entries) {
    final Q = entry.value.Q;
    final qStr = "${Q[0]}/${Q[1]}/${Q[2]}/${Q[3]}";
    file.writeStringSync("N ${entry.key} $qStr ${entry.value.N}\n");
    for (var edge in entry.value.edges.entries) {
      final move = edge.key;
      final count = edge.value;
      file.writeStringSync("E ${move.toSan()} $count\n");
    }
  }
  file.closeSync();
  print("exportGraph done");
}
