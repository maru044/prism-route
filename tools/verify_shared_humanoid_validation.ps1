param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath = Join-Path $projectPath '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Pass -GodotPath with your Godot executable.' }
$reportPath = Join-Path $projectPath 'docs/validation/shared_humanoid_20261103/verification.json'
$logPath = Join-Path $projectPath '.godot/shared_humanoid_validation.log'
if (Test-Path -LiteralPath $reportPath) { Remove-Item -LiteralPath $reportPath }
& $GodotPath --headless --fixed-fps 60 --quit-after 3000 --path $projectPath --log-file $logPath --script res://tools/verify_shared_humanoid_validation.gd
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $reportPath)) { throw 'Shared humanoid validation did not produce a successful fresh report.' }
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
if (-not $report.passed) { throw 'Shared humanoid validation failed.' }
Write-Output "Shared humanoid validation passed: $($report.rotation_checks) rotation checks, $($report.shared_resource_identity_checks) resource identity checks."
