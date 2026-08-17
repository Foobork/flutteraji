import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/chaturaji/move.dart';
import 'package:flutteraji/graph/vertex.dart';
import 'package:flutteraji/graph/graph.dart';
import 'graph/graph_export.dart';
import 'graph/graph_import.dart';
import 'graph/file_io.dart';
import 'gui/chaturaji_widget.dart';
import 'gui/chaturaji_controller.dart';

class Flutteraji extends StatelessWidget {
  const Flutteraji({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
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
          children: [
            _boardColumn(),
            Expanded(child: _movesColumn()),
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
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _button("resign", _resign),
            _button("reset", _reset),
            _button("back", _back),
            _button("rotate", _rotate),
            _button("import", _import),
            _button("export", _export),
            _button("mcts", _mcts),
            _settingsMenu(),
          ],
        ),
      ],
    );
  }

  dynamic _pointsRow(int left, int right) {
    return SizedBox(
      width: 380,
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
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_scoresSection(), _nnueSection(), _movesTable()],
        ),
      ),
    );
  }

  dynamic _nnueSection() {
    if (_controller.game.board.turn == gameOver) {
      return const SizedBox.shrink();
    }

    if (!_controller.useNNUE || _controller.engine == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _text("NNUE: Loading Gen 4 model...", style: _textStyle.copyWith(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 16),
        ],
      );
    }

    _controller.engine!.evaluate();
    String nnueRow = [0, 1, 2, 3]
        .map((i) {
          double score = _controller.engine!.getEval(i);
          return "${colorNames[i][0]}: ${score.toStringAsFixed(2)}";
        })
        .join(" | ");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text("NNUE: $nnueRow", style: _textStyle.copyWith(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
      ],
    );
  }

  dynamic _scoresSection() {
    var board = _controller.game.board;
    var fen = board.generateFen();
    Vertex? v = graph.v[fen];

    if (v == null) {
      return _text("No vertex data available");
    }

    String qnRow = [0, 1, 2, 3]
        .map((i) {
          double qn = v.N == 0 ? 0 : v.Q[i] / v.N;
          return "${colorNames[i][0]}: ${qn.toStringAsFixed(2)}";
        })
        .join(" | ");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        _text("N: ${v.N} | Q: ${v.Q[0].toStringAsFixed(2)}, ${v.Q[1].toStringAsFixed(2)}, ${v.Q[2].toStringAsFixed(2)}, ${v.Q[3].toStringAsFixed(2)}"),
        _text("E: $qnRow"),
        const SizedBox(height: 16),
      ],
    );
  }

  dynamic _movesTable() {
    var rows = _knownMoves.map((MoveInfo info) {
      int turn = _controller.game.board.turn;
      double qn = 0;
      if (turn != gameOver && info.childN > 0) {
        qn = info.childQ[turn] / info.childN;
      }
      return TableRow(
        children: [
          _moveButton(info.move),
          _text("${info.count}"),
          _text(
            "E: ${qn.toStringAsFixed(2)} | N: ${info.childN} | Q: ${info.childQ[0].toStringAsFixed(2)}, ${info.childQ[1].toStringAsFixed(2)}, ${info.childQ[2].toStringAsFixed(2)}, ${info.childQ[3].toStringAsFixed(2)}",
            style: _textStyle.copyWith(fontSize: 14),
          ),
        ],
      );
    }).toList();

    return _padded(
      Table(
        columnWidths: const <int, TableColumnWidth>{
          0: IntrinsicColumnWidth(),
          1: FixedColumnWidth(100),
          2: IntrinsicColumnWidth(),
        },
        children: rows,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller.loadPreferences();
    _controller.addListener(_boardListener);
    _update();
  }

  @override
  void dispose() {
    _controller.removeListener(_boardListener);
    _controller.dispose();
    super.dispose();
  }

  void _boardListener() {
    if (mounted) {
      setState(_update);
    }
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
        final childQ = childV?.Q ?? [0.0, 0.0, 0.0, 0.0];
        return MoveInfo(move.toSan(), count, childN, childQ);
      }).toList();

      // Sort by win rate for current color: childQ[board.turn] / childN
      if (board.turn != gameOver && board.turn < 4) {
        _knownMoves.sort((a, b) {
          int t = board.turn;
          double scoreA = a.childN == 0 ? 0 : a.childQ[t] / a.childN;
          double scoreB = b.childN == 0 ? 0 : b.childQ[t] / b.childN;
          return scoreB.compareTo(scoreA); // Descending: best move on top
        });
      }
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

  Future<void> _import() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        withData: true,
      );
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final content = utf8.decode(bytes);
        final added = importGraphFromString(content);
        _update();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported $added positions from ${file.name} (Total: ${graph.v.length})')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _export() async {
    try {
      final content = exportGraphToString();
      await saveTextFile("Chaturaji.txt", content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${graph.v.length} positions to Chaturaji.txt')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _mcts() {
    _controller.runMCTS(100000);
  }

  void _rotate() {
    _controller.rotate();
  }

  TextButton _button(String text, action) {
    var child = _text(text);
    return TextButton(onPressed: action, child: child);
  }

  Text _text(String text, {TextStyle? style}) {
    return Text(text, style: style ?? _textStyle);
  }

  Container _padded(dynamic child) {
    var padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8);
    return Container(padding: padding, child: child);
  }

  Widget _settingsMenu() {
    return ValueListenableBuilder<bool>(
      valueListenable: _controller.rotatePieces,
      builder: (context, rotatePieces, _) {
        return PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 22),
          tooltip: "Settings",
          padding: EdgeInsets.zero,
          onSelected: (String value) {
            if (value == 'toggle_rotation') {
              _controller.setRotatePieces(!rotatePieces);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            CheckedPopupMenuItem<String>(
              value: 'toggle_rotation',
              checked: rotatePieces,
              child: const Text('Pieces Face Center'),
            ),
          ],
        );
      },
    );
  }
}

class MoveInfo {
  String move;
  int count;
  int childN;
  List<double> childQ;
  MoveInfo(this.move, this.count, this.childN, this.childQ);
}
