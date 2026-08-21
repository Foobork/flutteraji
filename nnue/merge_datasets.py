"""
merge_datasets.py
~~~~~~~~~~~~~~~~~
Merge multiple packed binary .bin datasets (e.g. gen3.bin, gen4.bin, gen5.bin, gen6.bin)
into a single consolidated replay buffer dataset for training.
"""

from __future__ import annotations
import argparse
import struct
import sys
from pathlib import Path

# Binary format constants matching parse_selfplay.py
MAGIC        = b'CHT2'
MAX_FEATURES = 40
DENSE_SIZE   = 9
TARGET_SIZE  = 4

HEADER_FMT  = '<4sIHBBI'
HEADER_SIZE = struct.calcsize(HEADER_FMT)   # 16 bytes

RECORD_FMT  = f'<H{MAX_FEATURES}H{DENSE_SIZE}f{TARGET_SIZE}B4f'
RECORD_SIZE = struct.calcsize(RECORD_FMT)   # 138 bytes


def merge_datasets(input_paths: list[Path], output_path: Path) -> int:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    total_records = 0
    valid_inputs: list[tuple[Path, int]] = []
    
    for p in input_paths:
        if not p.exists():
            print(f"Skipping missing file: {p}", file=sys.stderr)
            continue
            
        file_size = p.stat().st_size
        if file_size < HEADER_SIZE:
            print(f"Skipping empty/corrupt file: {p}", file=sys.stderr)
            continue
            
        with open(p, 'rb') as f:
            header = f.read(HEADER_SIZE)
            magic, n_records, max_f, d_size, t_size, rec_size = struct.unpack(HEADER_FMT, header)
            
            if magic != MAGIC:
                print(f"Skipping {p.name} (magic {magic!r} != expected {MAGIC!r})", file=sys.stderr)
                continue
            if rec_size != RECORD_SIZE:
                print(f"Skipping {p.name} (record size {rec_size} != expected {RECORD_SIZE})", file=sys.stderr)
                continue
                
            expected_size = HEADER_SIZE + n_records * RECORD_SIZE
            if file_size != expected_size:
                print(f"Warning: {p.name} file size ({file_size}) != expected ({expected_size})", file=sys.stderr)
                
            print(f"  + {p.name:18}: {n_records:,} records")
            valid_inputs.append((p, n_records))
            total_records += n_records

    if total_records == 0:
        raise ValueError("No valid records found to merge!")

    print(f"\nMerging {len(valid_inputs)} files into {output_path} ({total_records:,} total records)...")
    
    with open(output_path, 'wb') as out_f:
        # Write merged header
        merged_header = struct.pack(
            HEADER_FMT,
            MAGIC,
            total_records,
            MAX_FEATURES,
            DENSE_SIZE,
            TARGET_SIZE,
            RECORD_SIZE,
        )
        out_f.write(merged_header)
        
        # Stream record data from each input file in 1MB chunks
        CHUNK_SIZE = 1024 * 1024  # 1 MB
        written = 0
        
        for p, n_rec in valid_inputs:
            with open(p, 'rb') as in_f:
                in_f.seek(HEADER_SIZE)
                bytes_to_copy = n_rec * RECORD_SIZE
                copied = 0
                while copied < bytes_to_copy:
                    to_read = min(CHUNK_SIZE, bytes_to_copy - copied)
                    chunk = in_f.read(to_read)
                    if not chunk:
                        break
                    out_f.write(chunk)
                    copied += len(chunk)
                written += n_rec

    size_mb = output_path.stat().st_size / (1024 * 1024)
    print(f"Done! Merged {written:,} records into {output_path} ({size_mb:.1f} MB).")
    return written


def main() -> None:
    parser = argparse.ArgumentParser(description="Merge multiple Chaturaji .bin datasets")
    parser.add_argument(
        '--inputs', '-i',
        nargs='+',
        type=Path,
        default=[
            Path('nnue/data/gen3.bin'),
            Path('nnue/data/gen4.bin'),
            Path('nnue/data/gen5.bin'),
            Path('nnue/data/gen6.bin'),
        ],
        help='List of .bin dataset files to merge',
    )
    parser.add_argument(
        '--output', '-o',
        type=Path,
        default=Path('nnue/data/merged_replay.bin'),
        help='Output path for merged .bin file',
    )
    args = parser.parse_args()
    merge_datasets(args.inputs, args.output)


if __name__ == '__main__':
    main()
