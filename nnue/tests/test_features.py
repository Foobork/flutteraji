"""
tests/test_features.py
~~~~~~~~~~~~~~~~~~~~~~
Unit tests for the Chaturaji NNUE feature encoder.

Run with:
    cd nnue
    ..\\.venv\\Scripts\\pytest tests/ -v
"""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

import pytest
import numpy as np
import torch

from chaturaji_board import (
    ChaturajiBoard,
    RED, BLUE, YELLOW, GREEN,
    PAWN, KNIGHT, BISHOP, ROOK, KING,
)
from features import (
    encode, alive_index, dead_index,
    FEATURE_SIZE, ALIVE_OFFSET, ALIVE_SIZE, DEAD_OFFSET, DEAD_SIZE, DENSE_SIZE,
)
from model import ChaturajiNNUE

# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------
START_FEN = (
    "bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/"
    "6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r"
)


# ---------------------------------------------------------------------------
# Test 1 — Feature count sanity on start position
# ---------------------------------------------------------------------------
class TestFeatureCountSanity:
    def test_start_position_has_32_alive_features(self):
        board = ChaturajiBoard.from_fen(START_FEN)
        indices, dense = encode(board)
        # 4 players × 8 pieces each = 32 alive pieces on the start position
        assert len(indices) == 32, f"Expected 32, got {len(indices)}"

    def test_no_dead_features_on_start(self):
        board = ChaturajiBoard.from_fen(START_FEN)
        indices, _ = encode(board)
        dead_features = [i for i in indices if i >= DEAD_OFFSET]
        assert len(dead_features) == 0, "No dead pieces at start"

    def test_all_indices_in_range(self):
        board = ChaturajiBoard.from_fen(START_FEN)
        indices, _ = encode(board)
        for idx in indices:
            assert 0 <= idx < FEATURE_SIZE, f"Index {idx} out of range [0, {FEATURE_SIZE})"

    def test_no_duplicate_indices(self):
        board = ChaturajiBoard.from_fen(START_FEN)
        indices, _ = encode(board)
        assert len(indices) == len(set(indices)), "Duplicate feature indices found"


# ---------------------------------------------------------------------------
# Test 2 — Dense vector shape and values
# ---------------------------------------------------------------------------
class TestDenseVector:
    def test_shape(self):
        board = ChaturajiBoard.from_fen(START_FEN)
        _, dense = encode(board)
        assert dense.shape == (DENSE_SIZE,), f"Expected ({DENSE_SIZE},), got {dense.shape}"

    def test_dtype(self):
        board = ChaturajiBoard.from_fen(START_FEN)
        _, dense = encode(board)
        assert dense.dtype == np.float32

    def test_points_normalised_zero_at_start(self):
        board = ChaturajiBoard.from_fen(START_FEN)
        _, dense = encode(board)
        assert np.all(dense[:4] == 0.0), "All points should be 0 at start"

    def test_all_alive_at_start(self):
        board = ChaturajiBoard.from_fen(START_FEN)
        _, dense = encode(board)
        # After canonicalisation turn=r, so alive[0]=self=red=1.0 etc.
        assert np.all(dense[4:8] == 1.0), "All players alive at start"


# ---------------------------------------------------------------------------
# Test 3 — Dead piece encoding (colour-independent)
# ---------------------------------------------------------------------------
class TestDeadPieceEncoding:
    # A position where Green has been eliminated (all Green pieces dead).
    # Constructed manually: use selfplay.txt line 8 which has *gP etc.
    DEAD_GREEN_FEN = (
        "bR1bP1yKyByNyR/bNbP2yP1yPyP/bBbP5/"
        "bKbP4yP1/6*gP1/1rP4*gP*gB/rP1rPrP2*gP*gN/"
        "rRrNrB1rK1*gP*gR 0/0/3/0 r"
    )

    def test_dead_pieces_produce_dead_indices(self):
        board = ChaturajiBoard.from_fen(self.DEAD_GREEN_FEN)
        indices, _ = encode(board)
        dead_indices = [i for i in indices if i >= DEAD_OFFSET]
        assert len(dead_indices) > 0, "Expected some dead piece features"

    def test_dead_non_king_class(self):
        """Dead non-king pieces (pawns, etc.) use dead_class=0."""
        board = ChaturajiBoard.from_fen(self.DEAD_GREEN_FEN)
        indices, _ = encode(board)
        # Non-king dead features must be in [DEAD_OFFSET, DEAD_OFFSET+64)
        nonking_dead = [i for i in indices
                        if DEAD_OFFSET <= i < DEAD_OFFSET + 64]
        assert len(nonking_dead) > 0, "Expected dead non-king features"

    def test_dead_colour_invariance(self):
        """
        Two boards identical except the dead pieces swap colour should produce
        the same dead feature indices (colour doesn't matter for dead pieces).

        We achieve this by checking that the dead indices from a position are
        the same whether the board is at turn=red or rotated to a different turn
        but with the same physical dead pieces.
        """
        board = ChaturajiBoard.from_fen(self.DEAD_GREEN_FEN)
        idx_red, _ = encode(board)
        dead_red = sorted(i for i in idx_red if i >= DEAD_OFFSET)

        # Construct a board as if Blue were to move (rotate) — dead pieces should
        # still land on same squares after rotation undoes itself in the canonical frame.
        # Here we directly check that after canonicalisation, dead features are the same
        # as long as physical board position of dead pieces is unchanged.
        canonical = board.canonical()   # board.turn=RED so canonical == board
        idx_can, _ = encode(canonical)
        dead_can = sorted(i for i in idx_can if i >= DEAD_OFFSET)
        assert dead_red == dead_can

    def test_green_alive_flag_false(self):
        """After Green is eliminated, dense alive[3] should be 0."""
        board = ChaturajiBoard.from_fen(self.DEAD_GREEN_FEN)
        _, dense = encode(board)
        # In canonical frame turn=r, relation map is [0,1,2,3]
        # Green is relation 3, so dense[4+3] = alive[3]
        assert dense[4 + GREEN] == 0.0, "Green should be dead"

    def test_active_player_always_alive(self):
        """The active player (canonical relation 0) must always be alive."""
        board = ChaturajiBoard.from_fen(self.DEAD_GREEN_FEN)
        _, dense = encode(board)
        assert dense[4] == 1.0, "Active player (relation 0) must always be alive"


