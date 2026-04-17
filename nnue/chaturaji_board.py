"""
chaturaji_board.py
~~~~~~~~~~~~~~~~~~
Pure-Python Chaturaji board representation and FEN parser.

Mirrors the bit layout from engine/board.h exactly so that feature indices
produced here will match any future C++ accumulator implementation.

FEN format (from engine/board.cpp):
    <position> <points_r/b/y/g> <turn>
    e.g.: bRbP2yKyByNyR/... 0/0/0/0 r
    Dead pieces are prefixed with '*': *gP = dead green pawn.

0x88 square layout:
    sq = row * 16 + col  (row 0 = rank 8 top, row 7 = rank 1 bottom)
    Valid squares satisfy (sq & 0x88) == 0  → col in [0..7], row in [0..7]
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Optional

# ---------------------------------------------------------------------------
# Constants (match engine/board.h)
# ---------------------------------------------------------------------------
RED    = 0
BLUE   = 1
YELLOW = 2
GREEN  = 3

PAWN   = 0
KNIGHT = 1
BISHOP = 2
ROOK   = 3
KING   = 4

COLOR_NAMES = {RED: 'r', BLUE: 'b', YELLOW: 'y', GREEN: 'g'}
PIECE_NAMES = {PAWN: 'P', KNIGHT: 'N', BISHOP: 'B', ROOK: 'R', KING: 'K'}

_CHAR_TO_COLOR = {v: k for k, v in COLOR_NAMES.items()}
_CHAR_TO_PIECE = {v: k for k, v in PIECE_NAMES.items()}

# After rotating so that `active_player` becomes south (=RED seat):
# The original colors map to new relationship indices [self, left, across, right].
# ROTATION_MAP[active_color] = [new_index_for_RED, new_index_for_BLUE,
#                                new_index_for_YELLOW, new_index_for_GREEN]
#
# Rotation is CCW: Blue→south requires 90° CCW, Yellow→south 180°, Green→south 90° CW.
#
# Relationship after rotation:
#   active_color → relationship 0 (self)
#   active_color+1 (mod 4) → relationship 1 (left)
#   active_color+2 (mod 4) → relationship 2 (across)
#   active_color+3 (mod 4) → relationship 3 (right)
ROTATION_MAP = {
    RED:    [0, 1, 2, 3],  # no rotation
    BLUE:   [3, 0, 1, 2],  # 90° CCW: Red→right, Blue→self, Yellow→left, Green→across
    YELLOW: [2, 3, 0, 1],  # 180°
    GREEN:  [1, 2, 3, 0],  # 90° CW: Red→left, Blue→across, Yellow→right, Green→self
}


# ---------------------------------------------------------------------------
# Piece dataclass
# ---------------------------------------------------------------------------
@dataclass
class Piece:
    color: int       # RED/BLUE/YELLOW/GREEN
    piece_type: int  # PAWN/KNIGHT/BISHOP/ROOK/KING
    is_dead: bool = False

    def __repr__(self) -> str:
        dead = '*' if self.is_dead else ''
        return f"{dead}{COLOR_NAMES[self.color]}{PIECE_NAMES[self.piece_type]}"


# ---------------------------------------------------------------------------
# Board
# ---------------------------------------------------------------------------
class ChaturajiBoard:
    """
    Represents a Chaturaji position.

    board[row][col] is either None (empty) or a Piece.
    row 0 = rank 8 (top), row 7 = rank 1 (bottom) — same as the C++ 0x88 layout.
    """

    def __init__(self) -> None:
        self.board: list[list[Optional[Piece]]] = [
            [None] * 8 for _ in range(8)
        ]
        self.points: list[int] = [0, 0, 0, 0]    # red, blue, yellow, green
        self.alive:  list[bool] = [False] * 4
        self.turn: int = RED
        self.ply: int = 0                         # filled in by dataset parser

    # ------------------------------------------------------------------
    # Factory: parse FEN string
    # ------------------------------------------------------------------
    @classmethod
    def from_fen(cls, fen: str, ply: int = 0) -> "ChaturajiBoard":
        """
        Parse a FEN string as produced by engine/board.cpp::generateFen().

        Format: <position> <points_r/b/y/g> <turn>
        Position rows are separated by '/'; dead pieces are prefixed with '*'.
        """
        parts = fen.strip().split()
        if len(parts) < 3:
            raise ValueError(f"Invalid FEN (need 3 parts): {fen!r}")

        board = cls()
        board.ply = ply

        # --- Parse position ---
        pos_str, points_str, turn_str = parts[0], parts[1], parts[2]

        row, col = 0, 0
        i = 0
        while i < len(pos_str):
            ch = pos_str[i]

            if ch == '/':
                row += 1
                col = 0
                i += 1

            elif ch.isdigit():
                col += int(ch)
                i += 1

            elif ch == '*':
                # Dead piece: *<color><piece>
                color_ch = pos_str[i + 1]
                piece_ch = pos_str[i + 2]
                color = _CHAR_TO_COLOR[color_ch]
                ptype = _CHAR_TO_PIECE[piece_ch]
                board.board[row][col] = Piece(color, ptype, is_dead=True)
                col += 1
                i += 3

            else:
                # Live piece: <color><piece>
                color_ch = ch
                piece_ch = pos_str[i + 1]
                color = _CHAR_TO_COLOR[color_ch]
                ptype = _CHAR_TO_PIECE[piece_ch]
                piece = Piece(color, ptype, is_dead=False)
                board.board[row][col] = piece
                if ptype == KING:
                    board.alive[color] = True
                col += 1
                i += 2

        # --- Parse points ---
        for idx, tok in enumerate(points_str.split('/')):
            board.points[idx] = int(tok)

        # --- Parse turn ---
        board.turn = _CHAR_TO_COLOR[turn_str[0]]

        return board

    # ------------------------------------------------------------------
    # Relation helper
    # ------------------------------------------------------------------
    def relation(self, color: int) -> int:
        """
        Return the relationship index [0=self, 1=left, 2=across, 3=right]
        of `color` relative to `self.turn` in the *canonical* frame.

        Call this on the board returned by canonical(), where self.turn == RED,
        and the rotation has already been applied to piece positions.
        """
        return ROTATION_MAP[self.turn][color]

    # ------------------------------------------------------------------
    # Canonical rotation
    # ------------------------------------------------------------------
    def canonical(self) -> "ChaturajiBoard":
        """
        Return a new board rotated so that the active player (self.turn)
        is in the Red/south seat (relationship 0).

        If self.turn == RED, returns self unchanged.

        Rotation rules (board coordinates: row 0 = top, col 0 = left):
            0° (RED already south):  (r, c) → (r, c)
            90° CCW (BLUE → south):  (r, c) → (c, 7-r)
            180°    (YELLOW → south): (r, c) → (7-r, 7-c)
            90° CW  (GREEN → south): (r, c) → (7-c, r)
        """
        if self.turn == RED:
            return self

        nb = ChaturajiBoard()
        nb.ply = self.ply
        nb.turn = RED   # after rotation, the active player is always in the Red seat

        # Rotate piece positions
        for row in range(8):
            for col in range(8):
                piece = self.board[row][col]
                if piece is None:
                    continue
                nr, nc = _rotate(row, col, self.turn)
                nb.board[nr][nc] = piece   # piece.color unchanged; relation() handles it

        # Rotate points and alive arrays so index 0 = the original active player
        rmap = ROTATION_MAP[self.turn]   # rmap[original_color] = canonical_index
        for orig_color in range(4):
            ci = rmap[orig_color]
            nb.points[ci] = self.points[orig_color]
            nb.alive[ci]  = self.alive[orig_color]

        # The canonical board's ROTATION_MAP[RED] = [0,1,2,3], so relation() works
        # correctly on canonical boards: pieces with color RED→rel 0, BLUE→rel 1, etc.
        # But the canonical board's pieces still carry their *original* color integers.
        # We need relation() to map them correctly, where:
        #   original active player → rel 0 (self)
        #   etc.
        # Since we've already shifted points/alive arrays, we also need to remap piece
        # colors so that the original active player's pieces now have color RED.
        _remap = _build_color_remap(self.turn)
        for row in range(8):
            for col in range(8):
                p = nb.board[row][col]
                if p is not None:
                    nb.board[row][col] = Piece(_remap[p.color], p.piece_type, p.is_dead)

        return nb

    # ------------------------------------------------------------------
    # Debug helpers
    # ------------------------------------------------------------------
    def __repr__(self) -> str:
        rows = []
        for row in range(8):
            cells = []
            for col in range(8):
                p = self.board[row][col]
                cells.append(str(p) if p else '..')
            rows.append(' '.join(cells))
        pts = '/'.join(str(p) for p in self.points)
        turn = COLOR_NAMES[self.turn]
        return '\n'.join(rows) + f'\nPoints: {pts}  Turn: {turn}'


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
def _rotate(row: int, col: int, active: int) -> tuple[int, int]:
    """Rotate (row, col) so that `active` player's king-side becomes south."""
    if active == BLUE:
        # 90° CCW: south side becomes Blue's starting edge
        return col, 7 - row
    elif active == YELLOW:
        # 180°
        return 7 - row, 7 - col
    elif active == GREEN:
        # 90° CW
        return 7 - col, row
    return row, col   # RED: no rotation


def _build_color_remap(active: int) -> list[int]:
    """
    Return a list where remap[original_color] = canonical_color, such that
    the active player's pieces become RED (0), left opponent becomes BLUE (1), etc.
    """
    # ROTATION_MAP[active][original_color] = relationship index = canonical color
    return ROTATION_MAP[active]
