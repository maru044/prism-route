param([string]$BlenderPath='D:\blender\blender.exe',[string]$PythonPath='python',[string]$GodotPath='',[switch]$AuditOnly)
$ErrorActionPreference='Stop'
$rosterProjectRoot=Split-Path -Parent $PSScriptRoot
$rosterWorkRoot='D:\Prism Route\research\character_batch_20261104_05'
if (-not $GodotPath) { $GodotPath=Join-Path $rosterProjectRoot '.current_map_build\runtime\Godot_v4.7.2-stable_win64_console.exe' }
$rosterConfig=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'character_batch\fifth_batch_profiles.json') -Raw -Encoding utf8 | ConvertFrom-Json
Push-Location -LiteralPath $rosterProjectRoot
try {
    & $PythonPath -X utf8 'tools/character_batch/prepare_first_batch.py' --profiles 'tools/character_batch/fifth_batch_profiles.json' --work-dir $rosterWorkRoot
    if ($LASTEXITCODE -ne 0) { throw 'Source preparation failed' }
    $rosterLogRoot=Join-Path $rosterWorkRoot 'logs'
    New-Item -ItemType Directory -Path $rosterLogRoot -Force | Out-Null
    foreach ($rosterProfile in $rosterConfig.profiles) {
        $rosterId=[string]$rosterProfile.id
        if ($rosterId -notmatch '^[a-z0-9_]+$') { throw 'Invalid profile identifier' }
        $rosterMode=if ($AuditOnly) { 'audit' } else { 'build' }
        $rosterScript=Join-Path $PSScriptRoot 'character_batch\blender_batch.py'
        $rosterProcess=Start-Process -FilePath $BlenderPath -ArgumentList @('--background','--python-exit-code','1','--python',('"'+$rosterScript+'"'),'--','--id',$rosterId,'--mode',$rosterMode,'--work-dir',('"'+$rosterWorkRoot+'"')) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $rosterLogRoot ($rosterId+'.log')) -RedirectStandardError (Join-Path $rosterLogRoot ($rosterId+'.error.log'))
        if ($rosterProcess.ExitCode -ne 0) { throw "Blender failed for $rosterId; see $rosterLogRoot" }
        Write-Output "Completed $rosterMode for $rosterId"
    }
    if ($AuditOnly) { return }
    & $PythonPath -X utf8 'tools/character_batch/package_first_batch.py' --work-dir $rosterWorkRoot --manifest-name 'fifth_batch.json'
    if ($LASTEXITCODE -ne 0) { throw 'VRM packaging failed' }
    & $GodotPath --headless --editor --path $rosterProjectRoot --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
    & $GodotPath --headless --path $rosterProjectRoot --script res://tools/verify_character_roster_1104.gd --fixed-fps 60 -- --catalog="res://assets/characters/roster/fifth_batch.json" --out="res://docs/character_batch_1104_05/"
    if ($LASTEXITCODE -ne 0) { throw 'Runtime checks failed' }
} finally { Pop-Location }
