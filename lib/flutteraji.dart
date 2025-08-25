// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/chaturaji/move.dart';
import 'package:flutteraji/graph/vertex.dart';
import 'package:flutteraji/graph/graph.dart';
import 'graph/graph_export.dart';
import 'gui/chaturaji_widget.dart';
import 'gui/chaturaji_controller.dart';

class Flutteraji extends StatelessWidget {
  const Flutteraji({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

const List<String> colorNames = ['Red', 'Blue', 'Yellow', 'Green'];

class HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    var body = Center(
      child: _padded(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_boardColumn(), _movesColumn()],
        ),
      ),
    );

    return Scaffold(body: body);
  }

  final _controller = ChaturajiController();
  final _textStyle = const TextStyle(fontSize: 20);

  List<MoveInfo> _knownMoves = [];
  String _fen = "";
  String _turn = "";

  dynamic _moveButton(String move) {
    return _button(move, () => _controller.makeSanMove(move));
  }

  dynamic _boardColumn() {
    var board = ChaturajiWidget(controller: _controller);
    var turn = _text(_turn);

    return Column(
      children: <Widget>[
        _pointsRow(blue, yellow),
        Expanded(child: board),
        _pointsRow(red, green),
        turn,
        Row(
          children: [
            _button("resign", _resign),
            _button("reset", _reset),
            _button("back", _back),
            _button("export", _export),
            _button("backprop", _backprop),
          ],
        ),
      ],
    );
  }

  dynamic _pointsRow(int left, int right) {
    return SizedBox(
      width: 300,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _text("${colorNames[left]}: ${_controller.game.board.points[left]}"),
          _text(
            "${colorNames[right]}: ${_controller.game.board.points[right]}",
          ),
        ],
      ),
    );
  }

  dynamic _movesColumn() {
    return _padded(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_scoresSection(), _movesTable()],
      ),
    );
  }

  dynamic _scoresSection() {
    var board = _controller.game.board;
    var fen = board.generateFen();
    Vertex? v = graph.v[fen];

    if (v == null) {
      return _text("No vertex data available");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        _text("N: ${v.N} | Q: ${v.Q[0]}, ${v.Q[1]}, ${v.Q[2]}, ${v.Q[3]}"),
        const SizedBox(height: 16),
      ],
    );
  }

  dynamic _movesTable() {
    var rows = _knownMoves.map((MoveInfo info) {
      return TableRow(
        children: [
          _moveButton(info.move),
          _text("${info.count}"),
          _text(
            "N: ${info.childN} | Q: ${info.childQ[0]}, ${info.childQ[1]}, ${info.childQ[2]}, ${info.childQ[3]}",
          ),
        ],
      );
    }).toList();

    return _padded(
      Table(
        columnWidths: const <int, TableColumnWidth>{
          0: IntrinsicColumnWidth(),
          1: FixedColumnWidth(60),
          2: IntrinsicColumnWidth(),
        },
        children: rows,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      ),
    );
  }

  HomePageState() {
    _update();
    _controller.addListener(_boardListener);
  }

  void _boardListener() {
    setState(_update);
  }

  void _update() {
    var board = _controller.game.board;
    _fen = board.generateFen();
    Vertex? v = graph.v[_fen];
    if (v != null) {
      _knownMoves = v.edges.entries.map((entry) {
        final move = entry.key;
        final count = entry.value;
        // compute child vertex by applying move on a copy
        final b = Board.copy(board);
        b.makeMove(move);
        final childFen = b.generateFen();
        final childV = graph.v[childFen];
        final childN = childV?.N ?? 0;
        final childQ = childV?.Q ?? [0, 0, 0, 0];
        return MoveInfo(move.toSan(), count, childN, childQ);
      }).toList();
    } else {
      _knownMoves = [];
    }
    _turn = switch (board.turn) {
      gameOver => "Game over",
      _ => "${colorNames[board.turn]} to move",
    };
    Clipboard.setData(ClipboardData(text: _fen));
  }

  void _back() {
    _controller.undoMove();
  }

  void _reset() {
    _controller.reset();
  }

  void _resign() {
    _controller.makeMove(resignMove);
  }

  void _export() {
    exportGraph("data/Chaturaji.txt");
  }

  void _backprop() {
    _controller.game.manualBackpropagate();
  }

  TextButton _button(String text, action) {
    var child = _text(text);
    return TextButton(onPressed: action, child: child);
  }

  Text _text(String text) {
    return Text(text, style: _textStyle);
  }

  Container _padded(dynamic child) {
    var padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8);
    return Container(padding: padding, child: child);
  }
}

class MoveInfo {
  String move;
  int count;
  int childN;
  List<int> childQ;
  MoveInfo(this.move, this.count, this.childN, this.childQ);
}
