param(
    [string]$GodotPath = '',
    [ValidateRange(2, 4)][int]$Workers = 2
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$cachePath = Join-Path $projectPath '.current_map_build'
[IO.Directory]::CreateDirectory($cachePath) | Out-Null
if (-not $GodotPath) {
    $portablePath = Join-Path $cachePath 'runtime/Godot_v4.7.2-stable_win64_console.exe'
    if (Test-Path -LiteralPath $portablePath) { $GodotPath = $portablePath }
    else {
        $foundGodot = Get-Command godot -ErrorAction SilentlyContinue
        if (-not $foundGodot) { throw 'Pass -GodotPath with your Godot console executable.' }
        $GodotPath = $foundGodot.Source
    }
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Godot not found: $GodotPath" }
$buildRuns = @()
foreach ($workerIndex in 0..($Workers - 1)) {
    $workerLog = (Join-Path $cachePath "grass_bake_$workerIndex.log").Replace('\', '/')
    $workerArgs = @('--headless', '--path', ('"' + $projectPath + '"'), '--script',
        'res://tools/bake_grass_issue13.gd', '--log-file', ('"' + $workerLog + '"'),
        '--', '--full', "--shards=$Workers", "--shard=$workerIndex", '--grass-no-bake', '--grass-no-profile')
    $buildRuns += Start-Process -FilePath $GodotPath -ArgumentList $workerArgs -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $cachePath "grass_bake_$workerIndex.out") `
        -RedirectStandardError (Join-Path $cachePath "grass_bake_$workerIndex.err")
}
foreach ($buildRun in $buildRuns) {
    $buildRun.WaitForExit()
    if ($buildRun.ExitCode -ne 0) { throw "Grass worker failed: $($buildRun.ExitCode). See $cachePath logs." }
}
& python (Join-Path $PSScriptRoot 'merge_grass_bake_issue13.py') --shards $Workers
if ($LASTEXITCODE -ne 0) { throw 'Grass manifest validation failed.' }
