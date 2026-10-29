param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $GodotPath = Join-Path $projectPath '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe'
    if (-not (Test-Path -LiteralPath $GodotPath)) {
        $GodotPath = 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
    }
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Pass -GodotPath with the Godot executable.' }
$logDirectory = Join-Path $projectPath '.current_map_build'
[IO.Directory]::CreateDirectory($logDirectory) | Out-Null
$logPath = Join-Path $logDirectory 'hologram_preview.log'
& $GodotPath --path $projectPath --log-file $logPath --scene 'res://scenes/character_hologram_test.tscn'
exit $LASTEXITCODE
