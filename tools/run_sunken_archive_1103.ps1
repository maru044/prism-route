param([string]$GodotPath = '')
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath = Join-Path $projectPath '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe' }
& $GodotPath --path $projectPath --log-file (Join-Path $projectPath '.godot/sunken_archive_preview.log') res://scenes/map_1021.tscn -- --sunken-archive-preview
