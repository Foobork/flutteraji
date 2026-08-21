import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

import numpy as np
from dataset import SelfplayDataset

for name in ['gen3.bin', 'gen4.bin', 'gen5.bin', 'gen6.bin', 'merged_replay.bin']:
    p = Path('nnue/data') / name
    if not p.exists():
        continue
    ds = SelfplayDataset(p, q_weight=0.0)
    targets = []
    n = min(50000, len(ds))
    np.random.seed(42)
    indices = np.random.choice(len(ds), n, replace=False)
    for idx in indices:
        _, _, tgt = ds[idx]
        targets.append(tgt)
    mean_tgt = np.mean(targets, axis=0)
    print(f"{name:18}: Mean Target [self, left, across, right] = {[f'{x:.4f}' for x in mean_tgt]} (pts: {[f'{x*12:.2f}' for x in mean_tgt]})")
