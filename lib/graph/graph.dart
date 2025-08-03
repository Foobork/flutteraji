// ignore_for_file: avoid_print

class Graph {
  final Map<String, Vertex> v = {};

  Vertex addVertex(String fen) {
    return v.putIfAbsent(fen, () => Vertex(fen));
  }

  Vertex addFullVertex(String fen, double? assigned, double? computed) {
    Vertex pos = v.putIfAbsent(fen, () => Vertex(fen));
    return pos;
  }

  void addLink(String a, String b) {
    addVertex(a).links.add(b);
    addVertex(b).backLinks.add(a);
  }

}

class Vertex {
  Set<String> links = {};
  Set<String> backLinks = {};

  Vertex(String fen);
}

// global graph
var graph = Graph();
