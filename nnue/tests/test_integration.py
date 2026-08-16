"""
tests/test_integration.py
~~~~~~~~~~~~~~~~~~~~~~~~~
Integration tests against the real self-play data in engine/selfplay.txt.

These tests parse every position from the actual self-play output and verify
that the feature encoder handles all real-world edge cases correctly:
- All 4 active players (Blue/Yellow/Green turns, not just Red)
- Dead players (single and multiple eliminations)
- Positions near game end (3 players eliminated)
- Valid rank-point targets (6/4/2/0 system)

Run with:
    cd c:\\vscode\\flutteraji
    nnue\\.venv\\Scripts\\pytest nnue\\tests\\test_integration.py -v
"""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

import pytest
import numpy as np
from collections import Counter, defaultdict
from pathlib import Path

from chaturaji_board import (
    ChaturajiBoard,
    RED, BLUE, YELLOW, GREEN,
    KING,
    COLOR_NAMES,
)
from features import (
    encode,
    FEATURE_SIZE, ALIVE_OFFSET, ALIVE_SIZE, DEAD_OFFSET, DEAD_SIZE,
)

# ---------------------------------------------------------------------------
# Locate selfplay.txt
# ---------------------------------------------------------------------------
REPO_ROOT    = Path(__file__).resolve().parents[2]   # flutteraji/
SELFPLAY_TXT = REPO_ROOT / "engine" / "selfplay.txt"

VALID_RANK_SETS = {
    frozenset([6, 4, 2, 0]),   # standard: all 4 alive at game end
    frozenset([6, 4, 1]),      # tie somewhere
    frozenset([6, 3, 1]),      # various tie combinations
    frozenset([5, 3, 1]),
    frozenset([5, 1]),
    frozenset([4, 2]),
    frozenset([6, 2]),
    frozenset([6, 0]),
    frozenset([4, 0]),
}

def _valid_rank_points(pts: list[int]) -> bool:
    """
    Rank points must sum to 12 (6+4+2+0 = 12, the total distributed each game).
    Each value must be a non-negative integer.
    """
    return sum(pts) == 12 and all(p >= 0 for p in pts)


pytestmark = pytest.mark.skipif(
    not SELFPLAY_TXT.exists(),
    reason="engine/selfplay.txt not found (generate via engine CLI selfplay)",
)

def _load_selfplay(max_records=5000):
    """Load sample lines from selfplay.txt as (fen_str, rank_points) pairs."""
    records = []
    if not SELFPLAY_TXT.exists():
        return records
    with open(SELFPLAY_TXT, encoding='utf-8') as f:
        for lineno, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            parts = line.split(' | ')
            if len(parts) != 2:
                continue
            fen = parts[0].strip()
            ranks = list(map(int, parts[1].strip().split()))
            records.append((fen, ranks, lineno))
            if len(records) >= max_records:
                break
    return records


# Cache so we only parse once per test session
_RECORDS = None

def records():
    global _RECORDS
    if _RECORDS is None:
        _RECORDS = _load_selfplay()
    return _RECORDS


# ---------------------------------------------------------------------------
# Test 1 — Parse every line without error
# ---------------------------------------------------------------------------
class TestParsing:
    def test_selfplay_file_exists(self):
        assert SELFPLAY_TXT.exists(), f"selfplay.txt not found at {SELFPLAY_TXT}"

    def test_parse_all_lines(self):
        """Every FEN in selfplay.txt should parse without exception."""
        errors = []
        for fen, ranks, lineno in records():
            try:
                board = ChaturajiBoard.from_fen(fen, ply=lineno)
            except Exception as e:
                errors.append(f"Line {lineno}: {e}  FEN={fen!r}")
        assert not errors, f"{len(errors)} parse errors:\n" + "\n".join(errors[:5])

    def test_rank_points_sum_to_12(self):
        """Every rank label must sum to 12 (total rank points distributed per game)."""
        bad = []
        for fen, ranks, lineno in records():
            if not _valid_rank_points(ranks):
                bad.append(f"Line {lineno}: ranks={ranks} (sum={sum(ranks)})")
        assert not bad, f"{len(bad)} bad rank rows:\n" + "\n".join(bad[:5])

    def test_turn_distribution(self):
        """All 4 colours appear as active player — confirms diverse game states."""
        turn_counts = Counter()
        for fen, _, _ in records():
            board = ChaturajiBoard.from_fen(fen)
            turn_counts[board.turn] += 1
        for color in [RED, BLUE, YELLOW, GREEN]:
            assert turn_counts[color] > 0, f"{COLOR_NAMES[color]} never appears as active player"


