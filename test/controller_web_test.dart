import 'package:flutter/services.dart';
import 'package:flutteraji/gui/chaturaji_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ChaturajiController loads NNUE from bundle assets', () async {
    final controller = ChaturajiController();
    await Future.delayed(const Duration(milliseconds: 100));

    expect(controller.useNNUE, isTrue);
    expect(controller.engine, isNotNull);

    controller.engine!.evaluate();
    for (int i = 0; i < 4; i++) {
      final eval = controller.engine!.getEval(i);
      print('Player $i eval: $eval');
      expect(eval, greaterThan(0.0));
    }
  });
}
