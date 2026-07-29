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
| Gen 2 | ✅ Complete | Won **285-195** vs Gen 1 |
| Dart FFI / UI | ✅ Working | Loading `gen4.nnue` (Latest Champion) |

---

## Phase 3 — Training Data Generation

### Generation Strategy
- **Gen 0 (bootstrap):** 1.2M positions from hand-crafted eval search. ✅
- **Gen 1:** 1.0M positions using Gen 0 model for guidance. ✅
- **Gen 2:** 1.1M positions using Gen 1 model for guidance. ✅
- **Gen 3:** **Hybrid Training.** Use Gen 2 model to generate 1.1M+ positions including root Q-values for cleaner signal. ✅
- **Gen 4:** **Hybrid Training.** Use Gen 3 model to generate 1M+ positions. ✅
- **Gen 5:** **Hybrid Training.** Use Gen 4 model to generate 1M+ positions. (Failed to beat Gen 4)

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
- [x] **CHT2 Binary Format:** Added support for recording and training on MCTS Q-values

---

## Training History

| Generation | Training Data | Result vs Prev | Notes |
|---|---|---|---|
| **Gen 0** | 1.2M (Baseline Search) | 98-142 vs Baseline | Learned basic game mechanics. |
| Gen 1 | 1.0M (Gen 0 Search) | 134-106 vs Gen 0 | First clear improvement cycle. |
| **Gen 2** | 1.1M (Gen 1 Search) | 285-195 vs Gen 1 | Massive jump after bug fix and data scale-up. |
| **Gen 3** | 0.9M (Gen 2 Hybrid) | 278-202 vs Gen 2 | **Hybrid Q+Result Training.** Significant gain; smarter opening/tactics. |
| **Gen 4** | 1.1M (Gen 3 Hybrid) | 304-176 vs Gen 3 | **Hybrid Q+Result Training.** Continued massive growth. ✅ |
| **Gen 5** | 1.1M (Gen 4 Hybrid) | 236-244 vs Gen 4 | **Stagnation.** Failed to beat Gen 4; potential data saturation or noise. |

---

## Future Directions & Experimentation

### Data Quality & Diversity
- **Increase Search Depth:** Move from 1000 to 2000+ iterations during self-play to provide a cleaner target for the network.
- **Forced Opening Diversity:** Use a randomized set of starting positions or force random moves for the first $N$ plies.
- **Root Temperature Tuning:** Increase exploration in early-game moves to ensure a broader variety of positions are recorded.

### Training Improvements
- **Loss Function Balance:** Tune the weighting between MCTS Q-values and final game results (currently Hybrid).
- **Learning Rate Decay:** Implement a dynamic scheduler (e.g., Cosine Annealing or ReduceLROnPlateau) to push past stagnation.
- **Architecture Scaling:** Evaluate if the 1,408 sparse features are hitting a capacity limit; consider adding deeper interaction terms.

### Engine Polish
- **Threading Support:** Parallelize self-play data generation (current bottle-neck).
- **Time Management:** Implement a proper clock-based search time allocator for real-world play.
