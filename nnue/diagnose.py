import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

import torch
import numpy as np
from model import ChaturajiNNUE
from chaturaji_board import ChaturajiBoard
from features import encode

m4 = ChaturajiNNUE()
m4.load_state_dict(torch.load('nnue/checkpoints/gen4.pt', map_location='cpu', weights_only=True))
m4.eval()

m7 = ChaturajiNNUE()
m7.load_state_dict(torch.load('nnue/checkpoints/gen7.pt', map_location='cpu', weights_only=True))
m7.eval()

b = ChaturajiBoard.from_fen('bRbP2yKyByNyR/bNbP2yPyPyPyP/bBbP6/bKbP6/6gPgK/6gPgB/rPrPrPrP2gPgN/rRrNrBrK2gPgR 0/0/0/0 r 0')
idx, den = encode(b)
p4 = m4.evaluate(idx, den)
p7 = m7.evaluate(idx, den)
print(f"Start position eval Gen 4: {[f'{x:.3f}' for x in p4]} (pts: {[f'{x*12:.2f}' for x in p4]})")
print(f"Start position eval Gen 7: {[f'{x:.3f}' for x in p7]} (pts: {[f'{x*12:.2f}' for x in p7]})")
