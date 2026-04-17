import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

typedef EngineCreateNative = Pointer<Void> Function();
typedef EngineCreate = Pointer<Void> Function();

typedef EngineDestroyNative = Void Function(Pointer<Void> engine);
typedef EngineDestroy = void Function(Pointer<Void> engine);

typedef EngineSetPositionNative = Int32 Function(Pointer<Void> engine, Pointer<Utf8> fen);
typedef EngineSetPosition = int Function(Pointer<Void> engine, Pointer<Utf8> fen);

typedef EngineGetFenNative = Pointer<Utf8> Function(Pointer<Void> engine);
typedef EngineGetFen = Pointer<Utf8> Function(Pointer<Void> engine);

typedef EngineLoadNNUENative = Int32 Function(Pointer<Void> engine, Pointer<Utf8> path);
typedef EngineLoadNNUE = int Function(Pointer<Void> engine, Pointer<Utf8> path);

typedef EngineIsGameOverNative = Int32 Function(Pointer<Void> engine);
typedef EngineIsGameOver = int Function(Pointer<Void> engine);

typedef EngineSearchNative = Void Function(Pointer<Void> engine, Int32 iterations);
typedef EngineSearch = void Function(Pointer<Void> engine, int iterations);

typedef EngineGetBestMoveNative = Pointer<Utf8> Function(Pointer<Void> engine);
typedef EngineGetBestMove = Pointer<Utf8> Function(Pointer<Void> engine);

typedef EngineGetMoveStatsNative = Int32 Function(
    Pointer<Void> engine, Pointer<Utf8> moveStr, Pointer<Int32> nOut, Pointer<Float> qOut);
typedef EngineGetMoveStats = int Function(
    Pointer<Void> engine, Pointer<Utf8> moveStr, Pointer<Int32> nOut, Pointer<Float> qOut);

typedef EngineGetEvalNative = Float Function(Pointer<Void> engine, Int32 player);
typedef EngineGetEval = double Function(Pointer<Void> engine, int player);

typedef EngineEvaluateNative = Void Function(Pointer<Void> engine);
typedef EngineEvaluate = void Function(Pointer<Void> engine);

typedef EngineApplyMoveNative = Int32 Function(Pointer<Void> engine, Pointer<Utf8> moveStr);
typedef EngineApplyMove = int Function(Pointer<Void> engine, Pointer<Utf8> moveStr);

typedef EngineGetTurnNative = Int32 Function(Pointer<Void> engine);
typedef EngineGetTurn = int Function(Pointer<Void> engine);

typedef EngineGetPointsNative = Int32 Function(Pointer<Void> engine, Int32 player);
typedef EngineGetPoints = int Function(Pointer<Void> engine, int player);

class ChaturajiEngine {
  late DynamicLibrary _lib;
  late Pointer<Void> _engine;

  late EngineCreate _create;
  late EngineDestroy _destroy;
  late EngineSetPosition _setPosition;
  late EngineGetFen _getFen;
  late EngineLoadNNUE _loadNNUE;
  late EngineSearch _search;
  late EngineGetBestMove _getBestMove;
  late EngineGetEval _getEval;
  late EngineEvaluate _evaluate;
  late EngineApplyMove _applyMove;
  late EngineGetTurn _getTurn;
  late EngineGetPoints _getPoints;
  late EngineGetMoveStats _getMoveStats;

  ChaturajiEngine() {
    String libraryPath = '';
    if (Platform.isWindows) {
      libraryPath = p.join(Directory.current.path, 'engine', 'chaturaji.dll');
    } else if (Platform.isLinux) {
      libraryPath = p.join(Directory.current.path, 'engine', 'libchaturaji.so');
    } else if (Platform.isMacOS) {
      libraryPath = p.join(Directory.current.path, 'engine', 'libchaturaji.dylib');
    }

    _lib = DynamicLibrary.open(libraryPath);

    _create = _lib.lookupFunction<EngineCreateNative, EngineCreate>('engine_create');
    _destroy = _lib.lookupFunction<EngineDestroyNative, EngineDestroy>('engine_destroy');
    _setPosition = _lib.lookupFunction<EngineSetPositionNative, EngineSetPosition>('engine_set_position');
    _getFen = _lib.lookupFunction<EngineGetFenNative, EngineGetFen>('engine_get_fen');
    _loadNNUE = _lib.lookupFunction<EngineLoadNNUENative, EngineLoadNNUE>('engine_load_nnue');
    _search = _lib.lookupFunction<EngineSearchNative, EngineSearch>('engine_search');
    _getBestMove = _lib.lookupFunction<EngineGetBestMoveNative, EngineGetBestMove>('engine_get_best_move');
    _getEval = _lib.lookupFunction<EngineGetEvalNative, EngineGetEval>('engine_get_eval');
    _evaluate = _lib.lookupFunction<EngineEvaluateNative, EngineEvaluate>('engine_evaluate');
    _applyMove = _lib.lookupFunction<EngineApplyMoveNative, EngineApplyMove>('engine_apply_move');
    _getTurn = _lib.lookupFunction<EngineGetTurnNative, EngineGetTurn>('engine_get_turn');
    _getPoints = _lib.lookupFunction<EngineGetPointsNative, EngineGetPoints>('engine_get_points');
    _getMoveStats = _lib.lookupFunction<EngineGetMoveStatsNative, EngineGetMoveStats>('engine_get_move_stats');

    _engine = _create();
  }

  void dispose() {
    _destroy(_engine);
  }

  bool setPosition(String fen) {
    final nativeFen = fen.toNativeUtf8();
    final result = _setPosition(_engine, nativeFen);
    malloc.free(nativeFen);
    return result == 1;
  }

  String getFen() {
    return _getFen(_engine).toDartString();
  }

  bool loadNNUE(String path) {
    final nativePath = path.toNativeUtf8();
    final result = _loadNNUE(_engine, nativePath);
    malloc.free(nativePath);
    return result == 1;
  }

  void search(int iterations) {
    _search(_engine, iterations);
  }

  String getBestMove() {
    return _getBestMove(_engine).toDartString();
  }

  double getEval(int player) {
    return _getEval(_engine, player);
  }

  Map<String, dynamic>? getMoveStats(String moveStr) {
    final nativeMove = moveStr.toNativeUtf8();
    final nOut = malloc<Int32>();
    final qOut = malloc<Float>(4);
    
    final result = _getMoveStats(_engine, nativeMove, nOut, qOut);
    
    Map<String, dynamic>? stats;
    if (result == 1) {
      stats = {
        'n': nOut.value,
        'q': List.generate(4, (i) => qOut[i]),
      };
    }
    
    malloc.free(nativeMove);
    malloc.free(nOut);
    malloc.free(qOut);
    return stats;
  }

  void evaluate() {
    _evaluate(_engine);
  }

  bool applyMove(String moveStr) {
    final nativeMove = moveStr.toNativeUtf8();
    final result = _applyMove(_engine, nativeMove);
    malloc.free(nativeMove);
    return result == 1;
  }

  int getTurn() {
    return _getTurn(_engine);
  }

  int getPoints(int player) {
    return _getPoints(_engine, player);
  }
}
