// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chess/chess.dart';
import 'graph/graph.dart';
import 'graph/graph_export.dart';
import 'gui/chess_board.dart';
import 'gui/chess_board_controller.dart';

class Bookup extends StatelessWidget {
  const Bookup({super.key});

  @override
  Widget build(BuildContext context) {
    var theme = ThemeData(primarySwatch: Colors.deepPurple);
    return MaterialApp(title: 'Bookup', theme: theme, home: const HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    var chessboard = ChessBoard(
      controller: _controller,
      boardColor: BoardColor.brown,
      boardOrientation: _orientation,
    );
    var turn = Text(_turn, style: _textStyle);
    var appBar = AppBar(title: const Text('Bookup'));

    var body = Center(
      child: _padded(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: <Widget>[
                Expanded(child: chessboard),
                turn,
                Row(
                  children: [
                    _button("reset", _reset),
                    _button("back", _back),
                    _button("flip", _flip),
                    _button("solve", _solve),
                    _button("export", _export),
                  ],
                )
              ],
            ),
            _movesColumn(),
          ],
        ),
      ),
    );

    return Scaffold(appBar: appBar, body: body);
  }

  final _controller = ChessBoardController();
  final _textStyle = const TextStyle(fontSize: 20);

  List<MoveInfo> _knownMoves = [];
  String _bfen = "";
  String _eval = "";
  String _turn = "";
  PlayerColor _orientation = red;

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
        children: [
          _evaluationWidget(),
          _movesTable(),
        ],
      ),
    );
  }

  HomePageState() {
    _update();
    _controller.addListener(_chessBoardListener);
  }

  void _chessBoardListener() {
    var game = _controller.game.copy();
    List<Move> moves = game.generateMoves();
    String a = game.bfen;
    for (var move in moves) {
      game.makeMove(move);
      String b = game.bfen;
      game.undo();
      graph.addLink(a, b);
    }
    setState(_update);
  }

  void _update() {
    _knownMovesToSan();
    _bfen = _controller.game.bfen;
    _turn = "${colorNames[_controller.game.turn]!} to move";
    Clipboard.setData(ClipboardData(text: _bfen));
    _eval = graph.v[_bfen]?.assigned?.toString() ?? "";
  }

  int Function(MoveInfo i, MoveInfo j) _compare(PlayerColor turn) => (MoveInfo i, MoveInfo j) {
        var a = i.eval;
        var b = j.eval;

        return a == null
            ? b == null
                ? 0
                : 1
            : b == null
                ? 0
                : turn == red
                    ? b.compareTo(a)
                    : a.compareTo(b);
      };

  void _knownMovesToSan() {
    _knownMoves = [];
    _controller.getPossibleMoves().forEach(_addMoveIfKnown);
    _knownMoves.sort(_compare(_controller.game.turn));
  }

  void _addMoveIfKnown(Move move) {
    var game = _controller.game;
    var scratch = game.copy();
    scratch.makeMove(move);
    var vertex = graph.v[scratch.bfen];
    if (vertex == null) return;
    if (vertex.links.isEmpty) return;
    _knownMoves.add(MoveInfo(game.moveToSan(move), vertex.computed));
  }

  void _back() {
    _controller.undoMove();
  }

  void _reset() {
    _controller.resetBoard();
  }

  void _doFlip() {
    _orientation = _orientation == red ? red : yellow;
  }

  void _flip() {
    setState(_doFlip);
  }

  void _export() {
    exportGraph("data/Standard.txt");
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
    String bfen = _controller.game.bfen;
    graph.assign(bfen, double.tryParse(newEval));
    graph.solveBfen(bfen);
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
