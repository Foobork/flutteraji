// ignore_for_file: avoid_print

import 'dart:io';

import 'graph.dart';
import '../chess/chess.dart';

var brackets = RegExp(r"[\[\]]");

double? parseEvalString(String? s) {
  if (s == null) return null;
  if (s == "-") return null;
  s = s.replaceAll(brackets, "");
  if (s == "0:1") return -1000;
  if (s.startsWith("#-")) return -990;
  return double.parse(s);
}

void importGraph(String filename) {
  try {
    var cwd = Directory.current;
    print("cwd $cwd");
    print("importGraph $filename");
    var regex = RegExp(r"^(.* .* .* .*) (.*) (.*)$");
    var lines = File(filename).readAsLinesSync();
    int lineNumber = 1;
    for (var line in lines) {
      if (lineNumber % 1000 == 0) print(lineNumber);
      var match = regex.firstMatch(line);
      if (match == null) throw "Can't match $line";
      var bfen = match.group(1) as String;
      var assigned = parseEvalString(match.group(2));
      var computed = parseEvalString(match.group(3));
      graph.addFullVertex(bfen, assigned, computed);
      var game = Chess();
      game.load("$bfen 0 1");
      List<Move> moves = game.generateMoves();
      String a = game.bfen;
      for (var move in moves) {
        game.makeMove(move);
        String b = game.bfen;
        game.undo();
        graph.addLink(a, b);
      }
      lineNumber++;
    }
    print("importGraph done");
  } catch (e) {
    print(e);
  }
}
