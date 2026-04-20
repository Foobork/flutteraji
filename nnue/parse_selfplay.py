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
    target      : uint8[4]         — rank points in CANONICAL order [self, left, across, right]

Usage
-----
    cd c:\\vscode\\flutteraji
    nnue\\.venv\\Scripts\\python nnue\\parse_selfplay.py
    # writes nnue/data/gen0.bin

    # With options:
    nnue\\.venv\\Scripts\\python nnue\\parse_selfplay.py \\
        --input engine/selfplay_gen1.txt \\
        --output nnue/data/gen1.bin \\
        --skip-opening 8
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
from chaturaji_board import ChaturajiBoard, ROTATION_MAP
from features import encode

# ---------------------------------------------------------------------------
# Binary format constants
# ---------------------------------------------------------------------------
MAGIC        = b'CHT1'
MAX_FEATURES = 40          # exact maximum is lower, but 40 is safe padding
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

            fen_full = parts[0].strip()
            target_str = parts[1].strip()

            # New FEN format: <pieces> <points> <turn_char> <ply>
            # Example: ... 0/0/0/0 r 0
            fen_parts = fen_full.split()
            if len(fen_parts) < 4:
                 print(f"  Warning: line {lineno} FEN incomplete, skipping", file=sys.stderr)
                 errors += 1
                 continue
            
            try:
                game_ply = int(fen_parts[3])
            except ValueError:
                 print(f"  Warning: line {lineno} ply not an int, skipping", file=sys.stderr)
                 errors += 1
                 continue

            # Opening skip
            if game_ply < skip_opening:
                skipped += 1
                continue

            # Encode position
            try:
                board = ChaturajiBoard.from_fen(fen_full)
                indices, dense = encode(board)
            except Exception as e:
                print(f"  Error at line {lineno}: {e}", file=sys.stderr)
                errors += 1
                continue

            # Validate
            if len(indices) > MAX_FEATURES:
                if verbose:
                    print(
                        f"  Warning: line {lineno} has {len(indices)} features > MAX_FEATURES={MAX_FEATURES}, "
                        f"truncating", file=sys.stderr
                    )
                indices = indices[:MAX_FEATURES]

            # Canonicalize target: raw [r,b,y,g] → [self, left, across, right]
            try:
                target_ints = list(map(int, target_str.split()))
                if len(target_ints) != 4:
                    raise ValueError(f"Expected 4 target points, got {len(target_ints)}")
            except ValueError as e:
                print(f"  Error parsing target at line {lineno}: {e}", file=sys.stderr)
                errors += 1
                continue

            rmap = ROTATION_MAP[board.turn]
            canon_target = [0] * 4
            for orig_color, rank_pts in enumerate(target_ints):
                canon_target[rmap[orig_color]] = rank_pts

            # Pack record
            n_active = len(indices)
            padded   = indices + [0] * (MAX_FEATURES - n_active)
            record   = struct.pack(RECORD_FMT, n_active, *padded, *dense.tolist(), *canon_target)
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
    print(f"  target   : {target}  (canonical [self/left/across/right], sum={sum(target)})")


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
