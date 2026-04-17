"""
features.py
~~~~~~~~~~~
Converts a ChaturajiBoard into sparse feature indices and a dense vector
for the ChaturajiNNUE accumulator.

Feature layout (total 1,408):
    Alive pieces [0..1279]:   4 relationships × 5 piece types × 64 squares
    Dead pieces  [1280..1407]: 2 classes (non-king=0, king=1) × 64 squares
                               Colour is IGNORED — dead pieces are grey.

Always call encode() on the canonical board (active player = south = RED).
The canonical() method on ChaturajiBoard handles the rotation.
"""

from __future__ import annotations
import numpy as np
from chaturaji_board import ChaturajiBoard, KING

# ---------------------------------------------------------------------------
# Feature space constants
# ---------------------------------------------------------------------------
NUM_PIECE_TYPES = 5   # pawn, knight, bishop, rook, king
NUM_RELATIONS   = 4   # self, left, across, right
NUM_SQUARES     = 64

# Alive features: 4 × 5 × 64 = 1,280
ALIVE_SIZE   = NUM_RELATIONS * NUM_PIECE_TYPES * NUM_SQUARES   # 1,280
ALIVE_OFFSET = 0

# Dead features: 2 × 64 = 128  (no colour/relationship — grey pieces)
DEAD_SIZE    = 2 * NUM_SQUARES   # 128
DEAD_OFFSET  = ALIVE_SIZE        # 1,280

FEATURE_SIZE = ALIVE_SIZE + DEAD_SIZE  # 1,408

# Dense vector size
DENSE_SIZE = 9   # points[4] + alive[4] + ply_norm[1]

# Normalisation constants
MAX_POINTS = 54.0   # approximate upper bound on earned points
MAX_PLY    = 512.0  # safety cap from selfplay.h


# ---------------------------------------------------------------------------
# Index helpers (also useful for the C++ accumulator implementation)
# ---------------------------------------------------------------------------
def alive_index(relation: int, piece_type: int, square: int) -> int:
    """
    Encode a live piece as a feature index.

    Args:
        relation:   0=self, 1=left, 2=across, 3=right
        piece_type: 0=pawn, 1=knight, 2=bishop, 3=rook, 4=king
        square:     0..63 (row*8 + col in the canonical board frame)
    """
    assert 0 <= relation < 4,         f"relation out of range: {relation}"
    assert 0 <= piece_type < 5,       f"piece_type out of range: {piece_type}"
    assert 0 <= square < 64,          f"square out of range: {square}"
    return ALIVE_OFFSET + relation * NUM_PIECE_TYPES * NUM_SQUARES + piece_type * NUM_SQUARES + square


def dead_index(dead_class: int, square: int) -> int:
    """
    Encode a dead piece as a feature index.

    Args:
        dead_class: 0=non-king (0 pts when dead), 1=king (3 pts to last survivor)
        square:     0..63 (position on the canonical board — rotation irrelevant for dead)
    """
    assert dead_class in (0, 1),  f"dead_class must be 0 or 1, got {dead_class}"
    assert 0 <= square < 64,      f"square out of range: {square}"
    return DEAD_OFFSET + dead_class * NUM_SQUARES + square


# ---------------------------------------------------------------------------
# Main encoder
# ---------------------------------------------------------------------------
def encode(board: ChaturajiBoard) -> tuple[list[int], np.ndarray]:
    """
    Encode a board position into NNUE inputs.

    The board should already be in canonical form (active player = RED seat).
    If not, call board.canonical() first.

    Returns:
        indices: list of active feature indices (typically ~16-32 entries)
        dense:   np.ndarray of shape (9,) with dtype float32
    """
    # Work on the canonical frame
    b = board if board.turn == 0 else board.canonical()

    indices: list[int] = []

    for row in range(8):
        for col in range(8):
            piece = b.board[row][col]
            if piece is None:
                continue

            sq = row * 8 + col

            if not piece.is_dead:
                # Alive piece: colour determines relationship
                rel = b.relation(piece.color)  # 0=self, 1=left, 2=across, 3=right
                indices.append(alive_index(rel, piece.piece_type, sq))
            else:
                # Dead piece: colour is irrelevant — just 2 classes
                dead_class = 1 if piece.piece_type == KING else 0
                indices.append(dead_index(dead_class, sq))

    # Build dense vector
    dense = np.zeros(DENSE_SIZE, dtype=np.float32)
    for i in range(4):
        dense[i]     = b.points[i] / MAX_POINTS    # normalised earned points
        dense[4 + i] = 1.0 if b.alive[i] else 0.0 # alive/dead status
    dense[8] = b.ply / MAX_PLY                      # game length normalised

    return indices, dense
