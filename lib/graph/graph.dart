// ignore_for_file: avoid_print

import 'dart:math';

class Graph {
  final Map<String, Vertex> v = {};

  Vertex addVertex(String fen) {
    return v.putIfAbsent(fen, () => Vertex(fen));
  }

  Vertex addFullVertex(String fen, double? assigned, double? computed) {
    Vertex pos = v.putIfAbsent(fen, () => Vertex(fen));
    pos.assigned = assigned;
    pos.computed = computed;
    return pos;
  }

  void addLink(String a, String b) {
    addVertex(a).links.add(b);
    addVertex(b).backLinks.add(a);
  }

  void assign(String fen, double? eval) {
    v[fen]?.assigned = eval;
  }

  void solve() {
    Set<String> todo = {};
    for (var vertex in v.values) {
      vertex.computed ??= vertex.assigned;
      if (vertex.computed != null) {
        todo.addAll(vertex.backLinks);
      }
    }
    print(todo.length);
    _solve(todo);
  }

  void solveBfen(String fen) {
    var vertex = v[fen];
    if (vertex == null) return;
    vertex.computed ??= vertex.assigned;
    _solve(vertex.backLinks);
  }

  void _solve(Set<String> todo) {
    while (todo.isNotEmpty) {
      if (todo.length % 10000 == 0) print(todo.length);
      String fen = todo.elementAt(0);
      todo.remove(fen);
      Vertex pos = v[fen] as Vertex;
      double? eval;
      for (String link in pos.links) {
        double? linkEval = v[link]?.computed;
        if (linkEval == null) continue;
        eval ??= linkEval;
        eval = pos.whiteToMove ? max(eval, linkEval) : min(eval, linkEval);
      }
      eval ??= pos.assigned;
      if (pos.computed == eval) continue;
      print("$fen ${pos.computed} -> $eval");
      pos.computed = eval;
      todo.addAll(pos.backLinks);
    }
    print("solved");
  }
}

class Vertex {
  late bool whiteToMove;
  double? assigned;
  double? computed;
  Set<String> links = {};
  Set<String> backLinks = {};

  Vertex(String fen) {
    whiteToMove = fen.contains("w");
  }
}

// global graph
var graph = Graph();
