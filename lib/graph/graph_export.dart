import 'graph.dart';
import 'file_io.dart';

String exportGraphToString() {
  final buffer = StringBuffer();
  for (final entry in graph.v.entries) {
    final Q = entry.value.Q;
    final qStr = "${Q[0]}/${Q[1]}/${Q[2]}/${Q[3]}";
    buffer.writeln("N ${entry.key} $qStr ${entry.value.N}");
    for (final edge in entry.value.edges.entries) {
      final move = edge.key;
      final count = edge.value;
      buffer.writeln("E ${move.toSan()} $count");
    }
  }
  return buffer.toString();
}

void exportGraph(String filename) {
  saveFileDirect(filename, exportGraphToString());
}
