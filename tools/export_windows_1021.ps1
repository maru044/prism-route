param(
    [string]$GodotPath = '',
    [switch]$Verify
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$cachePath = Join-Path $projectPath '.current_map_build'
$outputPath = Join-Path (Split-Path -Parent $projectPath) 'builds/windows_1021'
if (-not $GodotPath) {
    $GodotPath = Join-Path $cachePath 'runtime/Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Pass -GodotPath with the Godot 4.7.2 console executable.' }
[IO.Directory]::CreateDirectory($outputPath) | Out-Null
$env:PYTHONIOENCODING = 'utf-8'
Push-Location $projectPath
try {
    $templatePath = Join-Path $cachePath 'export_templates/windows_release_x86_64.exe'
    if (-not (Test-Path -LiteralPath $templatePath)) {
        & python (Join-Path $PSScriptRoot 'fetch_godot_windows_template.py')
        if ($LASTEXITCODE -ne 0) { throw 'Could not download the official Windows template.' }
    }
    & $GodotPath --headless --path $projectPath --script res://tools/configure_export_1021.gd `
        --log-file (Join-Path $cachePath 'export_dependencies_1021.log')
    if ($LASTEXITCODE -ne 0) { throw 'Export dependency check failed.' }
    $gamePath = Join-Path $outputPath 'PrismRoute1021.exe'
    & $GodotPath --headless --path $projectPath --export-release 'Windows 1021' $gamePath `
        --log-file (Join-Path $cachePath 'export_windows_1021.log') `
        > (Join-Path $cachePath 'export_windows_1021.out') 2> (Join-Path $cachePath 'export_windows_1021.err')
    if ($LASTEXITCODE -ne 0) { throw 'Windows export failed; see .current_map_build/export_windows_1021.err.' }
    & python (Join-Path $PSScriptRoot 'audit_export_1021.py')
    if ($LASTEXITCODE -ne 0) { throw 'Package integrity or content audit failed.' }
    if ($Verify) {
        $gameArgs = @('--log-file', ('"' + (Join-Path $cachePath 'export_1021_smoke.log') + '"'),
            '--', '--verify-export', ('"--export-report=' + (Join-Path $cachePath 'export_1021_validation.json') + '"'))
        $gameRun = Start-Process -FilePath $gamePath -ArgumentList $gameArgs -WorkingDirectory $outputPath `
            -WindowStyle Hidden -PassThru -Wait `
            -RedirectStandardOutput (Join-Path $cachePath 'export_1021_smoke.out') `
            -RedirectStandardError (Join-Path $cachePath 'export_1021_smoke.err')
        if ($gameRun.ExitCode -ne 0) { throw 'Exported game validation failed.' }
        $validation = Get-Content -LiteralPath (Join-Path $cachePath 'export_1021_validation.json') -Raw | ConvertFrom-Json
        if (-not $validation.passed) { throw 'Exported game reported failed checks.' }
        if (Select-String -LiteralPath (Join-Path $cachePath 'export_1021_smoke.err') `
            -Pattern 'SCRIPT ERROR|SHADER ERROR|Failed to load script|Shader compilation failed' -Quiet) {
            throw 'Exported game has script or shader errors; see export_1021_smoke.err.'
        }
    }
    Write-Output "Windows test build: $gamePath"
} finally { Pop-Location }
