param(
    [string]$GodotPath = '',
    [switch]$World
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $GodotPath = Join-Path $projectPath '.current_map_build\runtime\Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot not found: $GodotPath. Pass -GodotPath to select the executable."
}
$scenePath = if ($World) { 'res://scenes/map_1021.tscn' } else { 'res://scenes/water_1026_test.tscn' }
& $GodotPath --path $projectPath --scene $scenePath
exit $LASTEXITCODE
