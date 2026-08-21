# automate_gen7.ps1
# End-to-end Gen 7 pipeline:
# Multi-threaded Self-play (Gen 4 teacher, 1500 iters, temp-plies 6) ->
# Parse -> Merge with Gen 4 -> Train -> Export -> Match vs Gen 4.
#
# Usage:
#   powershell -File automate_gen7.ps1
#   powershell -File automate_gen7.ps1 -Games 1500 -Iters 1500

param(
    [switch]$SkipSelfPlay,
    [int]$Games = 2000,
    [int]$Iters = 1500,
    [int]$TempPlies = 6,
    [int]$Threads = 6,
    [int]$Seed = 777,
    [float]$QWeight = 0.35,
    [int]$Epochs = 30,
    [int]$MatchGames = 80
)

$ErrorActionPreference = "Stop"
$python = "nnue\.venv\Scripts\python.exe"
$engine = "engine\build\Release\chaturaji.exe"
$selfplayTxt = "engine\selfplay_gen7.txt"
$freshBin = "nnue\data\gen7_fresh.bin"
$combinedBin = "nnue\data\gen7_combined.bin"
$checkpointPt = "nnue\checkpoints\gen7.pt"
$checkpointNnue = "nnue\checkpoints\gen7.nnue"
$matchResult = "engine\gen7_match_result.txt"

Write-Host "========================================================="
Write-Host "  Chaturaji NNUE Gen 7 Pipeline"
Write-Host "========================================================="
Write-Host "Games: $Games | Iters: $Iters | Temp-Plies: $TempPlies | Threads: $Threads"
Write-Host "Q-Weight: $QWeight | Epochs: $Epochs | Match Games: $MatchGames"
Write-Host ""

# Step 1: Self-play
if (-not $SkipSelfPlay) {
    Write-Host "[1/5] Running multi-threaded self-play with Gen 4 teacher..."
    & $engine selfplay `
        --nnue nnue\checkpoints\gen4.nnue `
        --games $Games --iters $Iters --temp-plies $TempPlies `
        --threads $Threads --seed $Seed --out $selfplayTxt
    if ($LASTEXITCODE -ne 0) { Write-Host "Self-play failed!"; exit 1 }
} else {
    Write-Host "[1/5] Skipping self-play; using existing $selfplayTxt"
}

if (-not (Test-Path $selfplayTxt)) {
    Write-Host "Error: $selfplayTxt not found!"
    exit 1
}

# Step 2: Parse self-play to binary
Write-Host "`n[2/5] Parsing self-play data to binary format..."
& $python nnue\parse_selfplay.py --input $selfplayTxt --output $freshBin --skip-opening 0
if ($LASTEXITCODE -ne 0) { Write-Host "Parsing failed!"; exit 1 }

# Step 3: Merge fresh data with Gen 4 baseline
Write-Host "`n[3/5] Merging fresh data with Gen 4 corpus..."
& $python nnue\merge_datasets.py --inputs $freshBin nnue\data\gen4.bin --output $combinedBin
if ($LASTEXITCODE -ne 0) { Write-Host "Merge failed!"; exit 1 }

# Step 4: Train model
Write-Host "`n[4/5] Training Gen 7 (Q-Weight: $QWeight, Epochs: $Epochs, Batch: 1024)..."
& $python nnue\train.py --data $combinedBin --out $checkpointPt --epochs $Epochs --batch 1024 --lr 1e-3 --q-weight $QWeight --threads $Threads
if ($LASTEXITCODE -ne 0) { Write-Host "Training failed!"; exit 1 }

# Step 5: Export to binary
Write-Host "`n[5/5] Exporting model to binary format ($checkpointNnue)..."
& $python nnue\export.py -c $checkpointPt -o $checkpointNnue
if ($LASTEXITCODE -ne 0) { Write-Host "Export failed!"; exit 1 }

# Step 6: Head-to-Head Tournament
Write-Host "`n========================================================="
Write-Host "  Tournament: Gen 7 vs Gen 4 ($MatchGames games @ 1000 iters/move)"
Write-Host "========================================================="
& $engine match --nnue1 $checkpointNnue --nnue2 nnue\checkpoints\gen4.nnue --games $MatchGames --iters 1000 |
    Tee-Object -FilePath $matchResult

Write-Host "`nPipeline completed successfully! Results written to $matchResult"
