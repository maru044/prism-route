param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $GodotPath = Join-Path $projectPath '.current_map_build/runtime/Godot_v4.7.2-stable_win64.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Pass -GodotPath with the Godot executable.' }
& $GodotPath --path $projectPath --scene 'res://scenes/map_1021.tscn' -- --island-saddle-preview
exit $LASTEXITCODE
