"""
parse_selfplay.py
~~~~~~~~~~~~~~~~~
Convert engine/selfplay.txt → a packed binary .bin dataset for training.

Binary format
-------------
Header (16 bytes):
    magic       : 4 bytes  = b'CHT1'
    n_records   : uint32   — total number of positions
    max_features: uint16   — fixed slots per record (padded with 0)
    dense_size  : uint8    — 9
    target_size : uint8    — 4
    record_size : uint32   — bytes per record (2 + max_features*2 + dense*4 + target)

Records (n_records × record_size bytes):
    n_active    : uint16           — actual number of active feature indices
    features    : uint16[40]       — active indices, rest padded with 0
    dense       : float32[9]       — normalised game state features
    target      : uint8[4]         — raw rank points [6/4/2/0 or ties]

Usage
-----
    cd c:\\vscode\\flutteraji
    nnue\\.venv\\Scripts\\python nnue\\parse_selfplay.py
    # writes nnue/data/gen0.bin

    # With options:
    nnue\\.venv\\Scripts\\python nnue\\parse_selfplay.py \\
        --input engine/selfplay.txt \\
        --output nnue/data/gen0.bin \\
        --skip-opening 8          # skip first N plies of each game
"""

from __future__ import annotations

import argparse
import struct
import sys
import os
from pathlib import Path

# Allow running from any working directory
sys.path.insert(0, str(Path(__file__).parent))

import numpy as np
from chaturaji_board import ChaturajiBoard
from features import encode

# ---------------------------------------------------------------------------
# Binary format constants
# ---------------------------------------------------------------------------
MAGIC        = b'CHT1'
MAX_FEATURES = 32          # exact maximum: 4 players × 8 pieces each, pieces only leave the board
DENSE_SIZE   = 9
TARGET_SIZE  = 4

# Struct formats (little-endian)
# Header: magic(4s) n_records(I) max_features(H) dense_size(B) target_size(B) record_size(I)
HEADER_FMT  = '<4sIHBBI'
HEADER_SIZE = struct.calcsize(HEADER_FMT)   # 16 bytes

# Record: n_active(H) features(40H) dense(9f) target(4B)
RECORD_FMT  = f'<H{MAX_FEATURES}H{DENSE_SIZE}f{TARGET_SIZE}B'
RECORD_SIZE = struct.calcsize(RECORD_FMT)   # 2 + 80 + 36 + 4 = 122 bytes


