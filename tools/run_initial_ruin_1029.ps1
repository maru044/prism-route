param([string]$GodotPath = '', [switch]$Stairs)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $GodotPath = Join-Path $projectPath '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Pass -GodotPath with the Godot executable.' }
$logPath = (Join-Path $projectPath '.current_map_build/initial_ruin_preview.log').Replace('\','/')
$previewArguments=@('--ruin-preview')
if ($Stairs) { $previewArguments+='--ruin-stairs-preview' }
& $GodotPath --path $projectPath --log-file $logPath --scene 'res://scenes/map_1021.tscn' -- @previewArguments
exit $LASTEXITCODE
