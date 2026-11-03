param([string]$GodotPath = '',[ValidateSet(30,60,120)][int]$TestFps=60)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath = Join-Path $projectPath '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Pass -GodotPath with your Godot executable.' }
$reportPath = Join-Path $projectPath '.godot/mmd_paired_validation.json'
if ($TestFps -ne 60) { $reportPath = Join-Path $projectPath ".godot/mmd_paired_validation_$TestFps.json" }
$logPath = Join-Path $projectPath ".godot/mmd_paired_validation_$TestFps.log"
if (Test-Path -LiteralPath $reportPath) { Remove-Item -LiteralPath $reportPath }
$maximumFrames = 18*$TestFps+1000
& $GodotPath --headless --fixed-fps $TestFps --quit-after $maximumFrames --path $projectPath --log-file $logPath --script res://tools/verify_mmd_paired_validation.gd -- --entry=loop03_pair "--test-fps=$TestFps" "--output=$reportPath"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $reportPath)) { throw 'Paired motion verification did not produce a successful fresh report.' }
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
if (-not $report.passed) { throw 'Paired motion spatial/synchronization checks failed.' }
