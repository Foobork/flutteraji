abstract class ChaturajiEngine {
  factory ChaturajiEngine() => throw UnsupportedError('Cannot create ChaturajiEngine directly');

  void dispose();
  bool setPosition(String fen);
  String getFen();
  bool loadNNUE(String path);
  void search(int iterations);
  String getBestMove();
  double getEval(int player);
  Map<String, dynamic>? getMoveStats(String moveStr);
  void evaluate();
  bool applyMove(String moveStr);
  int getTurn();
  int getPoints(int player);
}
