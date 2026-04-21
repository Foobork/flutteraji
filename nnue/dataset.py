"""
dataset.py
~~~~~~~~~~
PyTorch Dataset and DataLoader for the packed Chaturaji binary dataset
produced by parse_selfplay.py.

Usage
-----
    from dataset import SelfplayDataset
    from torch.utils.data import DataLoader

    ds     = SelfplayDataset('nnue/data/gen0.bin')
    loader = DataLoader(ds, batch_size=256, shuffle=True,
                        collate_fn=SelfplayDataset.collate)

    for feature_indices, offsets, dense, target in loader:
        output = model(feature_indices, offsets, dense)
        loss   = criterion(output, target)
        ...

Batch tensors
-------------
    feature_indices : LongTensor (total_active_features,)
        Concatenated active feature indices for all positions in the batch.
    offsets         : LongTensor (batch_size,)
        Start position of each sample's features in feature_indices.
        Compatible with nn.EmbeddingBag.
    dense           : FloatTensor (batch_size, 9)
        Normalised game-state features.
    target          : FloatTensor (batch_size, 4)
        Rank probability targets (normalised so each row sums to 1).
        Derived from raw rank points [6/4/2/0] by dividing by their sum (=12).
"""

from __future__ import annotations

import struct
import mmap
from pathlib import Path
from typing import Optional

import numpy as np
import torch
from torch.utils.data import Dataset, DataLoader

# Import binary format constants from parse_selfplay
import sys
sys.path.insert(0, str(Path(__file__).parent))
from parse_selfplay import (
    MAGIC, HEADER_FMT, HEADER_SIZE,
    RECORD_FMT, RECORD_SIZE,
    MAX_FEATURES, DENSE_SIZE, TARGET_SIZE,
)

