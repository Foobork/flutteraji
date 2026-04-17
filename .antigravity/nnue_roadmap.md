# NNUE for Chaturaji — Roadmap

## Overview

Building an NNUE (Efficiently Updatable Neural Network) for Chaturaji — a four-player chess variant on an 8×8 board. The network serves as a **value network** inside **MCTS** (AlphaZero-style), avoiding the multi-player minimax problem entirely.

### Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Search** | MCTS + NNUE | Avoids Max^N/Paranoid limitations; scales naturally to 4 players |
| **Engine language** | C++ | Fast enough for self-play; good SIMD support; Dart FFI compatible |
| **Feature encoding** | Relative-Perspective PS (1,600 sparse + 9 dense) | Encodes rotational symmetry; includes dead pieces and points |
| **Training hardware** | Shared GPU (display + training) | Keep batch sizes moderate; train during off-peak |

---

## Current State of the Project

| Component | Status | Location |
|---|---|---|
| Board representation (0x88) — Dart | ✅ Complete | `lib/chaturaji/board.dart` |
| Move generation — Dart | ✅ Complete | `lib/chaturaji/board.dart` |
| FEN encode/decode — Dart | ✅ Complete | `lib/chaturaji/board.dart` |
| MCTS search — Dart | ✅ Basic | `lib/chaturaji/mcts.dart` |
| Hand-crafted eval — Dart | ⚠️ Material only | `getMaterial()` + capture-points |
| Graph / repertoire | ✅ Working | `lib/graph/` |
| Chess.com bot (Selenium) | ✅ Prototype | `chaturbot/` |
| Board representation (0x88) — C++ | ✅ Complete | `engine/board.h`, `engine/board.cpp` |
| Move generation — C++ | ✅ Complete | `engine/board.cpp` |
| Make/Unmake with undo stack — C++ | ✅ Complete | `engine/board.cpp` |
| Perft (validated to depth 6) | ✅ Complete | `engine/main.cpp` — matches Dart counts exactly |
| Hand-crafted eval — C++ | ✅ Complete | `engine/eval.h` |
| MCTS — C++ | ✅ Complete | `engine/mcts.h` |
| Self-play driver | ✅ Complete | `engine/selfplay.h` |
| Self-play data (text format) | ✅ Generated | `engine/selfplay.txt` (~987 KB) |
| Build system | ✅ Complete | `engine/build.bat` (MSVC x86) |
| C API / DLL | ✅ Complete | `engine/api.h`, `engine/api.cpp`, `engine/chaturaji.dll` |
| NNUE feature encoding | ❌ Not started | — |
| PyTorch model | ❌ Not started | — |
| Training pipeline | ❌ Not started | — |
| NNUE inference in C++ | ❌ Not started | — |
| Dart FFI bindings | ❌ Not started | — |

---

## Phase 0 — Hand-Crafted Evaluation Baseline

**Goal:** A measurable baseline the NNUE must eventually beat.

> [!NOTE]
> Phase 0 (Dart-side improvements) was partially skipped in favour of jumping directly to the C++ port.
> The C++ eval (`engine/eval.h`) now serves as the Gen-0 bootstrap evaluator.
> The Dart MCTS remains at its original baseline for now.

### Tasks

- [ ] **Improve the hand-crafted evaluation function** in Dart (deferred — C++ eval is the active baseline)
  - Material balance per player (already exists as `getMaterial()`)
  - Piece-square tables (PSTs) — placement bonuses tuned to 4-player geometry
  - Mobility (legal move count)
  - King safety (attacker proximity, pawn shield)
  - Pawn advancement / promotion proximity
  - Alive-player count adjustment
- [ ] **Establish benchmark protocol** (deferred — will happen once NNUE Gen 1 exists)
  - 4-way self-play round-robins (200+ games)
  - Track average rank-score per "seat" to detect first-move advantage
  - Metric: **average rank-points** (6/4/2/0 scale) — higher is better

---

## Phase 1 — C++ Engine Core ✅ COMPLETE

**Goal:** A fast, standalone Chaturaji engine in C++ for self-play data generation.

### 1a. Board & Move Generation ✅

- [x] Port board representation to C++ (`engine/board.h`)
- [x] Port move generation to C++ (`engine/board.cpp`)
- [x] Implement make/unmake with undo stack
- [x] Implement perft — validated to depth 6 against Dart reference counts

