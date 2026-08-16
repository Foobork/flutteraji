import 'chaturaji_engine.dart';
import 'chaturaji_engine_dart.dart';

class EngineInitResult {
  final ChaturajiEngine? engine;
  final bool useNNUE;

  EngineInitResult(this.engine, this.useNNUE);
}

EngineInitResult initPlatformEngine() {
  // On Web, return pure Dart engine ready to load NNUE from asset bundle
  return EngineInitResult(ChaturajiEngineDart(), false);
}
