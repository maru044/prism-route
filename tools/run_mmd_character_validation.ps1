param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $GodotPath = Join-Path $projectPath '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Pass -GodotPath with your Godot executable.' }
$previewLog = Join-Path $projectPath '.godot/mmd_character_preview.log'
& $GodotPath --path $projectPath --log-file $previewLog res://scenes/character_mmd_validation.tscn
