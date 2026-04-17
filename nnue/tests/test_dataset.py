"""
tests/test_dataset.py
~~~~~~~~~~~~~~~~~~~~~
Tests for the parse_selfplay.py / dataset.py pipeline.

Run with:
    cd c:\\vscode\\flutteraji
    nnue\\.venv\\Scripts\\pytest nnue\\tests\\test_dataset.py -v
"""

import sys, os, struct, tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest
import numpy as np
import torch

from parse_selfplay import (
    parse_selfplay, MAGIC, HEADER_FMT, HEADER_SIZE,
    RECORD_FMT, RECORD_SIZE, MAX_FEATURES, DENSE_SIZE, TARGET_SIZE,
)
from dataset import SelfplayDataset

REPO_ROOT    = Path(__file__).resolve().parents[2]
SELFPLAY_TXT = REPO_ROOT / 'engine' / 'selfplay.txt'
GEN0_BIN     = Path(__file__).resolve().parents[1] / 'data' / 'gen0.bin'


# ---------------------------------------------------------------------------
# Test 1 — Binary format
# ---------------------------------------------------------------------------
class TestBinaryFormat:
    def test_header_size(self):
        assert HEADER_SIZE == 16

    def test_record_size(self):
        # 2 (n_active) + 32*2 (features) + 9*4 (dense) + 4 (target) = 106
        assert RECORD_SIZE == 106

    def test_gen0_bin_exists(self):
        assert GEN0_BIN.exists(), f"gen0.bin not found — run parse_selfplay.py first"

    def test_magic_bytes(self):
        with open(GEN0_BIN, 'rb') as f:
            magic = f.read(4)
        assert magic == MAGIC

    def test_header_record_count_matches_file_size(self):
        stat_size = GEN0_BIN.stat().st_size
        with open(GEN0_BIN, 'rb') as f:
            header = struct.unpack(HEADER_FMT, f.read(HEADER_SIZE))
        n_records   = header[1]
        record_size = header[5]
        expected_size = HEADER_SIZE + n_records * record_size
        assert stat_size == expected_size, (
            f"File size {stat_size} != header-computed {expected_size}"
        )

    def test_max_features_is_exactly_32(self):
        """
        MAX_FEATURES must equal 32 — derived from game rules:
          - 4 players × 8 pieces each = 32 pieces at the start position
          - Pieces are only ever removed (captured), never added
          - Promotions replace a piece in-place (no net gain)
          ∴ 32 is the exact upper bound, tight at the start position
        """
        assert MAX_FEATURES == 32

    def test_no_position_exceeds_max_features(self):
        """
        Empirical proof: scan every position in selfplay.txt and confirm
        none produces more feature indices than MAX_FEATURES.
        This also validates that MAX_FEATURES = 32 is not just theoretical
        but sufficient for all real-game positions.
        """
        from chaturaji_board import ChaturajiBoard
        from features import encode

        max_seen = 0
        max_fen  = ''
        with open(SELFPLAY_TXT) as f:
            for line in f:
                fen = line.split(' | ')[0].strip()
                if not fen:
                    continue
                board = ChaturajiBoard.from_fen(fen)
                indices, _ = encode(board)
                if len(indices) > max_seen:
                    max_seen = len(indices)
                    max_fen  = fen

        assert max_seen <= MAX_FEATURES, (
            f"Position has {max_seen} features > MAX_FEATURES={MAX_FEATURES}:\n{max_fen}"
        )
        # Also assert the bound is tight (start position hits exactly 32)
        assert max_seen == MAX_FEATURES, (
            f"Expected max of exactly {MAX_FEATURES} (start position), got {max_seen}"
        )


