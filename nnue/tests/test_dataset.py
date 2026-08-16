"""
tests/test_dataset.py
~~~~~~~~~~~~~~~~~~~~~
Tests for the parse_selfplay.py / dataset.py pipeline.

Run with:
    cd nnue
    ..\\.venv\\Scripts\\pytest tests/test_dataset.py -v
"""

import sys, os, struct
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

SAMPLE_SELFPLAY = """bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 0 | 6 4 2 0 | 5.0 4.0 2.0 1.0
bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 1 | 6 4 2 0 | 5.0 4.0 2.0 1.0
bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 2 | 6 4 2 0 | 5.0 4.0 2.0 1.0
bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 3 | 6 4 2 0 | 5.0 4.0 2.0 1.0
bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 4 | 6 4 2 0 | 5.0 4.0 2.0 1.0
bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 5 | 6 4 2 0 | 5.0 4.0 2.0 1.0
bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 6 | 6 4 2 0 | 5.0 4.0 2.0 1.0
bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 7 | 6 4 2 0 | 5.0 4.0 2.0 1.0
bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 8 | 6 4 2 0 | 5.0 4.0 2.0 1.0
bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 9 | 6 4 2 0 | 5.0 4.0 2.0 1.0
bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 10 | 6 4 2 0 | 5.0 4.0 2.0 1.0
bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 11 | 6 4 2 0 | 5.0 4.0 2.0 1.0
bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 12 | 6 4 2 0 | 5.0 4.0 2.0 1.0
bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 13 | 6 4 2 0 | 5.0 4.0 2.0 1.0
bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 14 | 6 4 2 0 | 5.0 4.0 2.0 1.0
bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 15 | 6 4 2 0 | 5.0 4.0 2.0 1.0
"""


@pytest.fixture
def sample_selfplay_file(tmp_path):
    fpath = tmp_path / "sample_selfplay.txt"
    fpath.write_text(SAMPLE_SELFPLAY.strip(), encoding="utf-8")
    return fpath


@pytest.fixture
def sample_bin_file(sample_selfplay_file, tmp_path):
    bin_path = tmp_path / "sample.bin"
    parse_selfplay(sample_selfplay_file, bin_path, skip_opening=0, verbose=False)
    return bin_path


# ---------------------------------------------------------------------------
# Test 1 — Binary format
# ---------------------------------------------------------------------------
class TestBinaryFormat:
    def test_header_size(self):
        assert HEADER_SIZE == 16

    def test_record_size(self):
        # 2 (n_active) + 40*2 (features) + 9*4 (dense) + 4*4 (q_values) + 4 (target) = 138
        assert RECORD_SIZE == 138
        assert RECORD_SIZE == struct.calcsize(RECORD_FMT)

    def test_magic_bytes(self, sample_bin_file):
        with open(sample_bin_file, 'rb') as f:
            magic = f.read(4)
        assert magic == MAGIC

    def test_header_record_count_matches_file_size(self, sample_bin_file):
        stat_size = sample_bin_file.stat().st_size
        with open(sample_bin_file, 'rb') as f:
            header = struct.unpack(HEADER_FMT, f.read(HEADER_SIZE))
        n_records   = header[1]
        record_size = header[5]
        expected_size = HEADER_SIZE + n_records * record_size
        assert stat_size == expected_size, (
            f"File size {stat_size} != header-computed {expected_size}"
        )

    def test_max_features(self):
        assert MAX_FEATURES == 40


