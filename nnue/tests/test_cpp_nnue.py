"""
nnue/tests/test_cpp_nnue.py
~~~~~~~~~~~~~~~~~~~~~~~~~~~
Verify that the C++ NNUE implementation (with AVX2 SIMD) matches the 
Python reference model.py + features.py.
"""

import sys, os
import subprocess
import pytest
import torch
import numpy as np
from pathlib import Path

# Add nnue dir to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from chaturaji_board import ChaturajiBoard
from features import encode
from model import ChaturajiNNUE

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
REPO_ROOT    = Path(__file__).resolve().parents[2]
EXE_PATH     = REPO_ROOT / "engine" / "chaturaji.exe"
MODEL_PATH   = REPO_ROOT / "nnue" / "checkpoints" / "gen0.pt"
NNUE_PATH    = REPO_ROOT / "nnue" / "checkpoints" / "gen0.nnue"
SELFPLAY_TXT = REPO_ROOT / "engine" / "selfplay.txt"

@pytest.fixture(scope="module")
def python_model():
    model = ChaturajiNNUE()
    checkpoint = torch.load(MODEL_PATH, map_location='cpu', weights_only=True)
    if isinstance(checkpoint, dict) and 'state_dict' in checkpoint:
        model.load_state_dict(checkpoint['state_dict'])
    else:
        model.load_state_dict(checkpoint)
    model.eval()
    return model

def run_cpp_probe(fen: str):
    """Run chaturaji.exe probe and parse the canonical probabilities."""
    cmd = [str(EXE_PATH), "probe", "--nnue", str(MODEL_PATH.with_suffix('.nnue')), "--fen", fen]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    
    # We want to find the line containing "Position eval (before any move)"
    # But that section is rounded. 
    # Let's find a move line like:
    # "  a2a3       33.6%  [33.6% / 18.2% / 23.2% / 25.0%]"
    # Wait, if we want high precision, we should probably add a raw output mode to probe.
    # For now, let's look at the brackets [...] which have more precision.
    
    lines = result.stdout.splitlines()
    for line in lines:
        if "[" in line and "]" in line and "/" in line:
            bracket_content = line[line.find("[")+1 : line.find("]")]
            parts = [p.strip() for p in bracket_content.split("/")]
            
            # Ensure the parts are actually numbers (not "self", "left", etc.)
            try:
                # The updated C++ probe outputs raw floats like [0.288183 / 0.215647 / ...]
                probs = [float(p) for p in parts]
                return np.array(probs)
            except ValueError:
                continue
            
    raise ValueError(f"Failed to parse probabilities from C++ output: {result.stdout}")

def get_python_eval(model, fen: str):
    """Get Python model's probabilities for a FEN."""
    board = ChaturajiBoard.from_fen(fen)
    indices, dense = encode(board)
    
    t_idx = torch.tensor(indices, dtype=torch.long)
    t_off = torch.zeros(1, dtype=torch.long)
    t_den = torch.tensor(dense, dtype=torch.float32).unsqueeze(0)
    
    with torch.no_grad():
        probs = model(t_idx, t_off, t_den).squeeze(0).numpy()
    return probs

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def test_start_pos_parity(python_model):
    """Check that Red's first move matches exactly."""
    fen = "bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r"
    py_probs = get_python_eval(python_model, fen)
    cpp_probs = run_cpp_probe(fen)
    
    print(f"\nPython: {py_probs}")
    print(f"C++:    {cpp_probs}")
    
    np.testing.assert_allclose(py_probs, cpp_probs, atol=1e-4)

def test_random_positions_from_selfplay(python_model):
    """Test 20 random positions from the self-play dataset."""
    if not SELFPLAY_TXT.exists():
        pytest.skip("selfplay.txt not found")
        
    with open(SELFPLAY_TXT) as f:
        lines = f.readlines()
    
    # Sample 20 positions
    indices = np.random.choice(len(lines), 20, replace=False)
    
    for idx in indices:
        fen = lines[idx].split(' | ')[0].strip()
        print(f"Testing FEN: {fen}")
        
        py_probs = get_python_eval(python_model, fen)
        cpp_probs = run_cpp_probe(fen)
        
        # Tolerate small float diffs (1e-4 is plenty for 32-bit float parity)
        np.testing.assert_allclose(py_probs, cpp_probs, atol=1e-4, 
                                   err_msg=f"Mismatch at FEN: {fen}")

if __name__ == "__main__":
    # If run directly, just test start pos
    import sys
    model = ChaturajiNNUE()
    checkpoint = torch.load(MODEL_PATH, map_location='cpu', weights_only=True)
    model.load_state_dict(checkpoint['state_dict'] if 'state_dict' in checkpoint else checkpoint)
    model.eval()
    
    fen = "bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r"
    print(f"Python: {get_python_eval(model, fen)}")
    print(f"C++:    {run_cpp_probe(fen)}")