# ---------------------------------------------------------------------------
# Dataset
# ---------------------------------------------------------------------------
class SelfplayDataset(Dataset):
    """
    Memory-mapped binary dataset of Chaturaji self-play positions.

    Each item is a tuple:
        (indices: list[int], dense: np.ndarray[9], target: np.ndarray[4])

    Use the static collate() method as the DataLoader's collate_fn.
    """

    def __init__(self, bin_path: str | Path, q_weight: float = 0.0) -> None:
        """
        Args:
            bin_path: Path to .bin file
            q_weight: How much to weight MCTS Q-values vs Game Result (0.0 to 1.0).
                      Target = (1 - q_weight) * result + q_weight * Q
        """
        self.path = Path(bin_path)
        self.q_weight = q_weight
        
        if not self.path.exists():
            raise FileNotFoundError(f"Dataset not found: {self.path}")

        with open(self.path, 'rb') as f:
            header_bytes = f.read(HEADER_SIZE)

        magic, n_records, max_features, dense_size, target_size, record_size = \
            struct.unpack(HEADER_FMT, header_bytes)

        if magic != MAGIC:
            raise ValueError(f"Bad magic bytes: {magic!r}, expected {MAGIC!r}")
        if record_size != RECORD_SIZE:
            raise ValueError(
                f"Record size mismatch: file has {record_size}, "
                f"code expects {RECORD_SIZE}"
            )

        self.n_records   = n_records
        self.max_features = max_features
        self._file = open(self.path, 'rb')
        self._mmap = mmap.mmap(self._file.fileno(), 0, access=mmap.ACCESS_READ)

    def __len__(self) -> int:
        return self.n_records

    def __getitem__(self, idx: int) -> tuple[list[int], np.ndarray, np.ndarray]:
        if idx < 0 or idx >= self.n_records:
            raise IndexError(f"Index {idx} out of range [0, {self.n_records})")

        offset = HEADER_SIZE + idx * RECORD_SIZE
        record_bytes = self._mmap[offset: offset + RECORD_SIZE]
        unpacked = struct.unpack(RECORD_FMT, record_bytes)

        n_active = unpacked[0]
        features = list(unpacked[1: 1 + MAX_FEATURES])[:n_active]
        dense    = np.array(unpacked[1 + MAX_FEATURES: 1 + MAX_FEATURES + DENSE_SIZE],
                            dtype=np.float32)

        # Result target (canonical rank points [6/4/2/0])
        raw_res = np.array(unpacked[1 + MAX_FEATURES + DENSE_SIZE: 1 + MAX_FEATURES + DENSE_SIZE + TARGET_SIZE],
                           dtype=np.float32)
        res_target = raw_res / 12.0

        # Q target (MCTS evaluations)
        raw_q = np.array(unpacked[1 + MAX_FEATURES + DENSE_SIZE + TARGET_SIZE:],
                         dtype=np.float32)
        q_target = raw_q / 12.0

        # Blend targets
        target = (1.0 - self.q_weight) * res_target + self.q_weight * q_target

        return features, dense, target

    def __del__(self) -> None:
        try:
            if hasattr(self, '_mmap') and self._mmap:
                self._mmap.close()
            if hasattr(self, '_file') and self._file:
                self._file.close()
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Collate function for DataLoader
    # ------------------------------------------------------------------
    @staticmethod
    def collate(
        batch: list[tuple[list[int], np.ndarray, np.ndarray]],
    ) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor, torch.Tensor]:
        """
        Collate a batch of (indices, dense, target) tuples into tensors
        compatible with ChaturajiNNUE.forward().

        Returns:
            feature_indices : LongTensor  (total_features,)
            offsets         : LongTensor  (batch_size,)
            dense           : FloatTensor (batch_size, 9)
            target          : FloatTensor (batch_size, 4)
        """
        all_indices: list[int] = []
        offsets:     list[int] = []
        dense_rows:  list[np.ndarray] = []
        target_rows: list[np.ndarray] = []

        for indices, dense, target in batch:
            offsets.append(len(all_indices))
            all_indices.extend(indices)
            dense_rows.append(dense)
            target_rows.append(target)

        return (
            torch.tensor(all_indices, dtype=torch.long),
            torch.tensor(offsets, dtype=torch.long),
            torch.tensor(np.stack(dense_rows), dtype=torch.float32),
            torch.tensor(np.stack(target_rows), dtype=torch.float32),
        )

    # ------------------------------------------------------------------
    # Convenience: build a DataLoader
    # ------------------------------------------------------------------
    @classmethod
    def make_loader(
        cls,
        bin_path: str | Path,
        batch_size: int = 256,
        shuffle: bool = True,
        num_workers: int = 0,
    ) -> DataLoader:
        ds = cls(bin_path)
        return DataLoader(
            ds,
            batch_size=batch_size,
            shuffle=shuffle,
            collate_fn=cls.collate,
            num_workers=num_workers,
        )

    # ------------------------------------------------------------------
    # Dataset statistics
    # ------------------------------------------------------------------
    def stats(self) -> dict:
        """Compute summary statistics over the entire dataset."""
        rank_counts: dict[tuple, int] = {}
        total_features = 0
        alive_counts   = np.zeros(4)

        for i in range(self.n_records):
            indices, dense, target = self[i]
            total_features += len(indices)
            alive_counts   += dense[4:8]
            key = tuple((target * 12).astype(int).tolist())
            rank_counts[key] = rank_counts.get(key, 0) + 1

        return {
            'n_records':          self.n_records,
            'avg_features':       total_features / self.n_records,
            'avg_alive_players':  float(alive_counts.sum() / self.n_records),
            'top_rank_outcomes':  sorted(rank_counts.items(), key=lambda x: -x[1])[:5],
        }


# ---------------------------------------------------------------------------
# Quick smoke-test when run directly
# ---------------------------------------------------------------------------
if __name__ == '__main__':
    import sys
    bin_path = Path(__file__).parent / 'data' / 'gen0.bin'
    if len(sys.argv) > 1:
        bin_path = Path(sys.argv[1])

    print(f"Loading dataset: {bin_path}")
    ds = SelfplayDataset(bin_path)
    print(f"Records: {len(ds):,}")

    # Sample first item
    idx0, dense0, target0 = ds[0]
    print(f"\nItem 0:")
    print(f"  n_active features : {len(idx0)}")
    print(f"  dense             : {dense0}")
    print(f"  target (probs)    : {target0}  sum={target0.sum():.4f}")

    # One batch via DataLoader
    loader = SelfplayDataset.make_loader(bin_path, batch_size=4, shuffle=False)
    feat, off, den, tgt = next(iter(loader))
    print(f"\nBatch of 4:")
    print(f"  feature_indices shape : {feat.shape}")
    print(f"  offsets               : {off.tolist()}")
    print(f"  dense shape           : {den.shape}")
    print(f"  target shape          : {tgt.shape}")
    print(f"  target row sums       : {tgt.sum(dim=1).tolist()}")

    # Stats
    print("\nDataset statistics:")
    s = ds.stats()
    for k, v in s.items():
        print(f"  {k}: {v}")
