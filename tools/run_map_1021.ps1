param(
    [string]$GodotPath = 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe',
    [switch]$NoUI
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot not found: $GodotPath. Pass -GodotPath to select the executable."
}
$launchArgs = @('--path', $projectPath, '--scene', 'res://scenes/map_1021.tscn')
if ($NoUI) { $launchArgs += @('--', '--no-ui') }
& $GodotPath @launchArgs
exit $LASTEXITCODE