# ---------------------------------------------------------------------------
# Parser
# ---------------------------------------------------------------------------
def parse_selfplay(
    input_path: Path,
    output_path: Path,
    skip_opening: int = 0,
    verbose: bool = True,
) -> int:
    """
    Parse selfplay.txt and write binary dataset.

    Args:
        input_path:    Path to selfplay.txt
        output_path:   Path to output .bin file
        skip_opening:  Skip the first N positions of each game (opening noise).
                       Set to 0 to keep all positions.
        verbose:       Print progress.

    Returns:
        Number of records written.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)

    records: list[bytes] = []
    skipped = 0
    errors  = 0

    prev_turn  = None   # used to detect game boundaries
    game_ply   = 0      # ply counter within the current game

    with open(input_path, encoding='utf-8') as f:
        for lineno, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue

            parts = line.split(' | ')
            if len(parts) != 2:
                print(f"  Warning: line {lineno} unexpected format, skipping", file=sys.stderr)
                errors += 1
                continue

            fen    = parts[0].strip()
            target = list(map(int, parts[1].strip().split()))

            # Detect game boundary: if the new turn is <= prev_turn
            # (e.g. goes from g→r) a new game has started.
            # selfplay.txt has turns r→b→y→g→r→... sequentially within each game.
            turn_char = fen.strip().split()[-1]
            turn_idx  = {'r': 0, 'b': 1, 'y': 2, 'g': 3}.get(turn_char, -1)
            if prev_turn is not None and turn_idx <= prev_turn:
                game_ply = 0   # new game started
            prev_turn = turn_idx

            # Opening skip
            if game_ply < skip_opening:
                game_ply += 1
                skipped  += 1
                continue
            game_ply += 1

            # Encode position
            try:
                board = ChaturajiBoard.from_fen(fen, ply=game_ply)
                indices, dense = encode(board)
            except Exception as e:
                print(f"  Error at line {lineno}: {e}", file=sys.stderr)
                errors += 1
                continue

            # Validate
            if len(indices) > MAX_FEATURES:
                print(
                    f"  Warning: line {lineno} has {len(indices)} features > MAX_FEATURES={MAX_FEATURES}, "
                    f"truncating", file=sys.stderr
                )
                indices = indices[:MAX_FEATURES]

            # Pack record
            n_active = len(indices)
            padded   = indices + [0] * (MAX_FEATURES - n_active)
            record   = struct.pack(RECORD_FMT, n_active, *padded, *dense.tolist(), *target)
            records.append(record)

    if errors:
        print(f"  {errors} lines had errors and were skipped.", file=sys.stderr)

    n_records = len(records)

    # Write binary file
    with open(output_path, 'wb') as f:
        # Header
        header = struct.pack(
            HEADER_FMT,
            MAGIC,
            n_records,
            MAX_FEATURES,
            DENSE_SIZE,
            TARGET_SIZE,
            RECORD_SIZE,
        )
        f.write(header)

        # Records
        for rec in records:
            f.write(rec)

    size_kb = output_path.stat().st_size / 1024
    if verbose:
        print(f"\nWrote {n_records:,} records to {output_path}")
        print(f"Skipped {skipped:,} opening positions (skip_opening={skip_opening})")
        print(f"File size: {size_kb:.1f} KB  ({RECORD_SIZE} bytes/record)")
        if n_records > 0:
            print(f"\nSample record 0:")
            _print_sample(records[0])

    return n_records


def _print_sample(record_bytes: bytes) -> None:
    """Pretty-print a single packed record for verification."""
    unpacked = struct.unpack(RECORD_FMT, record_bytes)
    n_active = unpacked[0]
    features = list(unpacked[1:1 + MAX_FEATURES])[:n_active]
    dense    = list(unpacked[1 + MAX_FEATURES: 1 + MAX_FEATURES + DENSE_SIZE])
    target   = list(unpacked[1 + MAX_FEATURES + DENSE_SIZE:])
    print(f"  n_active : {n_active}")
    print(f"  features : {features[:8]}{'...' if n_active > 8 else ''}")
    print(f"  dense    : pts={[f'{d:.3f}' for d in dense[:4]]}  "
          f"alive={[int(a) for a in dense[4:8]]}  ply={dense[8]:.3f}")
    print(f"  target   : {target}  (ranks r/b/y/g, sum={sum(target)})")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]

    parser = argparse.ArgumentParser(
        description="Convert Chaturaji selfplay.txt to packed binary dataset"
    )
    parser.add_argument(
        '--input', '-i',
        type=Path,
        default=repo_root / 'engine' / 'selfplay.txt',
        help='Path to selfplay.txt (default: engine/selfplay.txt)',
    )
    parser.add_argument(
        '--output', '-o',
        type=Path,
        default=Path(__file__).parent / 'data' / 'gen0.bin',
        help='Path to output .bin file (default: nnue/data/gen0.bin)',
    )
    parser.add_argument(
        '--skip-opening', '-s',
        type=int,
        default=0,
        metavar='N',
        help='Skip first N positions of each game (default: 0)',
    )
    args = parser.parse_args()

    print(f"Input : {args.input}")
    print(f"Output: {args.output}")
    print(f"Skip opening plies: {args.skip_opening}")

    n = parse_selfplay(args.input, args.output, skip_opening=args.skip_opening)
    print(f"\nDone. {n:,} training positions ready.")


if __name__ == '__main__':
    main()
