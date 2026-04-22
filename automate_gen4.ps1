# automate_gen4.ps1
# Automates the Gen 4 pipeline: Wait for data -> Parse -> Train -> Export -> Match -> Done.

$data_gen_pid = 44396
$keep_awake_pid = 44400
$python = "nnue\.venv\Scripts\python.exe"
$engine = "engine\build\Release\chaturaji_cli.exe"

Write-Host "Waiting for data generation (PID $data_gen_pid) to finish..."
try {
    Wait-Process -Id $data_gen_pid -ErrorAction SilentlyContinue
} catch {
    Write-Host "Process $data_gen_pid not found or already finished."
}

Write-Host "Data generation finished. Starting parsing..."
& $python nnue\parse_selfplay.py --input engine\selfplay_gen4.txt --output nnue\data\gen4.bin --skip-opening 0
if ($LASTEXITCODE -ne 0) { Write-Host "Parsing failed!"; exit 1 }

Write-Host "Starting Gen 4 training (Hybrid q_weight=0.5)..."
& $python nnue\train.py --data nnue\data\gen4.bin --out nnue\checkpoints\gen4.pt --epochs 40 --q-weight 0.5
if ($LASTEXITCODE -ne 0) { Write-Host "Training failed!"; exit 1 }

Write-Host "Exporting Gen 4 model..."
& $python nnue\export.py -c nnue\checkpoints\gen4.pt -o nnue\checkpoints\gen4.nnue
if ($LASTEXITCODE -ne 0) { Write-Host "Export failed!"; exit 1 }

Write-Host "Running evaluation match: Gen 4 vs Gen 3..."
& $engine match --nnue1 nnue\checkpoints\gen4.nnue --nnue2 nnue\checkpoints\gen3.nnue --games 40 --iters 1000 | Tee-Object -FilePath "engine\gen4_match_result.txt"

Write-Host "Gen 4 cycle complete. Terminating keep_awake (PID $keep_awake_pid)..."
Stop-Process -Id $keep_awake_pid -Force -ErrorAction SilentlyContinue

Write-Host "Pipeline finished successfully."
