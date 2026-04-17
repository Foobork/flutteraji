"""
export.py
~~~~~~~~~
Export a trained ChaturajiNNUE checkpoint to a flat binary .nnue file
that the C++ engine can load and run inference on.

Binary format
-------------
Header (32 bytes):
    magic       : char[8]   = "CHATNNUE"
    version     : uint32    = 1
    feat_size   : uint32    = 1408
    acc_size    : uint32    = 256
    dense_size  : uint32    = 9
    hidden_size : uint32    = 32
    output_size : uint32    = 4

Weights (float32, little-endian, row-major):
    acc_weight  : float32[feat_size * acc_size]         (1408 × 256)
    acc_bias    : float32[acc_size]                     (256,)
    hid_weight  : float32[hidden_size * hidden_in]      (32 × 265)  hidden_in = acc+dense
    hid_bias    : float32[hidden_size]                  (32,)
    out_weight  : float32[output_size * hidden_size]    (4 × 32)
    out_bias    : float32[output_size]                  (4,)

Total: ~1.41 MB

Usage
-----
    cd c:\\vscode\\flutteraji
    nnue\\.venv\\Scripts\\python nnue\\export.py
    # writes nnue/checkpoints/gen0.nnue
"""

from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import torch
import numpy as np
from model   import ChaturajiNNUE
from features import FEATURE_SIZE, DENSE_SIZE

MAGIC   = b'CHATNNUE'
VERSION = 1


def export(checkpoint_path: Path, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Load weights
    model = ChaturajiNNUE()
    state = torch.load(checkpoint_path, map_location='cpu', weights_only=True)
    model.load_state_dict(state)
    model.eval()

    ACC_SIZE    = model.ACCUMULATOR_SIZE               # 256
    HIDDEN_SIZE = model.HIDDEN_SIZE                    # 32
    HIDDEN_IN   = ACC_SIZE + DENSE_SIZE                # 265
    OUT_SIZE    = model.OUTPUT_SIZE                    # 4

    # Verify shapes match expectations
    acc_w = model.accumulator.weight.detach().numpy()  # (1408, 256)
    acc_b = model.acc_bias.detach().numpy()            # (256,)
    hid_w = model.hidden.weight.detach().numpy()       # (32, 265)
    hid_b = model.hidden.bias.detach().numpy()         # (32,)
    out_w = model.value_head.weight.detach().numpy()   # (4, 32)
    out_b = model.value_head.bias.detach().numpy()     # (4,)

    assert acc_w.shape == (FEATURE_SIZE, ACC_SIZE),    f"acc_weight shape {acc_w.shape}"
    assert acc_b.shape == (ACC_SIZE,),                 f"acc_bias shape {acc_b.shape}"
    assert hid_w.shape == (HIDDEN_SIZE, HIDDEN_IN),    f"hid_weight shape {hid_w.shape}"
    assert hid_b.shape == (HIDDEN_SIZE,),              f"hid_bias shape {hid_b.shape}"
    assert out_w.shape == (OUT_SIZE, HIDDEN_SIZE),     f"out_weight shape {out_w.shape}"
    assert out_b.shape == (OUT_SIZE,),                 f"out_bias shape {out_b.shape}"

    with open(output_path, 'wb') as f:
        # Header
        f.write(MAGIC)
        f.write(struct.pack('<IIIIII',
            VERSION,
            FEATURE_SIZE,   # 1408
            ACC_SIZE,       # 256
            DENSE_SIZE,     # 9
            HIDDEN_SIZE,    # 32
            OUT_SIZE,       # 4
        ))

        # Weights (all float32, little-endian)
        f.write(acc_w.astype('<f4').tobytes())
        f.write(acc_b.astype('<f4').tobytes())
        f.write(hid_w.astype('<f4').tobytes())
        f.write(hid_b.astype('<f4').tobytes())
        f.write(out_w.astype('<f4').tobytes())
        f.write(out_b.astype('<f4').tobytes())

    size_kb = output_path.stat().st_size / 1024
    print(f"Exported:    {output_path}")
    print(f"File size:   {size_kb:.1f} KB")
    print(f"Architecture: feat={FEATURE_SIZE} acc={ACC_SIZE} "
          f"hidden_in={HIDDEN_IN} hidden={HIDDEN_SIZE} out={OUT_SIZE}")
    print(f"Weights:     acc({FEATURE_SIZE}x{ACC_SIZE}) + bias({ACC_SIZE}) "
          f"+ hid({HIDDEN_SIZE}x{HIDDEN_IN}) + bias({HIDDEN_SIZE}) "
          f"+ out({OUT_SIZE}x{HIDDEN_SIZE}) + bias({OUT_SIZE})")


def main() -> None:
    parser = argparse.ArgumentParser(description="Export NNUE checkpoint to C++ binary")
    parser.add_argument('--checkpoint', '-c', type=Path,
                        default=Path('nnue/checkpoints/gen0.pt'))
    parser.add_argument('--output', '-o', type=Path,
                        default=Path('nnue/checkpoints/gen0.nnue'))
    args = parser.parse_args()

    print(f"Loading: {args.checkpoint}")
    export(args.checkpoint, args.output)


if __name__ == '__main__':
    main()
