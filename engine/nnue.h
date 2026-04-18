// nnue.h
// ------
// Chaturaji NNUE inference — C++ equivalent of Python model.py + features.py.
//
// Architecture (must match Python model.py exactly):
//   Sparse accumulator (EmbeddingBag): 1,408 features -> 256 neurons
//   acc_bias:    256
//   ClippedReLU [0,1]
//   Dense bypass: 9 floats (points[4] + alive[4] + ply_norm)
//   Concatenate: [256 + 9] = 265
//   Hidden:      265 -> 32, ClippedReLU
//   Output:      32  ->  4, softmax
//   Result:      rank probabilities [self, left, across, right]
//
// Feature encoding (must match Python features.py exactly):
//   Alive [0..1279]:   4 relations x 5 piece types x 64 squares
//   Dead [1280..1407]: 2 classes (0=non-king, 1=king) x 64 squares (colour-agnostic)
//
// Binary .nnue format: see nnue/export.py for the full specification.

#pragma once
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>
#include <immintrin.h>
#include "board.h"

// ---------------------------------------------------------------------------
// Architecture constants — must match Python model.py / features.py
// ---------------------------------------------------------------------------
static constexpr int NNUE_FEAT_SIZE   = 1408;  // 1280 alive + 128 dead
static constexpr int NNUE_ACC_SIZE    = 256;
static constexpr int NNUE_DENSE_SIZE  = 9;
static constexpr int NNUE_HIDDEN_IN   = NNUE_ACC_SIZE + NNUE_DENSE_SIZE;  // 265
static constexpr int NNUE_HIDDEN_SIZE = 32;
static constexpr int NNUE_OUT_SIZE    = 4;

static constexpr int NNUE_ALIVE_OFFSET = 0;
static constexpr int NNUE_DEAD_OFFSET  = 1280;  // 4 * 5 * 64

// Canonical rotation map: NNUE_RELATION[active_color][piece_color] = relation index
// Mirrors Python chaturaji_board.ROTATION_MAP exactly.
//   Relation 0 = self, 1 = left, 2 = across, 3 = right
static const int NNUE_RELATION[4][4] = {
    {0, 1, 2, 3},   // RED active
    {3, 0, 1, 2},   // BLUE active
    {2, 3, 0, 1},   // YELLOW active
    {1, 2, 3, 0},   // GREEN active
};

// ---------------------------------------------------------------------------
// NNUEModel — loaded weights + inference
// ---------------------------------------------------------------------------
struct NNUEModel {
    // All weights stored flat, row-major (same layout as numpy's default).
    std::vector<float> acc_weight;  // [FEAT_SIZE * ACC_SIZE]
    std::vector<float> acc_bias;    // [ACC_SIZE]
    std::vector<float> hid_weight;  // [HIDDEN_SIZE * HIDDEN_IN]
    std::vector<float> hid_bias;    // [HIDDEN_SIZE]
    std::vector<float> out_weight;  // [OUT_SIZE * HIDDEN_SIZE]
    std::vector<float> out_bias;    // [OUT_SIZE]

    bool loaded = false;

    // Load weights from a .nnue binary file.
    // Returns true on success, false on any error.
    bool load(const std::string& path) {
        FILE* f = fopen(path.c_str(), "rb");
        if (!f) {
            fprintf(stderr, "NNUE: cannot open '%s'\n", path.c_str());
            return false;
        }

        // Magic
        char magic[9] = {};
        if (fread(magic, 1, 8, f) != 8 || memcmp(magic, "CHATNNUE", 8) != 0) {
            fprintf(stderr, "NNUE: bad magic in '%s'\n", path.c_str());
            fclose(f); return false;
        }

        // Header fields (6 x uint32, little-endian)
        uint32_t version, feat_size, acc_size, dense_size, hidden_size, out_size;
        fread(&version,     4, 1, f);
        fread(&feat_size,   4, 1, f);
        fread(&acc_size,    4, 1, f);
        fread(&dense_size,  4, 1, f);
        fread(&hidden_size, 4, 1, f);
        fread(&out_size,    4, 1, f);

        if ((int)feat_size   != NNUE_FEAT_SIZE   ||
            (int)acc_size    != NNUE_ACC_SIZE     ||
            (int)hidden_size != NNUE_HIDDEN_SIZE  ||
            (int)out_size    != NNUE_OUT_SIZE) {
            fprintf(stderr,
                "NNUE: architecture mismatch in '%s'\n"
                "  file: feat=%u acc=%u hidden=%u out=%u\n"
                "  code: feat=%d acc=%d hidden=%d out=%d\n",
                path.c_str(),
                feat_size, acc_size, hidden_size, out_size,
                NNUE_FEAT_SIZE, NNUE_ACC_SIZE, NNUE_HIDDEN_SIZE, NNUE_OUT_SIZE);
            fclose(f); return false;
        }

        auto read_floats = [&](std::vector<float>& v, size_t n) {
            v.resize(n);
            fread(v.data(), sizeof(float), n, f);
        };

        int hidden_in = acc_size + dense_size;  // 265
        read_floats(acc_weight, NNUE_FEAT_SIZE * NNUE_ACC_SIZE);
        read_floats(acc_bias,   NNUE_ACC_SIZE);
        read_floats(hid_weight, NNUE_HIDDEN_SIZE * hidden_in);
        read_floats(hid_bias,   NNUE_HIDDEN_SIZE);
        read_floats(out_weight, NNUE_OUT_SIZE * NNUE_HIDDEN_SIZE);
        read_floats(out_bias,   NNUE_OUT_SIZE);

        fclose(f);
        loaded = true;
        return true;
    }

