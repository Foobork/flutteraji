import sys, os
import torch
import numpy as np
from pathlib import Path

# Ensure we can import other files in this dir
sys.path.insert(0, os.path.dirname(__file__))

from chaturaji_board import ChaturajiBoard
from features import encode
from model import ChaturajiNNUE

def probe(fen: str, model_path: str):
    # Load model
    model = ChaturajiNNUE()
    checkpoint = torch.load(model_path, map_location='cpu', weights_only=True)
    model.load_state_dict(checkpoint['state_dict'] if 'state_dict' in checkpoint else checkpoint)
    model.eval()

    # Parse board
    board = ChaturajiBoard.from_fen(fen)
    indices, dense = encode(board)

    # Convert to tensors
    t_idx = torch.tensor(indices, dtype=torch.long)
    t_off = torch.zeros(1, dtype=torch.long)
    t_den = torch.tensor(dense, dtype=torch.float32).unsqueeze(0)

    # Forward pass
    with torch.no_grad():
        probs = model(t_idx, t_off, t_den).squeeze(0).numpy()

    print(f"FEN: {fen}")
    print(f"Turn: {board.turn} (0=Red, 1=Blue, 2=Yellow, 3=Green)")
    print(f"Python Probs [self, left, across, right]:")
    print(f"  {probs[0]:.6f} / {probs[1]:.6f} / {probs[2]:.6f} / {probs[3]:.6f}")

if __name__ == "__main__":
    fen = sys.argv[1]
    model_path = sys.argv[2]
    probe(fen, model_path)
