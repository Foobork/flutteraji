import 'package:flutter/material.dart';

import 'bookup.dart';
import 'graph/graph_import.dart';

void main() {
  importGraph("data/Chaturaji.txt");
  runApp(const Bookup());
}
