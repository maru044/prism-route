param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath = Join-Path $projectPath '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe' }
$reportPath = Join-Path $projectPath 'docs/validation/mmd_selected_20261103/verification.json'
$logPath = Join-Path $projectPath '.godot/mmd_selected_validation.log'
if (Test-Path -LiteralPath $reportPath) { Remove-Item -LiteralPath $reportPath }
& $GodotPath --headless --fixed-fps 60 --quit-after 6000 --path $projectPath --log-file $logPath --script res://tools/verify_selected_mmd_library.gd
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $reportPath)) { throw 'Selected library verification did not produce a fresh report.' }
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
if (-not $report.passed) { throw 'Selected library verification failed. Inspect verification.json.' }
Write-Output "Selected library passed: $($report.groups) groups, $($report.clips) clips, $($report.resource_identity_checks) shared identities."
