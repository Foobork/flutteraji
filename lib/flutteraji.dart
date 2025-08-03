// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutteraji/chaturaji/chaturaji_board.dart';
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
    var board = ChaturajiWidget(controller: _controller);
    var turn = Text(_turn, style: _textStyle);

    var body = Center(
      child: _padded(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: <Widget>[
                Expanded(child: board),
                turn,
                Row(
                  children: [
                    _button("reset", _reset),
                    _button("back", _back),
                    _button("solve", _solve),
                    _button("export", _export),
                  ],
                ),
              ],
            ),
            _movesColumn(),
          ],
        ),
      ),
    );

    return Scaffold(body: body);
  }

  final _controller = ChaturajiController();
  final _textStyle = const TextStyle(fontSize: 20);

  List<MoveInfo> _knownMoves = [];
  String _fen = "";
  String _eval = "";
  String _turn = "";

  dynamic _moveButton(String move) {
    return _button(move, () => _controller.makeMoveWithNormalNotation(move));
  }

  dynamic _movesTable() {
    var rows = _knownMoves.map((MoveInfo info) {
      return TableRow(
        children: [
          _moveButton(info.move),
          Text(info.eval?.toString() ?? "", style: _textStyle),
        ],
      );
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

  dynamic _movesColumn() {
    return _padded(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_evaluationWidget(), _movesTable()],
      ),
    );
  }

  HomePageState() {
    _update();
    _controller.addListener(_boardListener);
  }

  void _boardListener() {
    var board = ChaturajiBoard.copy(_controller.game.board);
    List<Move> moves = board.generateMoves();
    String a = board.generateFen();
    for (var move in moves) {
      ChaturajiBoard scratch = ChaturajiBoard.copy(board);
      scratch.move(move);
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
    _eval = graph.v[_fen]?.assigned?.toString() ?? "";
  }

  void _knownMovesToSan() {
    _knownMoves = [];
    _controller.getPossibleMoves().forEach(_addMoveIfKnown);
    //_knownMoves.sort(_compare(_controller.game.board.turn));
  }

  void _addMoveIfKnown(Move move) {
    var board = _controller.game.board;
    var scratch = ChaturajiBoard.copy(board);
    scratch.move(move);
    var vertex = graph.v[scratch.generateFen()];
    if (vertex == null) return;
    if (vertex.links.isEmpty) return;
    _knownMoves.add(MoveInfo(move.toSan(), vertex.computed));
  }

  void _back() {
    _controller.undoMove();
  }

  void _reset() {
    _controller.resetBoard();
  }

  void _export() {
    exportGraph("data/Chaturaji.txt");
  }

  void _solve() {
    graph.solve();
    _export();
  }

  TextButton _button(String text, action) {
    var child = Text(text, style: _textStyle);
    return TextButton(onPressed: action, child: child);
  }

  Container _padded(dynamic child) {
    var padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8);
    return Container(padding: padding, child: child);
  }

  dynamic _evaluationWidget() {
    return _textField("Evaluation", _eval, _updateEval);
  }

  void _updateEval(String newEval) {
    String fen = _controller.game.fen;
    graph.assign(fen, double.tryParse(newEval));
    graph.solveBfen(fen);
    _export();
  }

  SizedBox _textField(String label, initialValue, onSubmitted) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: TextEditingController(text: initialValue),
        decoration: InputDecoration(
          label: Text(label),
          border: const OutlineInputBorder(),
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }
}

class MoveInfo {
  String move;
  double? eval;

  MoveInfo(this.move, this.eval);
}
