param([string]$GodotPath='', [switch]$Verify)
# Compatibility entry: always forward to the single current preview launcher.
& (Join-Path $PSScriptRoot 'run_wall_foliage_cluster_preview.ps1') @PSBoundParameters
exit $LASTEXITCODE
