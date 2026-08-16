import os
import shutil
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DIST_DIR = REPO_ROOT / 'dist' / 'flutteraji-windows-x64'
ZIP_PATH = REPO_ROOT / 'dist' / 'flutteraji-windows-x64-v1.0.0.zip'

if DIST_DIR.exists():
    shutil.rmtree(DIST_DIR)
DIST_DIR.mkdir(parents=True, exist_ok=True)

# 1. Copy Flutter release build
release_dir = REPO_ROOT / 'build' / 'windows' / 'x64' / 'runner' / 'Release'
for item in release_dir.iterdir():
    if item.is_dir():
        shutil.copytree(item, DIST_DIR / item.name)
    else:
        shutil.copy2(item, DIST_DIR / item.name)

# 2. Copy Engine DLL and CLI executable
shutil.copy2(REPO_ROOT / 'engine' / 'chaturaji.dll', DIST_DIR / 'chaturaji.dll')
shutil.copy2(REPO_ROOT / 'engine' / 'chaturaji.exe', DIST_DIR / 'chaturaji.exe')

# 3. Copy NNUE model checkpoints
nnue_dest = DIST_DIR / 'nnue' / 'checkpoints'
nnue_dest.mkdir(parents=True, exist_ok=True)
shutil.copy2(REPO_ROOT / 'nnue' / 'checkpoints' / 'gen4.nnue', nnue_dest / 'gen4.nnue')

# 4. Copy LICENSE and add README.txt
shutil.copy2(REPO_ROOT / 'LICENSE', DIST_DIR / 'LICENSE')

readme_content = """Flutteraji - Chaturaji Analysis Tool & Engine (v1.0.0)
=====================================================

Quick Start:
1. Double-click `flutteraji.exe` to launch the graphical analysis board.
2. The app automatically loads the native C++ engine (`chaturaji.dll`)
   and the Gen 4 NNUE neural network model (`nnue/checkpoints/gen4.nnue`).

CLI Engine Usage:
  Open a terminal in this folder and run:
  - `chaturaji.exe validate`                       (run perft test suite)
  - `chaturaji.exe mcts`                           (run MCTS search on start position)
  - `chaturaji.exe probe --nnue nnue\\checkpoints\\gen4.nnue` (evaluate moves with NNUE)
  - `chaturaji.exe bench --nnue nnue\\checkpoints\\gen4.nnue` (benchmark NNUE eval speed)

GitHub Repository:
  https://github.com/Foobork/flutteraji
"""

(DIST_DIR / 'README.txt').write_text(readme_content, encoding='utf-8')

# 5. Create zip archive
if ZIP_PATH.exists():
    ZIP_PATH.unlink()

print(f"Creating zip package at: {ZIP_PATH}")
with zipfile.ZipFile(ZIP_PATH, 'w', zipfile.ZIP_DEFLATED) as zipf:
    for root, dirs, files in os.walk(DIST_DIR):
        for file in files:
            file_path = Path(root) / file
            arcname = file_path.relative_to(DIST_DIR)
            zipf.write(file_path, arcname)

size_mb = ZIP_PATH.stat().st_size / (1024 * 1024)
print(f"Successfully packaged {ZIP_PATH.name} ({size_mb:.2f} MB)")
