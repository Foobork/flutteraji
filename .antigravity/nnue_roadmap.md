# NNUE for Chaturaji — Roadmap

## Overview

Building an NNUE (Efficiently Updatable Neural Network) for Chaturaji — a four-player chess variant on an 8×8 board. The network serves as a **value network** inside **MCTS** (AlphaZero-style), avoiding the multi-player minimax problem entirely.

### Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Search** | MCTS + NNUE | Avoids Max^N/Paranoid limitations; scales naturally to 4 players |
| **Engine language** | C++ | Fast enough for self-play; good SIMD support; Dart FFI compatible |
| **Feature encoding** | Relative-Perspective PS (1,408 sparse + 9 dense) | Encodes rotational symmetry; includes dead pieces and points |

---

## Current State of the Project

| Component | Status | Location |
|---|---|---|
| Board representation (0x88) — C++ | ✅ Complete | `engine/board.h`, `engine/board.cpp` |
| Make/Unmake / Undo stack | ✅ Complete | `engine/board.cpp` (Fixed unmake logic) |
| Hand-crafted eval — C++ | ✅ Complete | `engine/eval.h` (Active Baseline) |
| MCTS — C++ | ✅ Complete | `engine/mcts.h` |
| NNUE feature encoding | ✅ Complete | `nnue/features.py` & `engine/nnue.h` (Aligned) |
| NNUE inference in C++ | ✅ Complete | `engine/nnue.h` (AVX2 optimized) |
| Rotation & Symmetry | ✅ Aligned | **RED=South** across C++ and Python |
| Training pipeline | ✅ Working | `nnue/train.py` |
| Gen 0 (Bootstrap) | ✅ Complete | Distilled from 1.2M Baseline positions |
| Gen 1 | ✅ Complete | Won **134-106** vs Gen 0 |
| Dart FFI / UI | ✅ Working | Loading `gen1.nnue` by default |

---

## Phase 3 — Training Data Generation

### Generation Strategy
- **Gen 0 (bootstrap):** 1.2M positions from hand-crafted eval search. ✅
- **Gen 1:** 1.0M positions using Gen 0 model for guidance. ✅
- **Gen 2:** Next step. Use Gen 1 to generate even higher quality data.

---

## Phase 5 — C++ Engine Integration

### Optimization Roadmap
- [x] NNUE inference in C++
- [x] Load `.nnue` file at startup
- [x] SIMD optimization: AVX2 intrinsics
- [x] **Incremental accumulator updates** (Verified with 1000-ply consistency test)
- [x] Plug NNUE into MCTS
- [x] Clean build (Fixed MSVC C4996 warnings)
- [x] Fixed king-capture double-update bug in incremental logic

---

## Training History

| Generation | Training Data | Result vs Prev | Notes |
|---|---|---|---|
| **Gen 0** | 1.2M (Baseline Search) | 98-142 vs Baseline | Learned basic game mechanics. |
| **Gen 1** | 1.0M (Gen 0 Search) | 134-106 vs Gen 0 | First clear improvement cycle. ✅ |
