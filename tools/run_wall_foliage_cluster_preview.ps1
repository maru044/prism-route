param([string]$GodotPath='', [switch]$Verify)
$ErrorActionPreference='Stop'
$projectPath=Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath=Join-Path $projectPath '.current_map_build/runtime/Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Pass -GodotPath with the Godot executable.' }
$entryPath=Join-Path $projectPath 'assets/world/architecture_details_1029/preview_entry.json'
$entry=Get-Content -LiteralPath $entryPath -Raw -Encoding utf8 | ConvertFrom-Json
$logName=if ($Verify) { 'foliage_preview_entry_verify.log' } else { 'wall_foliage_cluster_preview.log' }
$logPath=(Join-Path $projectPath ('.current_map_build/'+$logName)).Replace('\','/')
Write-Host ('Foliage preview: '+$entry.revision+' -> '+$entry.scene)
$previewArgs=@('--path',$projectPath,'--log-file',$logPath,'--scene',$entry.scene)
if ($Verify) { $previewArgs+=@('--','--verify-foliage-preview') }
& $GodotPath @previewArgs
exit $LASTEXITCODE
