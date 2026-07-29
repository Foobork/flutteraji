# Chaturaji Engine (C++)

Fast standalone Chaturaji engine for search, self-play data generation, and NNUE inference. Built as a shared library for Dart FFI and as a CLI for testing and training workflows.

## Building

```bat
engine\build.bat
```

Requires **CMake** and **MSVC** (Visual Studio 2022, x64) with AVX2. Outputs:

- `engine/chaturaji.dll` — shared library for Flutter/Dart FFI
- CLI binary under `engine/build/` (Release)

## Usage

```
chaturaji.exe [mode]
```

Running without arguments runs the built-in test suite and perft benchmark.

| Mode | Description |
|------|-------------|
| *(none)* | FEN round-trip, make/unmake tests, and perft benchmarks |
| `validate` | Assert perft depths against reference node counts (matches Dart) |
| `eval` | Hand-crafted evaluation for all four players on the start position |
| `mcts` | Run MCTS from the start position; print best move and child stats |
| `selfplay` | Generate self-play training data (`selfplay --help` for options) |
| `match` | Head-to-head match between two NNUE models |
| `probe` | Rank moves by NNUE eval (`probe --nnue <file> [--fen "..."]`) |
| `bench` | Measure NNUE evaluation speed (`bench --nnue <file>`) |
| `api` | Exercise the C API surface used by Dart FFI |

### Examples

```bat
engine\chaturaji.exe
engine\chaturaji.exe validate
engine\chaturaji.exe eval
engine\chaturaji.exe mcts
engine\chaturaji.exe probe --nnue nnue\checkpoints\gen4.nnue
engine\chaturaji.exe match --help
```

## Source files

| File | Description |
|------|-------------|
| `board.h` / `board.cpp` | 0x88 board, move gen, make/unmake, FEN |
| `eval.h` | Hand-crafted evaluation (baseline) |
| `mcts.h` | MCTS with UCT; NNUE or hand-crafted leaf eval |
| `nnue.h` / `nnue.cpp` | NNUE load + AVX2 inference, incremental accumulator |
| `selfplay.h` | Self-play driver for training data |
| `match.h` | NNUE vs NNUE match harness |
| `api.h` / `api.cpp` | C API for Dart FFI |
| `main.cpp` | CLI entry points |
| `build.bat` | CMake Release build |

## Perft reference numbers (start position)

| Depth | Nodes |
|------:|------:|
| 1 | 9 |
| 2 | 81 |
| 3 | 729 |
| 4 | 6 553 |
| 5 | 75 761 |
| 6 | 874 122 |

These match the Dart engine (`test/perft_test.dart`).

## Architecture notes

- **Board**: `uint8_t board[128]` (0x88). Piece encoding aligned with `lib/chaturaji/board.dart`.
- **Make/Unmake**: undo stack — no board copies on the hot path.
- **MCTS**: tree-based; each node stores `visitCount` and per-player `qSum` (rank-points 6/4/2/0).
- **Leaf evaluation**: NNUE when loaded, otherwise `evaluate()` from `eval.h`.
- **UCT constant**: C = 12.0 (matches Dart).
- **FFI**: Flutter loads `chaturaji.dll` via `lib/engine/chaturaji_engine.dart`.
