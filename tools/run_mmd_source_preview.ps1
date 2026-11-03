param([string]$BlenderPath = 'D:/blender/blender.exe')
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $projectPath 'tools/mmd_preview/blender_source_browser.py'
$config = Get-Content -LiteralPath (Join-Path $projectPath 'tools/mmd_preview/preview_config.json') -Raw | ConvertFrom-Json
if (-not (Test-Path -LiteralPath $BlenderPath)) { throw 'Pass -BlenderPath with your Blender executable.' }
if (Test-Path -LiteralPath $config.preview_blend) {
    & $BlenderPath $config.preview_blend --python $scriptPath
} else {
    & $BlenderPath --factory-startup --python $scriptPath
}
