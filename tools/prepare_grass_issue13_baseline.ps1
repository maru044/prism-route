$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$sourceLines = & git -c "safe.directory=$projectPath" -C $projectPath show 'abfc7e4:scripts/grass_volume_streamer.gd'
if ($LASTEXITCODE -ne 0) { throw 'Cannot read the pinned abfc7e4 baseline from Git history.' }
$cachePath = Join-Path $projectPath '.current_map_build'
[IO.Directory]::CreateDirectory($cachePath) | Out-Null
[IO.File]::WriteAllLines((Join-Path $cachePath 'grass_streamer_issue13_baseline.gd'),$sourceLines,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $cachePath '.gdignore'),'', [Text.UTF8Encoding]::new($false))
