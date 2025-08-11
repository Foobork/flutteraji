// ignore_for_file: avoid_print

import 'package:flutteraji/graph/vertex.dart';

class Graph {
  final Map<String, Vertex> v = {};

  Vertex addVertex(String fen) {
    return v.putIfAbsent(fen, () => Vertex());
  }

  void addLink(String a, String b) {
    addVertex(a).links.add(b);
    addVertex(b).backLinks.add(a);
  }
}

// global graph
var graph = Graph();
