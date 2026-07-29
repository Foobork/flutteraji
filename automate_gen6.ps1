# automate_gen6.ps1
# Full Gen 6 cycle: Self-play (Gen4 teacher, 2000 iters, temp-plies 16) ->
# Parse -> Train -> Export -> Match vs Gen 4.
#
# Usage:
#   powershell -File automate_gen6.ps1
#   powershell -File automate_gen6.ps1 -SkipSelfPlay
#   powershell -File automate_gen6.ps1 -KeepAwakePid 12345

param(
    [switch]$SkipSelfPlay,
    [int]$KeepAwakePid = 0,
    [int]$Games = 10000,
    [int]$Iters = 2000,
    [int]$TempPlies = 16,
    [int]$Seed = 60,
    [int]$MatchGames = 80
)

$ErrorActionPreference = "Stop"
$python = "nnue\.venv\Scripts\python.exe"
$engine = "engine\build\Release\chaturaji_cli.exe"
$outTxt = "engine\selfplay_gen6.txt"

if (-not $SkipSelfPlay) {
    Write-Host "Starting Gen 6 self-play: $Games games, $Iters iters, temp-plies $TempPlies..."
    & $engine selfplay `
        --nnue nnue\checkpoints\gen4.nnue `
        --games $Games --iters $Iters --temp-plies $TempPlies `
        --seed $Seed --out $outTxt --verbose
    if ($LASTEXITCODE -ne 0) { Write-Host "Self-play failed!"; exit 1 }
} else {
    Write-Host "Skipping self-play; using existing $outTxt"
}

if (-not (Test-Path $outTxt)) {
    Write-Host "Missing $outTxt - aborting."
    exit 1
}

Write-Host "Parsing Gen 6 self-play..."
& $python nnue\parse_selfplay.py --input $outTxt --output nnue\data\gen6.bin --skip-opening 0
if ($LASTEXITCODE -ne 0) { Write-Host "Parsing failed!"; exit 1 }

Write-Host "Training Gen 6 (Hybrid q_weight=0.5, 40 epochs)..."
& $python nnue\train.py --data nnue\data\gen6.bin --out nnue\checkpoints\gen6.pt --epochs 40 --q-weight 0.5
if ($LASTEXITCODE -ne 0) { Write-Host "Training failed!"; exit 1 }

Write-Host "Exporting Gen 6 model..."
& $python nnue\export.py -c nnue\checkpoints\gen6.pt -o nnue\checkpoints\gen6.nnue
if ($LASTEXITCODE -ne 0) { Write-Host "Export failed!"; exit 1 }

$matchMsg = "Match: Gen 6 vs Gen 4 - " + $MatchGames + " games, 1000 iters..."
Write-Host $matchMsg
& $engine match --nnue1 nnue\checkpoints\gen6.nnue --nnue2 nnue\checkpoints\gen4.nnue --games $MatchGames --iters 1000 |
    Tee-Object -FilePath "engine\gen6_match_result.txt"

if ($KeepAwakePid -gt 0) {
    Write-Host "Stopping keep_awake (PID $KeepAwakePid)..."
    Stop-Process -Id $KeepAwakePid -Force -ErrorAction SilentlyContinue
}

Write-Host "Gen 6 pipeline finished. See engine\gen6_match_result.txt"
