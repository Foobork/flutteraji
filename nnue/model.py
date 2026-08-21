"""
model.py
~~~~~~~~
ChaturajiNNUE — a value network for 4-player Chaturaji MCTS.

Architecture:
    Sparse accumulator (EmbeddingBag, 1,408 → 256) + ClippedReLU
    Dense bypass          (9 floats: points + alive + ply)
    Concatenate           [256 + 9 = 265]
    Hidden layer          (265 → 32) + ClippedReLU
    Value head            (32 → 4) + softmax

Output: probability distribution over rank outcomes [self, left, across, right]
        (trained against the 6/4/2/0 rank-point target, normalised to sum=1).

Note on EmbeddingBag vs a plain Linear layer:
    During training, EmbeddingBag(mode='sum') is mathematically equivalent to
    a one-hot sparse matrix × weight matrix.  It is far more memory-efficient
    for sparse inputs (~16-32 active out of 1,408).  During C++ inference the
    same matrix is used incrementally (add/subtract columns on make/unmake).
"""

from __future__ import annotations
import torch
import torch.nn as nn
from features import FEATURE_SIZE, DENSE_SIZE


class ChaturajiNNUE(nn.Module):
    """
    NNUE value network for Chaturaji.

    Forward signature:
        feature_indices : LongTensor (total_active_features,)
            Concatenated active feature indices for all positions in the batch.
        offsets         : LongTensor (batch_size,)
            Start position of each sample's features in `feature_indices`.
        dense           : FloatTensor (batch_size, DENSE_SIZE)
            9 dense features per position.

    Returns:
        FloatTensor (batch_size, 4)  — rank probabilities, summing to 1 per row.
    """

    ACCUMULATOR_SIZE = 256
    HIDDEN_SIZE      = 32
    OUTPUT_SIZE      = 4   # one value per player (in canonical [self,left,across,right] order)

    def __init__(self) -> None:
        super().__init__()

        # Sparse accumulator layer.
        # Each of the 1,408 feature slots has a 256-dim weight vector.
        # Active features are summed → dense 256-dim accumulator.
        self.accumulator = nn.EmbeddingBag(
            num_embeddings=FEATURE_SIZE,
            embedding_dim=self.ACCUMULATOR_SIZE,
            mode='sum',
            sparse=True,
        )
        # Explicit bias (EmbeddingBag doesn't have one built in)
        self.acc_bias = nn.Parameter(torch.zeros(self.ACCUMULATOR_SIZE))

        # Hidden layer: concatenated [accumulator(256) + dense(9)] → 32
        self.hidden = nn.Linear(
            self.ACCUMULATOR_SIZE + DENSE_SIZE,
            self.HIDDEN_SIZE,
        )

        # Value head: 32 → 4
        self.value_head = nn.Linear(self.HIDDEN_SIZE, self.OUTPUT_SIZE)

        # Weight initialisation: small uniform for accumulator, default for linear layers
        nn.init.uniform_(self.accumulator.weight, -0.01, 0.01)

    # ------------------------------------------------------------------
    # Forward
    # ------------------------------------------------------------------
    def forward(
        self,
        feature_indices: torch.Tensor,  # (total_features,) LongTensor
        offsets: torch.Tensor,           # (batch_size,)    LongTensor
        dense: torch.Tensor,             # (batch_size, 9)  FloatTensor
        return_logits: bool = False,
    ) -> torch.Tensor:                   # (batch_size, 4)  FloatTensor

        # 1. Accumulator: sparse sum → (batch_size, 256)
        acc = self.accumulator(feature_indices, offsets) + self.acc_bias

        # 2. ClippedReLU — keeps activations in [0, 1] for quantisation compatibility
        acc = torch.clamp(acc, 0.0, 1.0)

        # 3. Concatenate with dense bypass: (batch_size, 265)
        x = torch.cat([acc, dense], dim=1)

        # 4. Hidden layer + ClippedReLU
        x = torch.clamp(self.hidden(x), 0.0, 1.0)

        # 5. Value head
        logits = self.value_head(x)
        if return_logits:
            return logits
        return torch.softmax(logits, dim=1)

    # ------------------------------------------------------------------
    # Convenience: single-position inference (no batching)
    # ------------------------------------------------------------------
    @torch.no_grad()
    def evaluate(
        self,
        feature_indices: list[int],
        dense_np,
    ) -> list[float]:
        """
        Evaluate a single position. Returns 4 rank probabilities.

        Args:
            feature_indices: list of active feature indices (from features.encode())
            dense_np:        numpy array of shape (9,) from features.encode()
        """
        import numpy as np
        t_idx = torch.tensor(feature_indices, dtype=torch.long)
        t_off = torch.zeros(1, dtype=torch.long)
        t_den = torch.tensor(dense_np, dtype=torch.float32).unsqueeze(0)
        probs = self(t_idx, t_off, t_den)
        return probs.squeeze(0).tolist()
