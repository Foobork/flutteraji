import sys
import re
from pathlib import Path

match_file = sys.argv[1] if len(sys.argv) > 1 else 'engine/gen7_match_result.txt'
path = Path(match_file)
if not path.exists():
    print(f"File not found: {path}")
    sys.exit(1)

try:
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()
except Exception:
    with open(path, 'r', encoding='utf-16') as f:
        text = f.read()

games = re.findall(r'Game\s+(\d+):\s+(M[12]=R/Y),\s+M1 points:\s+(\d+),\s+M2 points:\s+(\d+)', text)

m1_as_ry = 0
m2_as_bg = 0
m1_as_bg = 0
m2_as_ry = 0

ry_wins = 0
bg_wins = 0
ties = 0

for g_num, seat, m1_pts, m2_pts in games:
    p1 = int(m1_pts)
    p2 = int(m2_pts)
    if seat == 'M1=R/Y':
        m1_as_ry += p1
        m2_as_bg += p2
        if p1 > p2: ry_wins += 1
        elif p2 > p1: bg_wins += 1
        else: ties += 1
    else:
        m1_as_bg += p1
        m2_as_ry += p2
        if p2 > p1: ry_wins += 1
        elif p1 > p2: bg_wins += 1
        else: ties += 1

print(f"Total games parsed: {len(games)}")
print(f"Seat Advantage: Red/Yellow total = {m1_as_ry + m2_as_ry} pts vs Blue/Green = {m1_as_bg + m2_as_bg} pts")
print(f"When Model 1 (Gen 7) played Red/Yellow:  M1 scored {m1_as_ry} vs M2 {m2_as_bg} (Win rate: {m1_as_ry / (m1_as_ry + m2_as_bg):.1%})")
print(f"When Model 2 (Gen 4) played Red/Yellow:  M2 scored {m2_as_ry} vs M1 {m1_as_bg} (Win rate: {m2_as_ry / (m2_as_ry + m1_as_bg):.1%})")
print(f"\nOverall M1 (Gen 7): {m1_as_ry + m1_as_bg} | Overall M2 (Gen 4): {m2_as_ry + m2_as_bg}")
