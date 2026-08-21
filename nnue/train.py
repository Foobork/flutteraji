"""
train.py
~~~~~~~~
Train the ChaturajiNNUE value network on self-play data.

Usage
-----
    cd c:\\vscode\\flutteraji
    nnue\\.venv\\Scripts\\python nnue\\train.py

    # With options:
    nnue\\.venv\\Scripts\\python nnue\\train.py \\
        --data   nnue/data/gen0.bin \\
        --out    nnue/checkpoints/gen0.pt \\
        --epochs 20 \\
        --batch  256 \\
        --lr     1e-3 \\
        --val-split 0.1

Training loop
-------------
  Loss   : cross_entropy(predicted_rank_probs, target_rank_probs)
  Opt    : Adam with cosine-annealing LR schedule
  Device : CPU (AMD GPU, no CUDA/ROCm configured)

Output
------
  nnue/checkpoints/gen0.pt   — best model weights by validation loss
  Training progress printed each epoch.
"""

from __future__ import annotations

import argparse
import math
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader, random_split

from dataset import SelfplayDataset
from model import ChaturajiNNUE


# ---------------------------------------------------------------------------
# Loss
# ---------------------------------------------------------------------------
def value_loss(logits: torch.Tensor, target: torch.Tensor) -> torch.Tensor:
    """
    Numerically stable cross-entropy / KL-divergence loss.
    Computes -(target * log_softmax(logits)).sum(dim=1).mean().
    """
    log_probs = F.log_softmax(logits, dim=-1)
    return -(target * log_probs).sum(dim=-1).mean()


# ---------------------------------------------------------------------------
# Training
# ---------------------------------------------------------------------------
def train(
    data_path:  Path,
    out_path:   Path,
    epochs:     int   = 25,
    batch_size: int   = 1024,
    lr:         float = 1e-3,
    val_split:  float = 0.05,
    q_weight:   float = 0.10,
    threads:    int   = 4,
    seed:       int   = 42,
) -> None:
    torch.manual_seed(seed)
    torch.set_num_threads(threads)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    # --- Dataset split ---
    full_ds = SelfplayDataset(data_path, q_weight=q_weight)
    n_val   = max(1, int(len(full_ds) * val_split))
    n_train = len(full_ds) - n_val
    train_ds, val_ds = random_split(
        full_ds, [n_train, n_val],
        generator=torch.Generator().manual_seed(seed),
    )

    train_loader = DataLoader(
        train_ds, batch_size=batch_size, shuffle=True,
        collate_fn=SelfplayDataset.collate,
        num_workers=0,
    )
    val_loader = DataLoader(
        val_ds, batch_size=batch_size, shuffle=False,
        collate_fn=SelfplayDataset.collate,
        num_workers=0,
    )

    print(f"Dataset : {len(full_ds):,} positions  "
          f"(train {n_train:,} / val {n_val:,})")
    print(f"Epochs  : {epochs}   Batch: {batch_size}   LR: {lr}   Q-Weight: {q_weight}   Threads: {threads}")
    print(f"Output  : {out_path}\n")

    # --- Model ---
    model = ChaturajiNNUE()

    # EmbeddingBag produces sparse gradients → needs SparseAdam.
    # All other parameters use regular Adam.
    sparse_params = [model.accumulator.weight]
    dense_params  = [p for name, p in model.named_parameters()
                     if name != 'accumulator.weight']

    optimizer = torch.optim.SparseAdam(sparse_params, lr=lr)
    optimizer_dense = torch.optim.Adam(
        dense_params, lr=lr, weight_decay=1e-4
    )
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer_dense, T_max=epochs, eta_min=1e-5)

    n_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"Model params: {n_params:,}\n")

    # --- Training loop ---
    best_val_loss = float('inf')
    header = f"{'Epoch':>5}  {'Train Loss':>10}  {'Val Loss':>10}  {'LR':>9}  {'Time':>6}"
    print(header)
    print('-' * len(header))

    for epoch in range(1, epochs + 1):
        t0 = time.time()

        # Cosine LR decay on SparseAdam optimizer as well
        cur_lr = lr * (0.5 * (1.0 + math.cos(math.pi * (epoch - 1) / max(1, epochs))))
        cur_lr = max(cur_lr, 1e-5)
        for pg in optimizer.param_groups:
            pg['lr'] = cur_lr

        # Train
        model.train()
        train_loss_sum = 0.0
        train_batches  = 0
        for feat, off, den, tgt in train_loader:
            optimizer.zero_grad()
            optimizer_dense.zero_grad()
            logits = model(feat, off, den, return_logits=True)
            loss = value_loss(logits, tgt)
            loss.backward()
            optimizer.step()
            optimizer_dense.step()
            train_loss_sum += loss.item()
            train_batches  += 1

        # Validate
        model.eval()
        val_loss_sum = 0.0
        val_batches  = 0
        with torch.no_grad():
            for feat, off, den, tgt in val_loader:
                logits = model(feat, off, den, return_logits=True)
                loss = value_loss(logits, tgt)
                val_loss_sum += loss.item()
                val_batches  += 1

        scheduler.step()

        avg_train = train_loss_sum / max(train_batches, 1)
        avg_val   = val_loss_sum   / max(val_batches, 1)
        elapsed   = time.time() - t0

        improved = ''
        if avg_val < best_val_loss:
            best_val_loss = avg_val
            torch.save(model.state_dict(), out_path)
            improved = ' *'

        print(f"{epoch:>5}  {avg_train:>10.4f}  {avg_val:>10.4f}  "
              f"{cur_lr:>9.2e}  {elapsed:>5.1f}s{improved}")

    print(f"\nBest val loss: {best_val_loss:.4f}")
    print(f"Saved to: {out_path}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(description="Train ChaturajiNNUE")
    parser.add_argument('--data',      type=Path,  default=Path('nnue/data/merged_replay.bin'))
    parser.add_argument('--out',       type=Path,  default=Path('nnue/checkpoints/gen7.pt'))
    parser.add_argument('--epochs',    type=int,   default=25)
    parser.add_argument('--batch',     type=int,   default=1024)
    parser.add_argument('--lr',        type=float, default=1e-3)
    parser.add_argument('--val-split', type=float, default=0.05)
    parser.add_argument('--q-weight',  type=float, default=0.10, help='Weight for MCTS Q-values (0.0=Result, 1.0=Q)')
    parser.add_argument('--threads',   type=int,   default=4)
    parser.add_argument('--seed',      type=int,   default=42)
    args = parser.parse_args()

    train(
        data_path  = args.data,
        out_path   = args.out,
        epochs     = args.epochs,
        batch_size = args.batch,
        lr         = args.lr,
        val_split  = args.val_split,
        q_weight   = args.q_weight,
        threads    = args.threads,
        seed       = args.seed,
    )


if __name__ == '__main__':
    main()