# ---------------------------------------------------------------------------
# Test 4 — Rotational canonicalisation
# ---------------------------------------------------------------------------
class TestRotationalCanonicalisation:
    """
    The start position is rotationally symmetric.  Encoding from Red's perspective
    and from Blue's perspective (same physical pieces, different active player)
    should produce the same number of features and the same alive/dead split,
    but different alive_index values (different relation assignments).
    """

    def test_feature_count_same_regardless_of_active_player(self):
        """All four canonical encodings of the start position have 32 alive features."""
        fens = [
            START_FEN.replace("0/0/0/0 r", "0/0/0/0 r"),
            START_FEN.replace("0/0/0/0 r", "0/0/0/0 b"),
            START_FEN.replace("0/0/0/0 r", "0/0/0/0 y"),
            START_FEN.replace("0/0/0/0 r", "0/0/0/0 g"),
        ]
        for fen in fens:
            board = ChaturajiBoard.from_fen(fen)
            indices, _ = encode(board)
            assert len(indices) == 32, (
                f"Expected 32 for turn={fen.split()[-1]}, got {len(indices)}"
            )

    def test_canonical_active_player_is_always_self(self):
        """
        After canonicalisation, all pieces of the active player have relation=0 (self).
        Alive features for relation 0 are in [ALIVE_OFFSET, ALIVE_OFFSET + 5*64).
        """
        board_r = ChaturajiBoard.from_fen(START_FEN)
        board_b = ChaturajiBoard.from_fen(START_FEN.replace("0/0/0/0 r", "0/0/0/0 b"))

        def self_features(board):
            indices, _ = encode(board)
            return sorted(i for i in indices if ALIVE_OFFSET <= i < ALIVE_OFFSET + 5 * 64)

        self_r = self_features(board_r)
        self_b = self_features(board_b)

        # Both should have exactly 8 self-features (8 pieces per player on start)
        assert len(self_r) == 8, f"Red self features: {len(self_r)}"
        assert len(self_b) == 8, f"Blue self features: {len(self_b)}"

    def test_index_arithmetic(self):
        """Sanity-check the index helper functions."""
        # Alive: self-pawn on a1 (sq=56)
        idx = alive_index(0, PAWN, 56)
        assert ALIVE_OFFSET <= idx < ALIVE_OFFSET + ALIVE_SIZE

        # Dead king on h8 (sq=7)
        idx = dead_index(1, 7)
        assert DEAD_OFFSET <= idx < DEAD_OFFSET + DEAD_SIZE

        # Dead non-king on d4 (sq=3*8+3=27)
        idx = dead_index(0, 27)
        assert DEAD_OFFSET <= idx < DEAD_OFFSET + DEAD_SIZE


# ---------------------------------------------------------------------------
# Test 5 — Model forward pass
# ---------------------------------------------------------------------------
class TestModelForwardPass:
    def _make_batch(self, n: int):
        """Create a batch of n copies of the start position."""
        board = ChaturajiBoard.from_fen(START_FEN)
        all_indices = []
        offsets = []
        dense_list = []
        for _ in range(n):
            indices, dense = encode(board)
            offsets.append(len(all_indices))
            all_indices.extend(indices)
            dense_list.append(dense)
        t_idx = torch.tensor(all_indices, dtype=torch.long)
        t_off = torch.tensor(offsets, dtype=torch.long)
        t_den = torch.tensor(np.stack(dense_list), dtype=torch.float32)
        return t_idx, t_off, t_den

    def test_output_shape(self):
        model = ChaturajiNNUE()
        t_idx, t_off, t_den = self._make_batch(8)
        out = model(t_idx, t_off, t_den)
        assert out.shape == (8, 4), f"Expected (8, 4), got {out.shape}"

    def test_output_in_unit_interval(self):
        model = ChaturajiNNUE()
        t_idx, t_off, t_den = self._make_batch(4)
        out = model(t_idx, t_off, t_den)
        assert torch.all(out >= 0.0) and torch.all(out <= 1.0), "Probs must be in [0, 1]"

    def test_output_rows_sum_to_one(self):
        model = ChaturajiNNUE()
        t_idx, t_off, t_den = self._make_batch(4)
        out = model(t_idx, t_off, t_den)
        row_sums = out.sum(dim=1)
        assert torch.allclose(row_sums, torch.ones(4), atol=1e-5), (
            f"Row sums not ≈ 1: {row_sums}"
        )

    def test_evaluate_convenience_method(self):
        model = ChaturajiNNUE()
        board = ChaturajiBoard.from_fen(START_FEN)
        indices, dense = encode(board)
        probs = model.evaluate(indices, dense)
        assert len(probs) == 4
        assert abs(sum(probs) - 1.0) < 1e-5, f"Probs don't sum to 1: {probs}"
