param([string]$GodotPath='')
$ErrorActionPreference='Stop'
$rosterProjectRoot=Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath=Join-Path $rosterProjectRoot '.current_map_build\runtime\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Please provide the Godot 4.7.2 executable with -GodotPath.' }
& $GodotPath --path $rosterProjectRoot 'res://scenes/character_roster_review.tscn'
