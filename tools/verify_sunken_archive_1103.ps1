param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath = Join-Path $projectPath '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe' }
$reportPath = Join-Path $projectPath 'docs/concepts/coastal_sunken_archive_1103/game/verification.json'
if (Test-Path -LiteralPath $reportPath) { Remove-Item -LiteralPath $reportPath }
& $GodotPath --headless --fixed-fps 60 --path $projectPath --log-file (Join-Path $projectPath '.godot/sunken_archive_validation.log') --script res://tools/verify_sunken_archive_1103.gd
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $reportPath)) { throw 'Native court verification did not produce a fresh report.' }
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
if (-not $report.passed) { throw 'Native court integration checks failed.' }
Write-Output 'Sunken court: stairs, colonly ramp, gallery, entrance and map spawns passed.'
