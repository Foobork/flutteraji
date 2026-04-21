$wsh = New-Object -ComObject WScript.Shell
$minutes = 600
$end = (Get-Date).AddMinutes($minutes)
Write-Host "Keeping awake for $minutes minutes (until $end)..."
while ((Get-Date) -lt $end) {
    $wsh.SendKeys('{SCROLLLOCK}')
    Start-Sleep -Seconds 59
    $wsh.SendKeys('{SCROLLLOCK}')
}
Write-Host "Done."