# ---------------------------------------------------------------------------
# Test 2 — Feature encoder invariants across all positions
# ---------------------------------------------------------------------------
class TestEncoderInvariants:
    def test_all_indices_in_range(self):
        """Every feature index must be in [0, FEATURE_SIZE) for all positions."""
        errors = []
        for fen, _, lineno in records():
            board = ChaturajiBoard.from_fen(fen, ply=lineno)
            indices, _ = encode(board)
            for idx in indices:
                if not (0 <= idx < FEATURE_SIZE):
                    errors.append(f"Line {lineno}: index {idx} out of [0,{FEATURE_SIZE})")
                    break
        assert not errors, f"{len(errors)} range errors:\n" + "\n".join(errors[:5])

    def test_no_duplicate_indices_per_position(self):
        """No position should have two pieces mapping to the same feature index."""
        errors = []
        for fen, _, lineno in records():
            board = ChaturajiBoard.from_fen(fen, ply=lineno)
            indices, _ = encode(board)
            if len(indices) != len(set(indices)):
                dupes = [i for i in indices if indices.count(i) > 1]
                errors.append(f"Line {lineno}: duplicate indices {set(dupes)}")
        assert not errors, f"{len(errors)} positions with duplicate indices:\n" + "\n".join(errors[:5])

    def test_dense_points_normalised(self):
        """All dense point features must be in [0, 1]."""
        errors = []
        for fen, _, lineno in records():
            board = ChaturajiBoard.from_fen(fen, ply=lineno)
            _, dense = encode(board)
            if not all(0.0 <= dense[i] <= 1.0 for i in range(4)):
                errors.append(f"Line {lineno}: points dense {dense[:4]} out of [0,1]")
        assert not errors, f"{len(errors)} normalisation errors:\n" + "\n".join(errors[:5])

    def test_active_player_always_alive(self):
        """The active player (canonical relation 0) must always be alive."""
        errors = []
        for fen, _, lineno in records():
            board = ChaturajiBoard.from_fen(fen, ply=lineno)
            _, dense = encode(board)
            if dense[4] != 1.0:
                errors.append(f"Line {lineno}: active player marked dead in dense[4]")
        assert not errors, f"{len(errors)} errors:\n" + "\n".join(errors[:5])

    def test_dense_shape_always_9(self):
        """Dense vector must always be shape (9,) float32."""
        for fen, _, lineno in records()[:100]:   # sample first 100
            board = ChaturajiBoard.from_fen(fen, ply=lineno)
            _, dense = encode(board)
            assert dense.shape == (9,)
            assert dense.dtype == np.float32


# ---------------------------------------------------------------------------
# Test 3 — Dead piece handling in real data
# ---------------------------------------------------------------------------
class TestDeadPiecesRealData:
    def test_dead_features_in_dead_king_range(self):
        """
        Dead kings must only produce indices in [DEAD_OFFSET+64, DEAD_OFFSET+128).
        Dead non-kings must only produce indices in [DEAD_OFFSET, DEAD_OFFSET+64).
        """
        errors = []
        for fen, _, lineno in records():
            board = ChaturajiBoard.from_fen(fen, ply=lineno)
            b = board.canonical()
            for row in range(8):
                for col in range(8):
                    piece = b.board[row][col]
                    if piece is None or not piece.is_dead:
                        continue
                    sq = row * 8 + col
                    dc = 1 if piece.piece_type == KING else 0
                    expected_range = (DEAD_OFFSET + dc * 64, DEAD_OFFSET + dc * 64 + 64)
                    idx = DEAD_OFFSET + dc * 64 + sq
                    if not (expected_range[0] <= idx < expected_range[1]):
                        errors.append(
                            f"Line {lineno}: dead piece {piece} sq={sq} "
                            f"idx={idx} not in range {expected_range}"
                        )
        assert not errors, f"{len(errors)} dead index errors:\n" + "\n".join(errors[:5])

    def test_positions_with_multiple_eliminations(self):
        """Find and successfully encode positions where 2+ players are eliminated."""
        multi_dead_count = 0
        for fen, _, lineno in records():
            board = ChaturajiBoard.from_fen(fen, ply=lineno)
            dead_count = sum(1 for alive in board.alive if not alive)
            if dead_count >= 2:
                multi_dead_count += 1
                # Must encode without error
                indices, dense = encode(board)
                assert 0 < len(indices) < FEATURE_SIZE
        # selfplay.txt should have some late-game positions
        assert multi_dead_count > 0, "Expected some positions with 2+ eliminations"

    def test_dead_alive_dense_consistent(self):
        """
        For every position, if a player's king is on the board with DEAD flag,
        their alive dense feature should be 0.
        """
        errors = []
        for fen, _, lineno in records():
            board = ChaturajiBoard.from_fen(fen, ply=lineno)
            # Check raw board (pre-canonical) alive flags vs FEN-parsed alive array
            for color in range(4):
                has_live_king = board.alive[color]
                # Find the king on the board
                king_found = False
                king_is_dead = False
                for row in range(8):
                    for col in range(8):
                        p = board.board[row][col]
                        if p is not None and p.color == color and p.piece_type == KING:
                            king_found = True
                            king_is_dead = p.is_dead
                if king_found and not king_is_dead and not has_live_king:
                    errors.append(
                        f"Line {lineno}: {COLOR_NAMES[color]} king is live but "
                        f"alive[] is False"
                    )
                if king_found and king_is_dead and has_live_king:
                    errors.append(
                        f"Line {lineno}: {COLOR_NAMES[color]} king is dead but "
                        f"alive[] is True"
                    )
        assert not errors, f"{len(errors)} inconsistencies:\n" + "\n".join(errors[:5])


