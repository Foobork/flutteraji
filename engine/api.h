#pragma once

// Chaturaji Engine C API
// Import this from Dart via dart:ffi
//
// Each opaque Engine handle manages: board position, MCTS tree, cached results.
// The handle is allocated on the heap — call engine_destroy() when done.

#ifdef _WIN32
  #ifdef CHATURAJI_BUILD_DLL
    #define CHATURAJI_API __declspec(dllexport)
  #else
    #define CHATURAJI_API __declspec(dllimport)
  #endif
#else
  #define CHATURAJI_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// --- Lifecycle ---

/// Create a new engine instance, loaded at the start position.
CHATURAJI_API void* engine_create(void);

/// Free all resources owned by the engine.
CHATURAJI_API void engine_destroy(void* engine);

// --- Position ---

/// Load a position from a FEN string.
/// Returns 1 on success, 0 if the FEN is invalid.
CHATURAJI_API int engine_set_position(void* engine, const char* fen);

/// Get the current position as a FEN string.
/// The returned pointer is valid until the next API call on this engine.
CHATURAJI_API const char* engine_get_fen(void* engine);

/// Returns 1 if the game is over (no legal moves / only one player left).
CHATURAJI_API int engine_is_game_over(void* engine);

// --- Search ---

/// Run MCTS for the given number of iterations.
/// Call engine_get_best_move() / engine_get_eval() after this.
CHATURAJI_API void engine_search(void* engine, int iterations);

/// Returns the best move in coordinate notation (e.g. "b1c3") or "resign".
/// The returned pointer is valid until the next engine_search() call.
CHATURAJI_API const char* engine_get_best_move(void* engine);

/// Returns the Q-value (mean rank-points) for `player` (0=red,1=blue,2=yellow,3=green)
/// from the last search. Returns 0.0 if no search has been run.
CHATURAJI_API float engine_get_eval(void* engine, int player);

// --- Direct evaluation (no search) ---

/// Run the hand-crafted evaluation on the current position.
/// Stores results internally; retrieve with engine_get_eval().
CHATURAJI_API void engine_evaluate(void* engine);

// --- Move application ---

/// Apply a move in coordinate notation (e.g. "b1c3" or "resign").
/// Returns 1 on success, 0 if the move string is invalid or illegal.
CHATURAJI_API int engine_apply_move(void* engine, const char* moveStr);

/// Returns the current player to move: 0=red, 1=blue, 2=yellow, 3=green, -1=game_over.
CHATURAJI_API int engine_get_turn(void* engine);

/// Returns the earned point total for `player`.
CHATURAJI_API int engine_get_points(void* engine, int player);

#ifdef __cplusplus
}
#endif
