"""
evaluate_gen0.py
~~~~~~~~~~~~~~~~
Evaluate the current ChaturajiNNUE gen0 model against self-play data.
"""

import torch
import torch.nn as nn
from torch.utils.data import DataLoader
import numpy as np
from pathlib import Path
import sys

# Add current dir to path to import local modules
sys.path.insert(0, str(Path(__file__).parent))

from dataset import SelfplayDataset
from model import ChaturajiNNUE

def evaluate_model(model_path: Path, data_path: Path, n_samples: int = 10000):
    print(f"Loading model: {model_path}")
    model = ChaturajiNNUE()
    # Load weights
    try:
        checkpoint = torch.load(model_path, map_location='cpu', weights_only=True)
        # If it was saved with a wrapper or as a state_dict
        if isinstance(checkpoint, dict) and 'state_dict' in checkpoint:
            model.load_state_dict(checkpoint['state_dict'])
        else:
            model.load_state_dict(checkpoint)
    except Exception as e:
        print(f"Error loading model: {e}")
        return

    model.eval()

    print(f"Loading data: {data_path}")
    ds = SelfplayDataset(data_path)
    
    # Take a random subset for evaluation
    if n_samples > len(ds):
        n_samples = len(ds)
    
    indices = np.random.choice(len(ds), n_samples, replace=False)
    
    mae_sum = 0.0
    mse_sum = 0.0
    winner_correct = 0
    top2_correct = 0
    
    print(f"Evaluating on {n_samples} samples...")
    
    with torch.no_grad():
        for i, idx in enumerate(indices):
            feat, dense, target = ds[idx]
            
            # target is [self, left, across, right] normalized to sum=1
            # Model output is also [self, left, across, right] probabilities
            
            # Single-position inference
            t_idx = torch.tensor(feat, dtype=torch.long)
            t_off = torch.zeros(1, dtype=torch.long)
            t_den = torch.tensor(dense, dtype=torch.float32).unsqueeze(0)
            
            pred = model(t_idx, t_off, t_den).squeeze(0).numpy()
            
            # Metrics
            diff = np.abs(pred - target)
            mae_sum += np.mean(diff)
            mse_sum += np.mean(diff**2)
            
            # Winner (who got 6 points, or index of max probability)
            actual_winner = np.argmax(target)
            pred_winner = np.argmax(pred)
            if actual_winner == pred_winner:
                winner_correct += 1
                
            # Top-2 (who got 6 and 4 points)
            actual_top2 = set(np.argsort(target)[-2:])
            pred_top2 = set(np.argsort(pred)[-2:])
            if actual_top2 == pred_top2:
                top2_correct += 1
                
            if (i + 1) % 1000 == 0:
                print(f"  Processed {i+1}/{n_samples}...")

    mae = mae_sum / n_samples
    mse = mse_sum / n_samples
    winner_acc = winner_correct / n_samples
    top2_acc = top2_correct / n_samples
    
    print("\nEvaluation Results:")
    print(f"  Mean Absolute Error (MAE): {mae:.4f}")
    print(f"  Mean Squared Error (MSE):  {mse:.4f}")
    print(f"  Winner Accuracy:          {winner_acc:.2%}")
    print(f"  Top-2 Accuracy:           {top2_acc:.2%}")
    
    # Baseline: Random guessing (uniform distribution [0.25, 0.25, 0.25, 0.25])
    # Average target is [0.5, 0.33, 0.16, 0] / sum=1 -> [0.5, 0.33, 0.16, 0] is WRONG
    # Points are [6, 4, 2, 0], sum=12. Normalised: [0.5, 0.33, 0.16, 0]
    # Random MAE vs [0.5, 0.33, 0.16, 0] = (0.25+0.08+0.09+0.25)/4 = 0.1675
    
    print("\nComparison (approximate):")
    print("  Random Guessing MAE:      ~0.1675")
    print("  Perfect Model MAE:         0.0000")

if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parents[1]
    model_path = repo_root / 'nnue' / 'checkpoints' / 'gen0.pt'
    data_path = repo_root / 'nnue' / 'data' / 'gen0.bin'
    
    evaluate_model(model_path, data_path)
