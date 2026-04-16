# Chaturaji Engine (C++)

A fast, standalone Chaturaji engine used for self-play data generation and NNUE training.

## Building

```bat
engine\build.bat
```

Requires **Visual Studio 2017 Build Tools** (MSVC x86). The resulting binary is `engine\chaturaji.exe`.

## Usage

```
chaturaji.exe [mode]
```

Running without arguments runs the built-in test suite and perft benchmark.

| Mode | Description |
|------|-------------|
| *(none)* | Run FEN round-trip test, make/unmake tests, and perft benchmarks (depths 1–6) |
| `validate` | Re-run perft depths 1–6 and assert against reference node counts (cross-validates against Dart engine) |
| `eval` | Print the hand-crafted evaluation score for all four players on the start position |
| `mcts` | Run 1 000 MCTS iterations from the start position and print the best move + per-child visit stats |

### Examples

```bat
rem Standard test suite + perft benchmark
engine\chaturaji.exe

rem Cross-validate perft node counts
engine\chaturaji.exe validate

rem Show evaluation on start position
engine\chaturaji.exe eval

rem Run MCTS, show best move for Red
engine\chaturaji.exe mcts
```

### Sample output — MCTS

```
=== MCTS (1000 iterations, 7.4 ms) ===
Root visits: 1000
Best move: b1c3

Child stats (move: visits, Q[red]):
  a2a3: N=141    Q[red]=3.86
  b2b3: N=175    Q[red]=4.12
  c2c3: N=178    Q[red]=4.16
  d2d3: N=162    Q[red]=4.04
  b1a3: N=67     Q[red]=2.63
  b1c3: N=187    Q[red]=4.21
  d1e2: N=29     Q[red]=0.62
  d1e1: N=35     Q[red]=1.09
  resign: N=26   Q[red]=0.27
```

## Source files

| File | Description |
|------|-------------|
| `board.h` / `board.cpp` | 0x88 board representation, move generation, make/unmake with undo stack, FEN load/save |
| `eval.h` | Hand-crafted evaluation: earned points, material, pawn advancement, centrality, king safety |
| `mcts.h` | MCTS with UCT selection, AlphaZero-style leaf evaluation, rank-point backpropagation (6/4/2/0) |
| `main.cpp` | Test harness + CLI modes (validate, eval, mcts) |
| `build.bat` | One-step MSVC build script |

## Perft reference numbers (start position)

| Depth | Nodes |
|------:|------:|
| 1 | 9 |
| 2 | 81 |
| 3 | 729 |
| 4 | 6 553 |
| 5 | 75 761 |
| 6 | 874 122 |

These match the Dart engine exactly (cross-validated via `test/perft_test.dart`).

## Architecture notes

- **Board**: `uint8_t board[128]` (0x88 layout). Piece encoding: `color | pieceType | DEAD`. Same bit layout as `board.dart`.
- **Make/Unmake**: undo stack of `UndoInfo` structs — no board copies in the hot path.
- **MCTS**: tree-based (nodes own children via `unique_ptr`). Each node stores `visitCount` and `qSum[4]` (cumulative rank-points per player).
- **Leaf evaluation**: `evaluate()` from `eval.h`, ranked to 6/4/2/0 scale.
- **UCT constant**: C = 12.0 (matches Dart engine).

## Roadmap

- [ ] Self-play driver — generate game records for NNUE training
- [ ] C API surface (`libchaturaji.dll`) for Dart FFI integration
- [ ] NNUE inference (SIMD-accelerated INT8 accumulator)
