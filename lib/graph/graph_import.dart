// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutteraji/chaturaji/game.dart';
import 'package:flutteraji/chaturaji/move.dart';

import 'graph.dart';

void importGraph(String filename) {
  try {
    var cwd = Directory.current;
    print("cwd $cwd");
    print("importGraph $filename");
    var regex = RegExp(r"^(.* .*)$");
    var lines = File(filename).readAsLinesSync();
    int lineNumber = 1;
    for (var line in lines) {
      if (lineNumber % 1000 == 0) print(lineNumber);
      var match = regex.firstMatch(line);
      if (match == null) throw "Can't match $line";
      var fen = match.group(1) as String;
      graph.addVertex(fen);
      var game = ChaturajiGame();
      game.board.load(fen);
      List<Move> moves = game.generateMoves();
      String a = game.generateFen();
      for (var move in moves) {
        game.makeMove(move);
        String b = game.generateFen();
        game.undoMove();
        graph.addVertex(a);
        graph.addEdge(a, move);
        graph.addVertex(b);
      }
      lineNumber++;
    }
    print("importGraph done");
  } catch (e) {
    print(e);
  }
}
