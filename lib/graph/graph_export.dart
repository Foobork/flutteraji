// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutteraji/graph/graph.dart';

void exportGraph(String filename) {
  print("exportGraph $filename");
  var file = File(filename).openSync(mode: FileMode.write);
  for (var entry in graph.v.entries) {
    file.writeStringSync("${entry.key}\n");
  }
  file.closeSync();
  print("exportGraph done");
}
