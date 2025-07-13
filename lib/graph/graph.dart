// ignore_for_file: avoid_print

import 'dart:math';

class Graph {
  final Map<String, Vertex> v = {};

  Vertex addVertex(String bfen) {
    return v.putIfAbsent(bfen, () => Vertex(bfen));
  }

  Vertex addFullVertex(String bfen, double? assigned, double? computed) {
    Vertex pos = v.putIfAbsent(bfen, () => Vertex(bfen));
    pos.assigned = assigned;
    pos.computed = computed;
    return pos;
  }

  void addLink(String a, String b) {
    addVertex(a).links.add(b);
    addVertex(b).backLinks.add(a);
  }

  void assign(String bfen, double? eval) {
    v[bfen]?.assigned = eval;
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

  void solveBfen(String bfen) {
    var vertex = v[bfen];
    if (vertex == null) return;
    vertex.computed ??= vertex.assigned;
    _solve(vertex.backLinks);
  }

  void _solve(Set<String> todo) {
    while (todo.isNotEmpty) {
      if (todo.length % 10000 == 0) print(todo.length);
      String bfen = todo.elementAt(0);
      todo.remove(bfen);
      Vertex pos = v[bfen] as Vertex;
      double? eval;
      for (String link in pos.links) {
        double? linkEval = v[link]?.computed;
        if (linkEval == null) continue;
        eval ??= linkEval;
        eval = pos.whiteToMove ? max(eval, linkEval) : min(eval, linkEval);
      }
      eval ??= pos.assigned;
      if (pos.computed == eval) continue;
      print("$bfen ${pos.computed} -> $eval");
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

  Vertex(String bfen) {
    whiteToMove = bfen.contains("w");
  }
}

// global graph
var graph = Graph();