### 1b. MCTS & Self-Play ✅

- [x] Port MCTS from Dart to C++ (`engine/mcts.h`)
  - UCT selection, AlphaZero-style leaf evaluation, rank-point backpropagation (6/4/2/0)
  - UCT constant C = 12.0 (matches Dart)
- [x] Self-play driver (`engine/selfplay.h`)
  - Temperature sampling for first `tempPlies` moves (opening diversity)
  - Output: `<FEN> | <rank_r> <rank_b> <rank_y> <rank_g>` text format
  - 512-ply safety cap per game

### 1c. Build System & C API ✅

- [x] `engine/build.bat` — single-step MSVC build producing `.exe` and `.dll`
- [x] C API surface (`engine/api.h` / `engine/api.cpp`):
  - `engine_create()` / `engine_destroy()`
  - `engine_set_position()` / `engine_get_fen()`
  - `engine_search()` / `engine_get_best_move()` / `engine_get_eval()`
  - `engine_evaluate()` / `engine_apply_move()` / `engine_get_turn()` / `engine_get_points()`
- [x] `engine/chaturaji.dll` compiled and ready for Dart FFI

### Perft Reference (start position)

| Depth | Nodes |
|------:|------:|
| 1 | 9 |
| 2 | 81 |
| 3 | 729 |
| 4 | 6,553 |
| 5 | 75,761 |
| 6 | 874,122 |

---

## Phase 2 — NNUE Architecture Design ✅ COMPLETE

**Goal:** Define and implement the neural network architecture in PyTorch.

### 2a. Feature Encoding — Relative-Perspective PS

Rotate the board so the **active player** is always in the "south" position. Then encode pieces by their relationship to the active player.

#### Sparse Binary Features (~1,600)

```
Own alive pieces:      1 × 5 pieces × 64 squares = 320
Opponent pieces (×3):  3 × 5 pieces × 2 states × 64 = 960  (alive + dead)
                                              Total ≈ 1,280
```

Or the fuller variant:
```
All alive pieces:  4 relationships × 5 pieces × 64 squares = 1,280
Dead pieces:       3 opponent relationships × 5 pieces × 64 =   960
                                                    Total = 2,240
```

A practical starting point: **1,600 features** (4 × 5 × 2 × 40 active squares, sparse). Tune during Phase 4.

Dead pieces matter because:
- They remain on the board and **block movement** (sliding pieces, pawns)
- **Only dead kings are worth points** (3 pts each) — other dead pieces score 0
- They still change the tactical landscape

#### Dense Features (9 floats, appended after accumulator)

```
Points per player:    4 floats (normalized by max ~54)
Alive/dead status:    4 floats (1.0 = alive, 0.0 = dead)
Ply count:            1 float  (normalized)
```

#### Tasks

- [x] Implement `encode_position(board) → (sparse_indices[], dense[9])` — `nnue/features.py`
- [x] Unit test: rotational canonicalisation consistent across all 4 active players
- [x] Unit test: dead piece features appear correctly (colour-invariant, 2 classes)
- [x] Unit test: feature count, index range, no duplicates

#### Files
- `nnue/chaturaji_board.py` — FEN parser + board + canonical rotation
- `nnue/features.py` — 1,408 feature encoder (1,280 alive + 128 dead)
- `nnue/model.py` — `ChaturajiNNUE` PyTorch model
- `nnue/tests/test_features.py` — 20 tests, all passing
- `nnue/requirements.txt` — pinned deps (torch 2.11.0+cpu, numpy 2.4.3, pytest 9.0.3)
- `nnue/.venv/` — Python 3.14 virtualenv (gitignored)

### 2b. Network Architecture

```
┌──────────────────────────┐  ┌──────────────────────┐
│  Sparse Binary Input     │  │  Dense Input          │
│  (1,600 features,        │  │  (9 floats: points,   │
│   ~16–20 active)         │  │   alive, ply)         │
└────────────┬─────────────┘  └──────────┬───────────┘
             │                           │
   ┌─────────▼──────────┐                │
   │   Accumulator       │  ← Efficiently updatable
   │   (256 neurons)     │    add/sub on make/unmake
   │   ClippedReLU       │               │
   └─────────┬──────────┘                │
             │                           │
             └──────────┬────────────────┘
                        │  concatenate [256 + 9 = 265]
              ┌─────────▼──────────┐
              │   Hidden Layer 1    │
              │   (32 neurons)      │
              │   ClippedReLU       │
              └────┬───────────────┘
                   │
              ┌────▼──────┐
              │  Value    │
              │  Head     │
              │(4 floats) │  ← rank probabilities per player
              └───────────┘
```

