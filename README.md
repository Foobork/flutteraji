# Flutteraji

[![Deploy to GitHub Pages](https://github.com/Foobork/flutteraji/actions/workflows/deploy_web.yml/badge.svg)](https://github.com/Foobork/flutteraji/actions/workflows/deploy_web.yml)

Chaturaji analysis tool and engine. Flutteraji combines a Flutter UI for exploring four-player Chaturaji with a C++ search engine and an NNUE value network trained via self-play.

🎮 **[Play Live Web Demo (WASM)](https://foobork.github.io/flutteraji/)**

## Features

- **Chaturaji rules**: Full implementation of piece movement, scoring, and check / double-check / triple-check detection (Dart and C++).
- **Interactive analysis UI**: Play moves, rotate the board by player perspective, undo/reset, and inspect MCTS visit counts (N) and value estimates (Q).
- **Graph-based exploration**: Track positions as a directed graph; export and import analysis graphs.
- **FEN support**: Load and generate Forsyth–Edwards Notation adapted for four-player Chaturaji.
- **C++ engine**: Fast 0x88 board, make/unmake, hand-crafted eval, MCTS, self-play, and head-to-head NNUE matches. Exposed to Dart via FFI (`chaturaji.dll`).
- **NNUE**: Relative-perspective network used as the MCTS leaf evaluator. Gen 4 is the current champion loaded by the UI (`nnue/checkpoints/gen4.nnue`).
- **WebAssembly**: Compiles to WebAssembly (Wasm-GC) for instant browser-based analysis on GitHub Pages.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- For the native engine: CMake and MSVC (Visual Studio 2022) with AVX2 support
- Optional (NNUE training): Python 3 + packages in `nnue/requirements.txt`

### Build the engine

```bat
engine\build.bat
```

Produces `engine/chaturaji.dll` (FFI) and the CLI binary under `engine/build/`. See [`engine/README.md`](engine/README.md) for CLI modes (`validate`, `eval`, `mcts`, `selfplay`, `match`, `probe`, `bench`).

### Run the app

```bash
flutter pub get
flutter run -d windows
```

On Windows desktop the app loads `engine/chaturaji.dll` and, if present, `nnue/checkpoints/gen4.nnue`. Without the DLL it falls back to the Dart board/MCTS path.

## Project Structure

| Path | Role |
|------|------|
| `lib/chaturaji` | Dart game logic, board, moves, eval, MCTS |
| `lib/engine` | Dart FFI bindings to the C++ engine |
| `lib/graph` | Analysis graph (vertices, import/export) |
| `lib/gui` | Board widget and controller |
| `engine/` | C++ engine (board, MCTS, NNUE inference, self-play, match) |
| `nnue/` | Training pipeline (features, model, dataset, export, tests) |
| `nnue/checkpoints/` | Exported `.nnue` / `.pt` weights by generation |
| `test/` | Dart unit and perft tests |
| `tool/` | Helper scripts (e.g. perft compare) |

## NNUE at a glance

Self-play generations are trained in `nnue/` and evaluated with `engine` match mode. Recent results:

| Gen | Result vs previous | Notes |
|-----|--------------------|-------|
| 0 | Bootstrap from hand-crafted eval | Baseline distillation |
| 1 | 134–106 vs Gen 0 | First clear gain |
| 2 | 285–195 vs Gen 1 | Large jump after data/bug fixes |
| 3 | 278–202 vs Gen 2 | Hybrid Q + result training |
| 4 | 304–176 vs Gen 3 | Current champion (UI default) |
| 5 | 236–244 vs Gen 4 | Did not beat Gen 4 |
| 6 | 478–482 vs Gen 4 | Plateaued; opening noise |
| 7 | 446–514 vs Gen 4 | Parallel self-play; offensive parity |

Training details, root-cause diagnosis, and future improvement roadmap live in [`.antigravity/nnue_roadmap.md`](.antigravity/nnue_roadmap.md).

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE).