# ---------------------------------------------------------------------------
# Test 2 — Round-trip: parse → read back → verify
# ---------------------------------------------------------------------------
class TestRoundTrip:
    def test_parse_writes_correct_count(self, sample_selfplay_file, tmp_path):
        out = tmp_path / 'test.bin'
        n = parse_selfplay(sample_selfplay_file, out, skip_opening=0, verbose=False)
        ds = SelfplayDataset(out)
        assert len(ds) == n

    def test_first_position_is_start(self, sample_bin_file):
        ds = SelfplayDataset(sample_bin_file)
        indices, dense, target = ds[0]

        # Start position: 32 alive pieces (4 players × 8 pieces), no dead
        assert len(indices) == 32, f"Expected 32 features, got {len(indices)}"

        # All 4 players alive
        assert np.all(dense[4:8] == 1.0), f"All alive flags should be 1 at start: {dense[4:8]}"

        # Points all 0 at start
        assert np.all(dense[:4] == 0.0), f"All points should be 0 at start: {dense[:4]}"

    def test_target_sums_to_one(self, sample_bin_file):
        ds = SelfplayDataset(sample_bin_file)
        for i in range(len(ds)):
            _, _, target = ds[i]
            assert abs(target.sum() - 1.0) < 1e-5, f"Record {i}: target sum = {target.sum()}"

    def test_all_indices_in_feature_range(self, sample_bin_file):
        from features import FEATURE_SIZE
        ds = SelfplayDataset(sample_bin_file)
        errors = []
        for i in range(len(ds)):
            indices, _, _ = ds[i]
            for idx in indices:
                if not (0 <= idx < FEATURE_SIZE):
                    errors.append(f"Record {i}: index {idx} out of [0,{FEATURE_SIZE})")
                    break
        assert not errors, f"{len(errors)} range errors: {errors[:3]}"

    def test_skip_opening_reduces_record_count(self, sample_selfplay_file, tmp_path):
        out_full = tmp_path / 'full.bin'
        out_skip = tmp_path / 'skip.bin'
        n_full = parse_selfplay(sample_selfplay_file, out_full, skip_opening=0, verbose=False)
        n_skip = parse_selfplay(sample_selfplay_file, out_skip, skip_opening=8, verbose=False)
        assert n_skip < n_full, "Skipping opening plies should reduce record count"


# ---------------------------------------------------------------------------
# Test 3 — Dataset and DataLoader
# ---------------------------------------------------------------------------
class TestDataLoader:
    def test_len_matches_header(self, sample_bin_file):
        ds = SelfplayDataset(sample_bin_file)
        with open(sample_bin_file, 'rb') as f:
            header = struct.unpack(HEADER_FMT, f.read(HEADER_SIZE))
        assert len(ds) == header[1]

    def test_getitem_types(self, sample_bin_file):
        ds = SelfplayDataset(sample_bin_file)
        indices, dense, target = ds[0]
        assert isinstance(indices, list)
        assert isinstance(dense, np.ndarray) and dense.dtype == np.float32
        assert isinstance(target, np.ndarray) and target.dtype == np.float32

    def test_batch_tensor_shapes(self, sample_bin_file):
        from torch.utils.data import DataLoader
        ds = SelfplayDataset(sample_bin_file)
        loader = DataLoader(ds, batch_size=8, shuffle=False,
                            collate_fn=SelfplayDataset.collate)
        feat, off, den, tgt = next(iter(loader))

        assert feat.dtype  == torch.long
        assert off.dtype   == torch.long
        assert den.shape   == (8, DENSE_SIZE)
        assert tgt.shape   == (8, TARGET_SIZE)
        assert den.dtype   == torch.float32
        assert tgt.dtype   == torch.float32

    def test_offsets_monotone_increasing(self, sample_bin_file):
        """Offsets must be strictly increasing (each sample has ≥1 feature)."""
        from torch.utils.data import DataLoader
        ds = SelfplayDataset(sample_bin_file)
        loader = DataLoader(ds, batch_size=16, shuffle=False,
                            collate_fn=SelfplayDataset.collate)
        _, off, _, _ = next(iter(loader))
        offsets = off.tolist()
        assert all(offsets[i] < offsets[i+1] for i in range(len(offsets)-1)), (
            f"Offsets not strictly increasing: {offsets}"
        )

    def test_target_rows_sum_to_one(self, sample_bin_file):
        from torch.utils.data import DataLoader
        ds = SelfplayDataset(sample_bin_file)
        loader = DataLoader(ds, batch_size=8, shuffle=False,
                            collate_fn=SelfplayDataset.collate)
        _, _, _, tgt = next(iter(loader))
        sums = tgt.sum(dim=1)
        assert torch.allclose(sums, torch.ones(8), atol=1e-5), (
            f"Target rows don't sum to 1: {sums}"
        )

    def test_model_forward_on_batch(self, sample_bin_file):
        """Full pipeline: dataset → batch → model forward pass."""
        from model import ChaturajiNNUE
        from torch.utils.data import DataLoader

        model = ChaturajiNNUE()
        ds    = SelfplayDataset(sample_bin_file)
        loader = DataLoader(ds, batch_size=8, shuffle=False,
                            collate_fn=SelfplayDataset.collate)
        feat, off, den, tgt = next(iter(loader))

        out = model(feat, off, den)
        assert out.shape == (8, 4)
        assert torch.allclose(out.sum(dim=1), torch.ones(8), atol=1e-5)
