param([string]$GodotPath = '', [ValidateSet(30,60,120)][int]$TestFps = 60)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $GodotPath = Join-Path $projectPath '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Pass -GodotPath with your Godot executable.' }
$verifyLog = Join-Path $projectPath ".godot/mmd_vrm_verify_$TestFps.log"
$reportPath = Join-Path $projectPath ".godot/mmd_vrm_validation_$TestFps.json"
if (Test-Path -LiteralPath $reportPath) { Remove-Item -LiteralPath $reportPath }
$maximumFrames = 16 * $TestFps + 1000
& $GodotPath --headless --fixed-fps $TestFps --quit-after $maximumFrames --path $projectPath --log-file $verifyLog --script res://tools/verify_mmd_vrm_validation.gd -- "--test-fps=$TestFps" "--output=$reportPath"
if ($LASTEXITCODE -ne 0) { throw 'MMD to VRM validation failed. Inspect the JSON report and log.' }
if (-not (Test-Path -LiteralPath $reportPath)) { throw 'Verification did not produce a fresh report.' }
$result = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
if (-not $result.passed) { throw 'MMD to VRM validation reported a failure.' }
