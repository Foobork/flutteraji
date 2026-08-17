import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutteraji/chaturaji/board.dart';
import 'package:flutteraji/flutteraji.dart';
import 'package:flutteraji/gui/chaturaji_controller.dart';
import 'package:flutteraji/gui/chaturaji_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Controller rotatePieces preference defaults to true and persists changes', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final controller = ChaturajiController();
    await controller.loadPreferences();
    expect(controller.rotatePieces.value, isTrue);

    await controller.setRotatePieces(false);
    expect(controller.rotatePieces.value, isFalse);
    expect(prefs.getBool('rotate_pieces'), isFalse);

    await controller.setRotatePieces(true);
    expect(controller.rotatePieces.value, isTrue);
    expect(prefs.getBool('rotate_pieces'), isTrue);
  });

  testWidgets('BoardPiece rotates with player color when rotatePieces is true', (WidgetTester tester) async {
    // Red pawn: colorTurns = 0 -> turns = 0
    // Blue pawn: colorTurns = 1 -> turns = 1
    // Yellow pawn: colorTurns = 2 -> turns = 2
    // Green pawn: colorTurns = 3 -> turns = 3

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BoardPiece(piece: blue | pawn, rotatePieces: true, boardRotation: 0),
        ),
      ),
    );

    final rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox));
    expect(rotatedBox.quarterTurns, equals(1));
  });

  testWidgets('BoardPiece faces straight up (turns = 0) when rotatePieces is false', (WidgetTester tester) async {
    // Blue pawn with rotatePieces = false and boardRotation = 0 -> turns = 0
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BoardPiece(piece: blue | pawn, rotatePieces: false, boardRotation: 0),
        ),
      ),
    );

    final rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox));
    expect(rotatedBox.quarterTurns, equals(0));
  });

  testWidgets('BoardPiece counter-rotates when board is rotated to stay upright', (WidgetTester tester) async {
    // When boardRotation = 1 (90° CW), piece must have quarterTurns = 3 so net rotation on screen is 0
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BoardPiece(piece: yellow | pawn, rotatePieces: false, boardRotation: 1),
        ),
      ),
    );

    final rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox));
    expect(rotatedBox.quarterTurns, equals(3));
  });

  testWidgets('Ellipsis menu toggles rotatePieces setting', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const Flutteraji());
    await tester.pumpAndSettle();

    // Find the settings ellipsis icon
    final settingsIcon = find.byIcon(Icons.more_vert);
    expect(settingsIcon, findsOneWidget);

    // Open popup menu
    await tester.tap(settingsIcon);
    await tester.pumpAndSettle();

    // Find the menu item with text Pieces Face Center
    final menuItem = find.text('Pieces Face Center');
    expect(menuItem, findsOneWidget);

    await tester.tap(menuItem, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Check that preference was saved as false
    expect(prefs.getBool('rotate_pieces'), isFalse);
  });
}
