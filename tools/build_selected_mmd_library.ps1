param([string]$BlenderPath = 'D:/blender/blender.exe', [string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $BlenderPath)) { throw 'Pass -BlenderPath with your Blender executable.' }
Push-Location -LiteralPath $projectPath
try {
    python tools/prepare_selected_mmd.py
    if ($LASTEXITCODE -ne 0) { throw 'Source selection preparation failed.' }
    & $BlenderPath --background --factory-startup --python-exit-code 1 --python (Join-Path $PSScriptRoot 'mmd_pipeline/bake_selected_sources.py')
    if ($LASTEXITCODE -ne 0) { throw 'Independent Blender source solve failed. Inspect bake_journal.json.' }
    python tools/build_selected_mmd_library.py
    if ($LASTEXITCODE -ne 0) { throw 'Shared animation build failed.' }
    & (Join-Path $PSScriptRoot 'verify_selected_mmd_library.ps1') -GodotPath $GodotPath
} finally {
    Pop-Location
}
