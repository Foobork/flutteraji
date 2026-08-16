import 'chaturaji_engine_interface.dart';

class ChaturajiEngineStub implements ChaturajiEngine {
  ChaturajiEngineStub() {
    throw UnsupportedError('Native C++ FFI engine is not available on this platform.');
  }

  @override
  void dispose() {}

  @override
  bool setPosition(String fen) => false;

  @override
  String getFen() => '';

  @override
  bool loadNNUE(String path) => false;

  @override
  void search(int iterations) {}

  @override
  String getBestMove() => '';

  @override
  double getEval(int player) => 0.0;

  @override
  Map<String, dynamic>? getMoveStats(String moveStr) => null;

  @override
  void evaluate() {}

  @override
  bool applyMove(String moveStr) => false;

  @override
  int getTurn() => 0;

  @override
  int getPoints(int player) => 0;
}

ChaturajiEngine createEngine() => ChaturajiEngineStub();
