import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'chaturaji_engine.dart';
import 'chaturaji_engine_dart.dart';

class EngineInitResult {
  final ChaturajiEngine? engine;
  final bool useNNUE;

  EngineInitResult(this.engine, this.useNNUE);
}

EngineInitResult initPlatformEngine() {
  try {
    final engine = getChaturajiEngine();
    bool useNNUE = false;

    final exeDir = p.dirname(Platform.resolvedExecutable);
    final candidateNNUEPaths = [
      p.join(Directory.current.path, 'nnue', 'checkpoints', 'gen8.nnue'),
      p.join(exeDir, 'nnue', 'checkpoints', 'gen8.nnue'),
      p.join(exeDir, 'checkpoints', 'gen8.nnue'),
      p.join(exeDir, 'gen8.nnue'),
      p.join(exeDir, 'data', 'flutter_assets', 'nnue', 'checkpoints', 'gen8.nnue'),
      p.join(Directory.current.path, 'nnue', 'checkpoints', 'gen4.nnue'),
      p.join(exeDir, 'nnue', 'checkpoints', 'gen4.nnue'),
      p.join(exeDir, 'checkpoints', 'gen4.nnue'),
      p.join(exeDir, 'gen4.nnue'),
      p.join(exeDir, 'data', 'flutter_assets', 'nnue', 'checkpoints', 'gen4.nnue'),
    ];

    String nnuePath = '';
    for (final path in candidateNNUEPaths) {
      if (File(path).existsSync()) {
        nnuePath = path;
        break;
      }
    }

    if (nnuePath.isNotEmpty && File(nnuePath).existsSync()) {
      useNNUE = engine.loadNNUE(nnuePath);
    }
    return EngineInitResult(engine, useNNUE);
  } catch (e) {
    // Fallback to pure Dart engine
    try {
      final dartEngine = ChaturajiEngineDart();
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final candidateNNUEPaths = [
        p.join(Directory.current.path, 'nnue', 'checkpoints', 'gen8.nnue'),
        p.join(exeDir, 'nnue', 'checkpoints', 'gen8.nnue'),
        p.join(exeDir, 'checkpoints', 'gen8.nnue'),
        p.join(exeDir, 'gen8.nnue'),
        p.join(exeDir, 'data', 'flutter_assets', 'nnue', 'checkpoints', 'gen8.nnue'),
        p.join(Directory.current.path, 'nnue', 'checkpoints', 'gen4.nnue'),
        p.join(exeDir, 'nnue', 'checkpoints', 'gen4.nnue'),
        p.join(exeDir, 'checkpoints', 'gen4.nnue'),
        p.join(exeDir, 'gen4.nnue'),
        p.join(exeDir, 'data', 'flutter_assets', 'nnue', 'checkpoints', 'gen4.nnue'),
      ];
      for (final path in candidateNNUEPaths) {
        if (File(path).existsSync()) {
          final bytes = File(path).readAsBytesSync();
          if (dartEngine.loadFromBytes(bytes)) {
            return EngineInitResult(dartEngine, true);
          }
        }
      }
      return EngineInitResult(dartEngine, false);
    } catch (_) {
      return EngineInitResult(null, false);
    }
  }
}