# ---------------------------------------------------------------------------
# Test 2 — Round-trip: parse → read back → verify
# ---------------------------------------------------------------------------
class TestRoundTrip:
    def test_parse_writes_correct_count(self, tmp_path):
        out = tmp_path / 'test.bin'
        n = parse_selfplay(SELFPLAY_TXT, out, verbose=False)
        ds = SelfplayDataset(out)
        assert len(ds) == n

    def test_first_position_is_start(self, tmp_path):
        """Position 0 in selfplay.txt is always the start position."""
        out = tmp_path / 'test.bin'
        parse_selfplay(SELFPLAY_TXT, out, verbose=False)
        ds = SelfplayDataset(out)
        indices, dense, target = ds[0]

        # Start position: 32 alive pieces (4 players × 8 pieces), no dead
        assert len(indices) == 32, f"Expected 32 features, got {len(indices)}"

        # All 4 players alive
        assert np.all(dense[4:8] == 1.0), f"All alive flags should be 1 at start: {dense[4:8]}"

        # Points all 0 at start
        assert np.all(dense[:4] == 0.0), f"All points should be 0 at start: {dense[:4]}"

    def test_target_sums_to_one(self, tmp_path):
        out = tmp_path / 'test.bin'
        parse_selfplay(SELFPLAY_TXT, out, verbose=False)
        ds = SelfplayDataset(out)
        for i in range(0, len(ds), len(ds) // 10):   # sample 10 records
            _, _, target = ds[i]
            assert abs(target.sum() - 1.0) < 1e-5, f"Record {i}: target sum = {target.sum()}"

    def test_all_indices_in_feature_range(self, tmp_path):
        from features import FEATURE_SIZE
        out = tmp_path / 'test.bin'
        parse_selfplay(SELFPLAY_TXT, out, verbose=False)
        ds = SelfplayDataset(out)
        errors = []
        for i in range(len(ds)):
            indices, _, _ = ds[i]
            for idx in indices:
                if not (0 <= idx < FEATURE_SIZE):
                    errors.append(f"Record {i}: index {idx} out of [0,{FEATURE_SIZE})")
                    break
        assert not errors, f"{len(errors)} range errors: {errors[:3]}"

    def test_skip_opening_reduces_record_count(self, tmp_path):
        out_full = tmp_path / 'full.bin'
        out_skip = tmp_path / 'skip.bin'
        n_full = parse_selfplay(SELFPLAY_TXT, out_full, skip_opening=0, verbose=False)
        n_skip = parse_selfplay(SELFPLAY_TXT, out_skip, skip_opening=8, verbose=False)
        assert n_skip < n_full, "Skipping opening plies should reduce record count"


# ---------------------------------------------------------------------------
# Test 3 — Dataset and DataLoader
# ---------------------------------------------------------------------------
class TestDataLoader:
    def test_len_matches_header(self):
        ds = SelfplayDataset(GEN0_BIN)
        with open(GEN0_BIN, 'rb') as f:
            header = struct.unpack(HEADER_FMT, f.read(HEADER_SIZE))
        assert len(ds) == header[1]

    def test_getitem_types(self):
        ds = SelfplayDataset(GEN0_BIN)
        indices, dense, target = ds[0]
        assert isinstance(indices, list)
        assert isinstance(dense, np.ndarray) and dense.dtype == np.float32
        assert isinstance(target, np.ndarray) and target.dtype == np.float32

    def test_batch_tensor_shapes(self):
        from torch.utils.data import DataLoader
        ds = SelfplayDataset(GEN0_BIN)
        loader = DataLoader(ds, batch_size=8, shuffle=False,
                            collate_fn=SelfplayDataset.collate)
        feat, off, den, tgt = next(iter(loader))

        assert feat.dtype  == torch.long
        assert off.dtype   == torch.long
        assert den.shape   == (8, DENSE_SIZE)
        assert tgt.shape   == (8, TARGET_SIZE)
        assert den.dtype   == torch.float32
        assert tgt.dtype   == torch.float32

    def test_offsets_monotone_increasing(self):
        """Offsets must be strictly increasing (each sample has ≥1 feature)."""
        from torch.utils.data import DataLoader
        ds = SelfplayDataset(GEN0_BIN)
        loader = DataLoader(ds, batch_size=16, shuffle=False,
                            collate_fn=SelfplayDataset.collate)
        _, off, _, _ = next(iter(loader))
        offsets = off.tolist()
        assert all(offsets[i] < offsets[i+1] for i in range(len(offsets)-1)), (
            f"Offsets not strictly increasing: {offsets}"
        )

    def test_target_rows_sum_to_one(self):
        from torch.utils.data import DataLoader
        ds = SelfplayDataset(GEN0_BIN)
        loader = DataLoader(ds, batch_size=32, shuffle=False,
                            collate_fn=SelfplayDataset.collate)
        _, _, _, tgt = next(iter(loader))
        sums = tgt.sum(dim=1)
        assert torch.allclose(sums, torch.ones(32), atol=1e-5), (
            f"Target rows don't sum to 1: {sums}"
        )

    def test_model_forward_on_batch(self):
        """Full pipeline: dataset → batch → model forward pass."""
        import sys
        sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
        from model import ChaturajiNNUE
        from torch.utils.data import DataLoader

        model = ChaturajiNNUE()
        ds    = SelfplayDataset(GEN0_BIN)
        loader = DataLoader(ds, batch_size=8, shuffle=False,
                            collate_fn=SelfplayDataset.collate)
        feat, off, den, tgt = next(iter(loader))

        out = model(feat, off, den)
        assert out.shape == (8, 4)
        assert torch.allclose(out.sum(dim=1), torch.ones(8), atol=1e-5)
