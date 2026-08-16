import 'chaturaji_engine.dart';

class EngineInitResult {
  final ChaturajiEngine? engine;
  final bool useNNUE;

  EngineInitResult(this.engine, this.useNNUE);
}

EngineInitResult initPlatformEngine() {
  // On Web, native C++ FFI is not loaded; the pure Dart MCTS engine is used
  return EngineInitResult(null, false);
}