> [!IMPORTANT]
> **Start without a policy head.** A value-only NNUE with uniform move priors in MCTS is simpler to train and already provides a massive quality improvement over hand-crafted eval. Policy head can be added in a later generation.

#### Tasks

- [ ] Implement `ChaturajiNNUE(nn.Module)` in PyTorch
- [ ] Verify forward pass on a batch of random positions
- [ ] Unit test rotational equivariance: `eval(pos) ≈ eval(rotate(pos))` after re-canonicalization

### 2c. Perspective & Symmetry

- **Always rotate** the input so the active player is in the "south" seat
- Rotation mapping: Red=0°, Blue=90°CW, Yellow=180°, Green=270°CW
- After rotation: `[self, left, across, right]` — the network learns one canonical orientation
- **4× data efficiency** because every game position yields 4 training samples (one per perspective)

---

## Phase 3 — Training Data Generation

**Goal:** Convert self-play output into a clean, packed dataset for PyTorch training.

### 3a. Data Format (packed binary, ~40 bytes/position)

```
active_features[]: uint16 indices (max ~20 active)
dense[9]:          float32
game_result[4]:    float16 (final rank scores: 6/4/2/0 normalized)
```

### 3b. Self-Play Pipeline

```
C++ Engine (MCTS + Eval)
    → selfplay.txt (FEN | rank_r rank_b rank_y rank_g)
    → parse_selfplay.py → filter noisy positions → .bin dataset
    → PyTorch DataLoader → Train NNUE
    → export chaturaji.nnue
    → load into C++ engine (next generation)
```

### 3c. Generation Strategy

**Gen 0 (bootstrap, current data):**
- `engine/selfplay.txt` already generated (~987 KB, text format)
- Convert to binary training format via `tool/parse_selfplay.py` (to be written)

**Gen 1+:**
- MCTS with NNUE from previous generation
- Increase search budget as quality improves (800 → 1,600 → 3,200 iters/move)
- Mix ~20% data from previous generation (prevent catastrophic forgetting)

### 3d. Filtering

Remove positions where:
- Any player is in check (tactically noisy signal)
- Position is from the opening randomized plies (`tempPlies < 8`)
- Duplicate FENs (dedup by hash)

### Tasks

- [ ] Write `tool/parse_selfplay.py` — text → filtered binary `.bin`
- [ ] Write `tool/dataset.py` — PyTorch `Dataset` / `DataLoader` for `.bin` files
- [ ] Generate Gen 0 `.bin` from `engine/selfplay.txt`
- [ ] Verify position count and rank-distribution balance

