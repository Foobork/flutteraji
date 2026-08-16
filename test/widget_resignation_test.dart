import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutteraji/flutteraji.dart';
import 'package:flutteraji/chaturaji/board.dart';

void main() {
  testWidgets('Clicking resign button 3 times updates the UI to Game over and turns Yellow grey', (WidgetTester tester) async {
    await tester.pumpWidget(const Flutteraji());
    await tester.pumpAndSettle();

    // Verify initial turn is Red to move
    expect(find.text('Red to move'), findsOneWidget);

    // Find the 'resign' button in the toolbar
    final resignButton = find.widgetWithText(TextButton, 'resign').first;

    // 1st click: Red resigns -> Blue to move
    await tester.tap(resignButton);
    await tester.pumpAndSettle();
    expect(find.text('Blue to move'), findsOneWidget);

    // 2nd click: Blue resigns -> Yellow to move
    await tester.tap(resignButton);
    await tester.pumpAndSettle();
    expect(find.text('Yellow to move'), findsOneWidget);

    // 3rd click: Yellow resigns -> Game over!
    await tester.tap(resignButton);
    await tester.pumpAndSettle();
    expect(find.text('Game over'), findsOneWidget);
    expect(find.text('Green: 9'), findsOneWidget);
  });
}
