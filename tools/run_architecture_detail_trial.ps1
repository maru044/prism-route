param([string]$GodotPath='', [switch]$Verify)
$ErrorActionPreference='Stop'
$projectPath=Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath=Join-Path $projectPath '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe' }
$logPath=(Join-Path $projectPath '.current_map_build/architecture_detail_trial.log').Replace('\','/')
$previewArgs=@('--path',$projectPath,'--log-file',$logPath,'--scene','res://scenes/map_1021.tscn','--','--architecture-detail-preview')
if ($Verify) { $previewArgs+='--verify-world-clusters' }
& $GodotPath @previewArgs
exit $LASTEXITCODE
