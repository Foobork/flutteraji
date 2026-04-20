#include "nnue.h"
#include "board.h"
#include <immintrin.h>

void NNUEModel::refresh_accumulator(const Board& board, Accumulator& acc) const {
    // Initialize with bias for all 4 perspectives
    for (int p = 0; p < 4; p++) {
        for (int j = 0; j < NNUE_ACC_SIZE / 8; j++) {
            _mm256_store_ps(acc.v[p] + j * 8, _mm256_loadu_ps(acc_bias.data() + j * 8));
        }
    }

    // Add all pieces on the board
    for (int sq = SQ_A8; sq <= SQ_H1; sq++) {
        if (sq & 0x88) { sq += 7; continue; }
        uint8_t piece = board.board[sq];
        if (piece == EMPTY) continue;

        update_feature(acc, piece & COLOR_MASK, piece & PIECE_MASK, sq, (piece & DEAD) != 0, true);
    }
    acc.initialized = true;
}

void NNUEModel::update_feature(Accumulator& acc, int color, int ptype, int sq0x88, bool is_dead, bool add) const {
    for (int active = 0; active < 4; active++) {
        int canon_sq = nnue_canonical_sq(sq0x88, active);
        int fi;
        if (!is_dead) {
            int rel = NNUE_RELATION[active][color];
            int pid = nnue_piece_idx(ptype);
            fi = NNUE_ALIVE_OFFSET + rel * 5 * 64 + pid * 64 + canon_sq;
        } else {
            int dc = (ptype == KING) ? 1 : 0;
            fi = NNUE_DEAD_OFFSET + dc * 64 + canon_sq;
        }

        const float* row = acc_weight.data() + fi * NNUE_ACC_SIZE;
        float* v = acc.v[active];

        if (add) {
            for (int j = 0; j < NNUE_ACC_SIZE / 8; j++) {
                __m256 v_acc = _mm256_load_ps(v + j * 8);
                __m256 v_row = _mm256_loadu_ps(row + j * 8);
                _mm256_store_ps(v + j * 8, _mm256_add_ps(v_acc, v_row));
            }
        } else {
            for (int j = 0; j < NNUE_ACC_SIZE / 8; j++) {
                __m256 v_acc = _mm256_load_ps(v + j * 8);
                __m256 v_row = _mm256_loadu_ps(row + j * 8);
                _mm256_store_ps(v + j * 8, _mm256_sub_ps(v_acc, v_row));
            }
        }
    }
}

void NNUEModel::evaluate(const Board& board, float output[NNUE_OUT_SIZE]) const {
    if (!board.nnue_acc.initialized) {
        // Fallback or just-in-time refresh if not initialized
        refresh_accumulator(board, const_cast<Board&>(board).nnue_acc);
    }

    const float* acc = board.nnue_acc.v[board.turn];

    // 1. ClippedReLU on the accumulator (local copy to avoid mutating the board's acc)
    alignas(32) float x[272];
    __m256 v_zero = _mm256_setzero_ps();
    __m256 v_one  = _mm256_set1_ps(1.0f);
    for (int j = 0; j < NNUE_ACC_SIZE / 8; j++) {
        __m256 v_acc = _mm256_load_ps(acc + j * 8);
        v_acc = _mm256_max_ps(v_zero, _mm256_min_ps(v_one, v_acc));
        _mm256_store_ps(x + j * 8, v_acc);
    }

    // 2. Dense vector: points, alive, ply
    bool alive[4] = {false, false, false, false};
    for (int sq = SQ_A8; sq <= SQ_H1; sq++) {
        if (sq & 0x88) { sq += 7; continue; }
        uint8_t p = board.board[sq];
        if (p != EMPTY && (p & PIECE_MASK) == KING && !(p & DEAD))
            alive[p & COLOR_MASK] = true;
    }

    float canon_pts[4]   = {};
    float canon_alive[4] = {};
    for (int c = 0; c < 4; c++) {
        int ci = NNUE_RELATION[board.turn][c];
        canon_pts[ci]   = board.points[c] / 54.0f;
        canon_alive[ci] = alive[c] ? 1.0f : 0.0f;
    }
    for (int i = 0; i < 4; i++) {
        x[NNUE_ACC_SIZE + i]     = canon_pts[i];
        x[NNUE_ACC_SIZE + 4 + i] = canon_alive[i];
    }
    x[NNUE_ACC_SIZE + 8] = (float)board.ply / 512.0f;
    memset(x + NNUE_ACC_SIZE + 9, 0, (272 - 265) * sizeof(float));

    // 3. Hidden layer + ClippedReLU
    float h[NNUE_HIDDEN_SIZE];
    for (int i = 0; i < NNUE_HIDDEN_SIZE; i++) {
        __m256 v_sum = _mm256_setzero_ps();
        const float* row = hid_weight.data() + i * NNUE_HIDDEN_IN;
        for (int j = 0; j < 33; j++) {
            __m256 v_w = _mm256_loadu_ps(row + j * 8);
            __m256 v_x = _mm256_load_ps(x + j * 8);
            v_sum = _mm256_fmadd_ps(v_w, v_x, v_sum);
        }
        float v = hsum_avx(v_sum) + hid_bias[i];
        v += row[264] * x[264];
        h[i] = v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v);
    }

    // 4. Output layer + Softmax
    float logits[NNUE_OUT_SIZE];
    for (int i = 0; i < NNUE_OUT_SIZE; i++) {
        float v = out_bias[i];
        const float* row = out_weight.data() + i * NNUE_HIDDEN_SIZE;
        for (int j = 0; j < NNUE_HIDDEN_SIZE; j++)
            v += row[j] * h[j];
        logits[i] = v;
    }

    float max_l = logits[0];
    for (int i = 1; i < NNUE_OUT_SIZE; i++) if (logits[i] > max_l) max_l = logits[i];
    float sum = 0.0f;
    for (int i = 0; i < NNUE_OUT_SIZE; i++) {
        output[i] = expf(logits[i] - max_l);
        sum += output[i];
    }
    for (int i = 0; i < NNUE_OUT_SIZE; i++) output[i] /= sum;
}

float NNUEModel::player_value(const Board& board, int for_player) const {
    float probs[NNUE_OUT_SIZE];
    evaluate(board, probs);
    // probs[0] is for board.turn; probs[rel] is for for_player
    return probs[NNUE_RELATION[board.turn][for_player]];
}