    // Evaluate a board position.
    // output[0..3] = rank probabilities for [self, left, across, right]
    // relative to board.turn (the active player).
    void evaluate(const Board& board, float output[NNUE_OUT_SIZE]) const;

    // Return the rank probability for `for_player` given a board position
    // where it may be some other player's turn.
    float player_value(const Board& board, int for_player) const {
        float probs[NNUE_OUT_SIZE];
        evaluate(board, probs);
        // probs[0] is for board.turn; probs[rel] is for for_player
        return probs[NNUE_RELATION[board.turn][for_player]];
    }
};

// ---------------------------------------------------------------------------
// Feature encoding — mirrors Python features.py exactly
// ---------------------------------------------------------------------------

// Map a 0x88 square + active player to the canonical Python square (row*8+col).
// Python canonical() rotates the board so the active player is always "south".
static inline int nnue_canonical_sq(int sq0x88, int active) {
    int row = sq0x88 >> 4;
    int col = sq0x88 & 0x0F;
    switch (active) {
        case RED:    return row       * 8 + col;        // no rotation
        case BLUE:   return (7 - col) * 8 + row;         // 90 deg CCW
        case YELLOW: return (7 - row) * 8 + (7 - col);  // 180 deg
        case GREEN:  return col       * 8 + (7 - row);  // 90 deg CW
        default:     return row       * 8 + col;
    }
}

// Piece type (PIECE_MASK bits) to Python piece index 0-4.
// PAWN=0x04 -> 0, KNIGHT=0x08 -> 1, BISHOP=0x0C -> 2, ROOK=0x10 -> 3, KING=0x14 -> 4
static inline int nnue_piece_idx(uint8_t ptype) {
    return (ptype >> 2) - 1;
}

// Collect active feature indices and dense vector for a board position.
static void nnue_collect_features(
    const Board& board,
    std::vector<int>& indices,
    float dense[NNUE_DENSE_SIZE])
{
    int active = board.turn;
    indices.clear();

    // --- Alive status (scan for live kings) ---
    bool alive[4] = {false, false, false, false};
    for (int sq = SQ_A8; sq <= SQ_H1; sq++) {
        if (sq & 0x88) { sq += 7; continue; }
        uint8_t p = board.board[sq];
        if (p != EMPTY && (p & PIECE_MASK) == KING && !(p & DEAD))
            alive[p & COLOR_MASK] = true;
    }

    // --- Dense vector: canonically reordered points + alive + ply ---
    // Canonical means: index 0 = active player, 1 = left, 2 = across, 3 = right.
    float canon_pts[4]   = {};
    float canon_alive[4] = {};
    for (int c = 0; c < 4; c++) {
        int ci = NNUE_RELATION[active][c];
        canon_pts[ci]   = board.points[c] / 54.0f;
        canon_alive[ci] = alive[c] ? 1.0f : 0.0f;
    }
    for (int i = 0; i < 4; i++) {
        dense[i]     = canon_pts[i];
        dense[4 + i] = canon_alive[i];
    }
    dense[8] = 0.0f;  // ply unknown at C++ inference time

    // --- Sparse feature indices ---
    for (int sq = SQ_A8; sq <= SQ_H1; sq++) {
        if (sq & 0x88) { sq += 7; continue; }
        uint8_t piece = board.board[sq];
        if (piece == EMPTY) continue;

        int color    = piece & COLOR_MASK;
        int ptype    = piece & PIECE_MASK;
        bool is_dead = (piece & DEAD) != 0;
        int  canon_sq = nnue_canonical_sq(sq, active);

        if (!is_dead) {
            int rel = NNUE_RELATION[active][color];
            int pid = nnue_piece_idx(ptype);
            indices.push_back(NNUE_ALIVE_OFFSET + rel * 5 * 64 + pid * 64 + canon_sq);
        } else {
            // Dead pieces are colour-agnostic — 2 classes only
            int dc = (ptype == KING) ? 1 : 0;
            indices.push_back(NNUE_DEAD_OFFSET + dc * 64 + canon_sq);
        }
    }
}

