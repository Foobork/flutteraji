import 'package:flutter_test/flutter_test.dart';
import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/chaturaji/move.dart';
import 'package:flutteraji/engine/chaturaji_engine_dart.dart';
import 'package:flutteraji/gui/chaturaji_controller.dart';

void main() {
  test('Three resignations consecutively with pure Dart engine', () {
    final controller = ChaturajiController();
    // Attach pure Dart engine (as used on Web)
    final dartEngine = ChaturajiEngineDart();
    controller.engine = dartEngine;

    // Initial state: Red to move (turn = 0)
    expect(controller.game.board.turn, equals(red));
    expect(controller.game.board.liveColors, equals({red, blue, yellow, green}));

    int notifyCount = 0;
    controller.addListener(() {
      notifyCount++;
    });

    // 1st resignation: Red resigns
    controller.makeMove(resignMove);
    expect(controller.game.board.turn, equals(blue));
    expect(controller.game.board.liveColors, equals({blue, yellow, green}));
    expect(notifyCount, equals(1));

    // 2nd resignation: Blue resigns
    controller.makeMove(resignMove);
    expect(controller.game.board.turn, equals(yellow));
    expect(controller.game.board.liveColors, equals({yellow, green}));
    expect(notifyCount, equals(2));

    // 3rd resignation: Yellow resigns
    controller.makeMove(resignMove);
    expect(controller.game.board.turn, equals(gameOver));
    expect(controller.game.board.liveColors, equals({green}));
    expect(controller.game.board.points[green], equals(9));
    expect(notifyCount, equals(3));

    // Check that Yellow's pieces are marked dead on the board
    for (int sq = squaresA8; sq <= squaresH1; sq++) {
      if ((sq & 0x88) != 0) {
        sq += 7;
        continue;
      }
      final piece = controller.game.board.board[sq];
      if (piece != empty && (piece & colorMask) == yellow) {
        expect((piece & dead), equals(dead), reason: 'Yellow piece at $sq should be dead');
      }
    }
  });
}
