// nnue.h
// ------
// Chaturaji NNUE inference — C++ equivalent of Python model.py + features.py.

#pragma once
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>
#include <immintrin.h>

// Forward declaration
class Board;

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
static const int NNUE_RELATION[4][4] = {
    {0, 1, 2, 3},   // RED active
    {3, 0, 1, 2},   // BLUE active
    {2, 3, 0, 1},   // YELLOW active
    {1, 2, 3, 0},   // GREEN active
};

// ---------------------------------------------------------------------------
// NNUE Accumulator — stores the first layer output for each perspective
// ---------------------------------------------------------------------------
struct Accumulator {
    alignas(32) float v[4][NNUE_ACC_SIZE];
    bool initialized = false;

    void zero() {
        memset(v, 0, sizeof(v));
        initialized = false;
    }
};

// ---------------------------------------------------------------------------
// NNUEModel — loaded weights + inference
// ---------------------------------------------------------------------------
struct NNUEModel {
    std::vector<float> acc_weight;  // [FEAT_SIZE * NNUE_ACC_SIZE]
    std::vector<float> acc_bias;    // [NNUE_ACC_SIZE]
    std::vector<float> hid_weight;  // [HIDDEN_SIZE * HIDDEN_IN]
    std::vector<float> hid_bias;    // [HIDDEN_SIZE]
    std::vector<float> out_weight;  // [OUT_SIZE * HIDDEN_SIZE]
    std::vector<float> out_bias;    // [OUT_SIZE]

    bool loaded = false;

    bool load(const std::string& path) {
        FILE* f = fopen(path.c_str(), "rb");
        if (!f) return false;

        char magic[9] = {};
        if (fread(magic, 1, 8, f) != 8 || memcmp(magic, "CHATNNUE", 8) != 0) {
            fclose(f); return false;
        }

        uint32_t version, feat_size, acc_size, dense_size, hidden_size, out_size;
        fread(&version,     4, 1, f);
        fread(&feat_size,   4, 1, f);
        fread(&acc_size,    4, 1, f);
        fread(&dense_size,  4, 1, f);
        fread(&hidden_size, 4, 1, f);
        fread(&out_size,    4, 1, f);

        if ((int)feat_size != NNUE_FEAT_SIZE || (int)acc_size != NNUE_ACC_SIZE) {
            fclose(f); return false;
        }

        auto read_floats = [&](std::vector<float>& v, size_t n) {
            v.resize(n);
            fread(v.data(), sizeof(float), n, f);
        };

        read_floats(acc_weight, NNUE_FEAT_SIZE * NNUE_ACC_SIZE);
        read_floats(acc_bias,   NNUE_ACC_SIZE);
        read_floats(hid_weight, NNUE_HIDDEN_SIZE * (acc_size + dense_size));
        read_floats(hid_bias,   NNUE_HIDDEN_SIZE);
        read_floats(out_weight, NNUE_OUT_SIZE * NNUE_HIDDEN_SIZE);
        read_floats(out_bias,   NNUE_OUT_SIZE);

        fclose(f);
        loaded = true;
        return true;
    }

    // Evaluate using the incremental accumulator in the board
    void evaluate(const Board& board, float output[NNUE_OUT_SIZE]) const;

    // Refresh the entire accumulator from scratch
    void refresh_accumulator(const Board& board, Accumulator& acc) const;

    // Incremental update: update a single piece's contribution to all 4 perspectives
    void update_feature(Accumulator& acc, int color, int ptype, int sq0x88, bool is_dead, bool add) const;

    // Return the rank probability for `for_player` given a board position
    float player_value(const Board& board, int for_player) const;
};

// ---------------------------------------------------------------------------
// Helper functions (moved from board.h/cpp logic for NNUE specifics)
// ---------------------------------------------------------------------------

static inline int nnue_canonical_sq(int sq0x88, int active) {
    int r = sq0x88 >> 4;
    int c = sq0x88 & 0x0F;
    int nr, nc;
    switch (active) {
        case 0: nr = r;     nc = c;     break; // RED
        case 1: nr = 7 - c; nc = r;     break; // BLUE
        case 2: nr = 7 - r; nc = 7 - c; break; // YELLOW
        case 3: nr = c;     nc = 7 - r; break; // GREEN
        default: nr = r;    nc = c;     break;
    }
    return nr * 8 + nc;
}

static inline int nnue_piece_idx(uint8_t ptype) {
    // PAWN=0x04 -> 0, KNIGHT=0x08 -> 1, BISHOP=0x0C -> 2, ROOK=0x10 -> 3, KING=0x14 -> 4
    return (ptype >> 2) - 1;
}

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