// ---------------------------------------------------------------------------
// Forward pass
// ---------------------------------------------------------------------------
static inline float nnue_clipped_relu(float x) {
    return x < 0.0f ? 0.0f : (x > 1.0f ? 1.0f : x);
}

// Horizontal sum of a 256-bit AVX register (8 floats)
static inline float hsum_avx(__m256 v) {
    __m128 vlow  = _mm256_castps256_ps128(v);
    __m128 vhigh = _mm256_extractf128_ps(v, 1);
    vlow = _mm_add_ps(vlow, vhigh);
    __m128 shuf = _mm_movehdup_ps(vlow);
    __m128 sums = _mm_add_ps(vlow, shuf);
    shuf = _mm_movehl_ps(shuf, sums);
    sums = _mm_add_ss(sums, shuf);
    return _mm_cvtss_f32(sums);
}

inline void NNUEModel::evaluate(const Board& board, float output[NNUE_OUT_SIZE]) const {
    std::vector<int> indices;
    float dense[NNUE_DENSE_SIZE];
    nnue_collect_features(board, indices, dense);

    // 1. Accumulator = bias + sum of active feature rows
    // acc is 256 floats = 32 blocks of 8
    alignas(32) float acc[NNUE_ACC_SIZE];
    
    // Initialize with bias
    for (int j = 0; j < NNUE_ACC_SIZE / 8; j++) {
        _mm256_store_ps(acc + j * 8, _mm256_loadu_ps(acc_bias.data() + j * 8));
    }

    // Add active feature rows
    for (int fi : indices) {
        const float* row = acc_weight.data() + fi * NNUE_ACC_SIZE;
        for (int j = 0; j < NNUE_ACC_SIZE / 8; j++) {
            __m256 v_acc = _mm256_load_ps(acc + j * 8);
            __m256 v_row = _mm256_loadu_ps(row + j * 8);
            _mm256_store_ps(acc + j * 8, _mm256_add_ps(v_acc, v_row));
        }
    }

    // 2. ClippedReLU
    __m256 v_zero = _mm256_setzero_ps();
    __m256 v_one  = _mm256_set1_ps(1.0f);
    for (int j = 0; j < NNUE_ACC_SIZE / 8; j++) {
        __m256 v_acc = _mm256_load_ps(acc + j * 8);
        v_acc = _mm256_max_ps(v_zero, _mm256_min_ps(v_one, v_acc));
        _mm256_store_ps(acc + j * 8, v_acc);
    }

    // 3. Concatenate [acc(256) | dense(9)] -> x(265)
    alignas(32) float x[272]; // Pad to 272 (multiple of 8) for easier SIMD
    memcpy(x, acc, NNUE_ACC_SIZE * sizeof(float));
    memcpy(x + NNUE_ACC_SIZE, dense, NNUE_DENSE_SIZE * sizeof(float));
    memset(x + NNUE_ACC_SIZE + NNUE_DENSE_SIZE, 0, (272 - 265) * sizeof(float));

    // 4. Hidden layer + ClippedReLU
    float h[NNUE_HIDDEN_SIZE];
    for (int i = 0; i < NNUE_HIDDEN_SIZE; i++) {
        __m256 v_sum = _mm256_setzero_ps();
        const float* row = hid_weight.data() + i * NNUE_HIDDEN_IN;
        
        // Process 264 floats in blocks of 8
        for (int j = 0; j < 33; j++) {
            __m256 v_w = _mm256_loadu_ps(row + j * 8);
            __m256 v_x = _mm256_load_ps(x + j * 8);
            v_sum = _mm256_fmadd_ps(v_w, v_x, v_sum);
        }
        
        // Sum up the register and add the 265th element + bias
        float v = hsum_avx(v_sum) + hid_bias[i];
        v += row[264] * x[264];
        
        h[i] = nnue_clipped_relu(v);
    }

    // 5. Output layer (only 4 neurons, keep scalar for simplicity)
    float logits[NNUE_OUT_SIZE];
    for (int i = 0; i < NNUE_OUT_SIZE; i++) {
        float v = out_bias[i];
        const float* row = out_weight.data() + i * NNUE_HIDDEN_SIZE;
        for (int j = 0; j < NNUE_HIDDEN_SIZE; j++)
            v += row[j] * h[j];
        logits[i] = v;
    }

    // 6. Softmax (numerically stable)
    float max_l = logits[0];
    for (int i = 1; i < NNUE_OUT_SIZE; i++)
        if (logits[i] > max_l) max_l = logits[i];
    float sum = 0.0f;
    for (int i = 0; i < NNUE_OUT_SIZE; i++) {
        output[i] = expf(logits[i] - max_l);
        sum += output[i];
    }
    for (int i = 0; i < NNUE_OUT_SIZE; i++)
        output[i] /= sum;
}
