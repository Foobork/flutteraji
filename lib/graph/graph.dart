// ignore_for_file: avoid_print

import 'package:flutteraji/chaturaji/move.dart';
import 'package:flutteraji/graph/vertex.dart';

class Graph {
  final Map<String, Vertex> v = {};

  Vertex addVertex(String fen) {
    return v.putIfAbsent(fen, () => Vertex());
  }

  void addEdge(String fen, Move move, [int count = 0]) {
    addVertex(fen).edges.putIfAbsent(move, () => count);
  }
}

// global graph
var graph = Graph();
