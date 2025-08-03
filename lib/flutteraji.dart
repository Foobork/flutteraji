// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/chaturaji/move.dart';

import 'graph/graph.dart';
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

const Map<int, String> colorNames = {
  red: 'Red',
  blue: 'Blue',
  yellow: 'Yellow',
  green: 'Green',
};

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
            _button("reset", _reset),
            _button("back", _back),
            _button("export", _export),
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
          _text("${colorNames[right]}: ${_controller.game.board.points[right]}"),
        ],
      ),
    );
  }

  dynamic _movesColumn() {
    return _padded(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_movesTable()],
      ),
    );
  }

  dynamic _movesTable() {
    var rows = _knownMoves.map((MoveInfo info) {
      return TableRow(children: [_moveButton(info.move)]);
    }).toList();

    return _padded(
      Table(
        columnWidths: const <int, TableColumnWidth>{
          0: IntrinsicColumnWidth(),
          1: FixedColumnWidth(150),
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
    var board = Board.copy(_controller.game.board);
    List<Move> moves = board.generateMoves();
    String a = board.generateFen();
    for (var move in moves) {
      Board scratch = Board.copy(board);
      scratch.makeMove(move);
      String b = scratch.generateFen();
      graph.addLink(a, b);
    }
    setState(_update);
  }

  void _update() {
    _knownMovesToSan();
    _fen = _controller.game.board.generateFen();
    _turn = "${colorNames[_controller.game.board.turn]!} to move";
    Clipboard.setData(ClipboardData(text: _fen));
  }

  void _knownMovesToSan() {
    _knownMoves = [];
    _controller.generateMoves().forEach(_addMoveIfKnown);
  }

  void _addMoveIfKnown(Move move) {
    var board = _controller.game.board;
    var scratch = Board.copy(board);
    scratch.makeMove(move);
    var vertex = graph.v[scratch.generateFen()];
    if (vertex == null) return;
    if (vertex.links.isEmpty) return;
    _knownMoves.add(MoveInfo(move.toSan()));
  }

  void _back() {
    _controller.undoMove();
  }

  void _reset() {
    _controller.reset();
  }

  void _export() {
    exportGraph("data/Chaturaji.txt");
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
  MoveInfo(this.move);
}