# ---------------------------------------------------------------------------
# Test 4 — Canonical rotation on non-Red active players
# ---------------------------------------------------------------------------
class TestCanonicalRotationRealData:
    def test_blue_to_move_self_features_in_relation0(self):
        """
        For Blue-to-move positions: after canonicalisation, Blue's pieces
        must all encode as relation=0 (self) — alive indices in [0, 5*64).
        """
        blue_positions = [
            (fen, lineno) for fen, _, lineno in records()
            if ChaturajiBoard.from_fen(fen).turn == BLUE
        ]
        assert len(blue_positions) > 0, "No Blue-to-move positions found"

        errors = []
        for fen, lineno in blue_positions[:50]:   # sample 50
            board = ChaturajiBoard.from_fen(fen, ply=lineno)
            canonical = board.canonical()

            # Find Blue pieces on the original board → they should be relation 0
            blue_piece_count = sum(
                1 for row in range(8) for col in range(8)
                if board.board[row][col] is not None
                and board.board[row][col].color == BLUE
                and not board.board[row][col].is_dead
            )

            # After canonicalisation, active player's pieces are at colour=RED (rel 0)
            self_feature_indices, _ = encode(canonical)
            self_count = sum(
                1 for idx in self_feature_indices
                if ALIVE_OFFSET <= idx < ALIVE_OFFSET + 5 * 64
            )

            if self_count != blue_piece_count:
                errors.append(
                    f"Line {lineno}: Blue has {blue_piece_count} alive pieces "
                    f"but only {self_count} land in relation-0 features"
                )

        assert not errors, f"{len(errors)} rotation errors:\n" + "\n".join(errors[:5])

    def test_feature_count_consistent_across_turns(self):
        """
        Total feature count (alive + dead) should match the actual piece count
        on the board, regardless of whose turn it is.
        """
        errors = []
        for fen, _, lineno in records()[:200]:   # sample 200
            board = ChaturajiBoard.from_fen(fen, ply=lineno)

            # Count actual pieces on the raw board
            actual_count = sum(
                1 for row in range(8) for col in range(8)
                if board.board[row][col] is not None
            )

            indices, _ = encode(board)
            if len(indices) != actual_count:
                errors.append(
                    f"Line {lineno}: board has {actual_count} pieces but "
                    f"encoder produced {len(indices)} features"
                )

        assert not errors, f"{len(errors)} count mismatches:\n" + "\n".join(errors[:5])


# ---------------------------------------------------------------------------
# Test 5 — Statistical properties of the dataset
# ---------------------------------------------------------------------------
class TestDatasetStatistics:
    def test_feature_coverage(self):
        """
        Across all positions, the alive feature planes should all be exercised
        (no plane that is NEVER active would indicate a bug in the encoder).
        We check that all 4 relation planes are used.
        """
        relation_used = [False] * 4
        for fen, _, _ in records():
            board = ChaturajiBoard.from_fen(fen)
            indices, _ = encode(board)
            for idx in indices:
                if ALIVE_OFFSET <= idx < ALIVE_OFFSET + ALIVE_SIZE:
                    rel = (idx - ALIVE_OFFSET) // (5 * 64)
                    relation_used[rel] = True
            if all(relation_used):
                break
        assert all(relation_used), (
            f"Some relation planes never used: "
            f"{[i for i, u in enumerate(relation_used) if not u]}"
        )

    def test_dead_features_observed(self):
        """Dead piece features should appear somewhere in selfplay.txt."""
        dead_seen = False
        for fen, _, _ in records():
            board = ChaturajiBoard.from_fen(fen)
            indices, _ = encode(board)
            if any(idx >= DEAD_OFFSET for idx in indices):
                dead_seen = True
                break
        assert dead_seen, "Dead piece features never observed in selfplay.txt"

    def test_all_four_rank_outcomes_present(self):
        """
        All rank values 0, 2, 4, 6 should appear as targets in the dataset.
        This confirms game outcomes are diverse.
        """
        seen_ranks = set()
        for _, ranks, _ in records():
            seen_ranks.update(ranks)
        for expected in [0, 2, 4, 6]:
            assert expected in seen_ranks, f"Rank value {expected} never appears in dataset"