> [!TIP]
> Since the GPU is shared with your display:
> - Run self-play on **CPU** (NNUE inference is CPU-optimized — that's the point of NNUE)
> - Reserve the GPU for **training only** (batched gradient descent)
> - Use moderate batch sizes (4,096–8,192) to avoid starving the display driver
> - Schedule long training runs overnight

---

## Phase 4 — Training

**Goal:** Train the NNUE weights using PyTorch.

### Tasks

- [ ] Implement custom `DataLoader` with memory-mapped binary files
- [ ] Define loss function:
  ```python
  # Value loss: cross-entropy over 4-player rank prediction
  value_loss = cross_entropy(predicted_values, game_results)
  total_loss = value_loss  # no policy head in Gen 1
  ```
- [ ] Training hyperparameters:
  - Optimizer: Adam, lr=1e-3 with cosine annealing
  - Batch size: 4,096–8,192 (shared GPU constraint)
  - Epochs: 10–20 per generation
  - Weight decay: 1e-4
- [ ] Quantization pipeline:
  - Float32 → Int16 (accumulator layer)
  - Float32 → Int8 (hidden layers)
  - ClippedReLU: clamp to [0, 127] to keep activations in int8 range
  - Validate quantized ≈ float32 within 2% on 10,000 positions
- [ ] Export to `.nnue` binary format:
  ```
  Header:               magic, version, architecture descriptor
  Accumulator weights:  int16[1600 × 256]
  Accumulator biases:   int16[256]
  Hidden weights:       int8[265 × 32]   (256 accum + 9 dense → hidden)
  Hidden biases:        int32[32]
  Value head weights:   int8[32 × 4]
  Value head biases:    int32[4]
  ```
- [ ] Play 200-game match: NNUE Gen 1 vs hand-crafted eval — expect clear improvement

---

## Phase 5 — C++ Engine Integration

**Goal:** Wire the quantized NNUE into the C++ engine's MCTS loop.

### Tasks

- [ ] NNUE inference in C++:
  ```cpp
  // Accumulator (sparse → dense, efficiently updatable)
  int16_t accumulator[256];

  // Hidden layer
  int8_t hidden[32] = matmul_i8(clipped_relu_i16(accumulator), hidden_weights);

  // Value output
  int32_t value[4] = matmul_i32(clipped_relu_i8(hidden), value_weights);
  ```
- [ ] Load `.nnue` file at startup into aligned memory
- [ ] SIMD optimization: SSE2/AVX2 intrinsics for matrix multiplications
- [ ] Incremental accumulator updates on `makeMove()` / `unmakeMove()`
  - On move: `accumulator[i] += weights[added_feature][i]`, `accumulator[i] -= weights[removed_feature][i]`
  - Store delta on undo stack for fast unmake
- [ ] Plug NNUE into MCTS — replace hand-crafted leaf eval with NNUE forward pass

### Performance Targets

| Metric | Target |
|---|---|
| NNUE inference (single position) | < 1 μs |
| MCTS iterations/second | > 100,000 |
| Accumulator update (per move) | < 200 ns |

---

## Phase 6 — Flutter App Integration

**Goal:** Bring the NNUE engine into the Flutter GUI via Dart FFI.

> [!NOTE]
> The C API (`engine/api.h`) and compiled DLL (`engine/chaturaji.dll`) are already in place.
> Phase 6 only requires Dart FFI bindings and UI work.

### Tasks

- [ ] Dart FFI bindings to `chaturaji.dll`:
  ```dart
  Pointer<Void> engineCreate();
  void engineDestroy(Pointer<Void> engine);
  void engineSetPosition(Pointer<Void> engine, Pointer<Utf8> fen);
  void engineSearch(Pointer<Void> engine, int iterations);
  double engineGetEval(Pointer<Void> engine, int player);
  Pointer<Utf8> engineGetBestMove(Pointer<Void> engine);
  ```
- [ ] Run engine on a background `Isolate` (keep UI at 60fps)
- [ ] UI enhancements:
  - 4-color eval bar (stacked horizontal, one colour per player)
  - Best move arrow overlay on board
  - Real-time eval streaming during analysis
  - "Strength" display (NNUE generation + estimated strength)
- [ ] Ship `.nnue` weights as a Flutter asset

---

## Unique Challenges for Four-Player NNUE

| Challenge | Impact | Mitigation |
|---|---|---|
| **4-player output** | Standard NNUE outputs 1 scalar; we need 4 | 4-output value head; softmax for rank prediction |
| **Rotational symmetry** | Board has 4-fold rotational symmetry | Rotate to canonical "south" orientation before eval |
| **Player elimination** | Players die mid-game, changing dynamics | Alive/dead flags in input; dead pieces kept as features |
| **Coalition dynamics** | Players implicitly cooperate against the leader | Emerges from self-play data; no special handling needed |
| **Branching factor** | ~30 legal moves per player per turn | NNUE replaces rollouts → no branching during eval |
| **No existing data** | Can't bootstrap from human game databases | Pure self-play from Gen 0 (hand-crafted eval bootstrap) |
| **Scoring system** | Rank-based (6/4/2/0), not binary win/loss | Loss function targets rank distribution, not win probability |
| **Shared GPU** | Can't dedicate GPU to training | CPU self-play + GPU training in batches; overnight runs |

---

## What to Build Next

**You are at the Phase 1 → Phase 2 boundary.** The recommended next steps in parallel:

1. **Phase 2** — Write the PyTorch feature encoder and `ChaturajiNNUE` model
2. **Phase 3a** — Write `tool/parse_selfplay.py` to convert `engine/selfplay.txt` → `.bin` dataset

Both can proceed simultaneously and are independent of each other.
