param(
    [switch]$VerifyOnly,
    [string]$GodotExe = 'C:/Users/f7212/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.6.3-stable_win64.exe',
    [string]$AsepriteExe = 'C:/Users/f7212/AppData/Local/Programs/Aseprite-build/build/bin/aseprite.exe'
)
$ErrorActionPreference = 'Stop'
$actorRoot = Split-Path $PSScriptRoot -Parent
$projectPath = Join-Path $actorRoot 'godot-client'
$reportPath = Join-Path $actorRoot 'prototype/reports/actors'
foreach ($executable in @($GodotExe, $AsepriteExe)) {
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw "Missing executable: $executable" }
}
foreach ($directory in @('prototype/reports/actors','pixel-assets/prototype-actors/baked-layers','pixel-assets/prototype-actors/source-textures','pixel-assets/prototype-actors/native','pixel-assets/prototype-actors/previews','godot-client/prototype/actors/layers')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $actorRoot $directory) | Out-Null
}
function Invoke-ActorProcess {
    param([string]$Executable, [string[]]$Arguments, [string]$LogName, [string]$ExpectedMarker)
    # Literal executable and quoted arguments, passed directly to one process.
    $quotedArguments = @($Arguments | ForEach-Object { '"' + $_ + '"' })
    $stdout = Join-Path $reportPath ($LogName + '.log')
    $stderr = Join-Path $reportPath ($LogName + '-errors.log')
    $process = Start-Process -FilePath $Executable -ArgumentList $quotedArguments -WorkingDirectory $actorRoot -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $outputText = Get-Content -Raw -LiteralPath $stdout
    $errorText = Get-Content -Raw -LiteralPath $stderr
    if ($process.ExitCode -ne 0 -or $errorText -match 'SCRIPT ERROR|Parse Error|ERROR:') {
        throw "$LogName failed (exit $($process.ExitCode)). Read $stdout and $stderr"
    }
    # Aseprite may exit zero after a Lua exception; require an explicit end marker.
    if ($ExpectedMarker -and ($outputText -notmatch [regex]::Escape($ExpectedMarker))) {
        throw "$LogName did not finish successfully. Read $stdout"
    }
    Write-Output "$LogName PASS"
}
function Invoke-ActorLua {
    param([string]$File, [string]$LogName, [string]$Marker)
    Invoke-ActorProcess $AsepriteExe @('-b','--script-param',("root=" + $actorRoot),'--script',(Join-Path $PSScriptRoot $File)) $LogName $Marker
}
if (-not $VerifyOnly) {
    Invoke-ActorLua 'prototype_art_sources.lua' 'aseprite-sources' 'ACTOR GARMENT SOURCES SAVED'
    Invoke-ActorLua 'prototype_art_heads.lua' 'aseprite-heads' 'DISTINCT HEAD SOURCES SAVED'
    Invoke-ActorProcess $GodotExe @('--path',$projectPath,'--script',(Join-Path $PSScriptRoot 'prototype_art_bake.gd'),'--disable-vsync','--max-fps','0','--resolution','192x192') 'bake' 'ACTOR BAKE COMPLETE'
    Invoke-ActorLua 'prototype_art_export.lua' 'aseprite-roundtrip' 'NATIVE ROUNDTRIP PASS male'
}
Invoke-ActorLua 'prototype_art_verify.lua' 'aseprite-pixel-check' 'ASEPRITE PIXEL CHECK PASS'
Invoke-ActorProcess $GodotExe @('--path',$projectPath,'--headless','--script',(Join-Path $PSScriptRoot 'prototype_art_gait_verify.gd')) 'gait-validation' 'GAIT VALIDATION PASS'
$sourceResults = @()
foreach ($manifestRelative in @('asset-library/characters/human-female-base/1.0.0/manifest.sha256.json','asset-library/characters/human-male-base/0.1.0/manifest.sha256.json')) {
    $manifestPath = Join-Path $actorRoot $manifestRelative
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    foreach ($entry in $manifest.files.psobject.Properties) {
        $filePath = Join-Path (Split-Path $manifestPath -Parent) $entry.Name
        $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
        $sourceResults += [pscustomobject]@{path=[IO.Path]::GetRelativePath($actorRoot,$filePath);passed=($actualHash -eq $entry.Value)}
    }
}
$sourceResults | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $reportPath 'approved-source-integrity.json') -Encoding utf8
if (@($sourceResults | Where-Object { -not $_.passed }).Count -gt 0) { throw 'Approved asset integrity check failed.' }
Invoke-ActorProcess $GodotExe @('--path',$projectPath,'--headless','--editor','--import','--quit') 'actor-import' ''
Invoke-ActorProcess $GodotExe @('--path',$projectPath,'res://prototype/actors/actor_preview.tscn','--','--verify-actors') 'actor-runtime' 'ACTOR_ACCEPTANCE PASS'
$report = Get-Content -Raw -LiteralPath (Join-Path $reportPath 'actor-runtime-report.json') | ConvertFrom-Json
if (-not $report.passed) { throw 'Actor runtime verification failed.' }
Write-Output ("Verified {0} checks, {1} approved source hashes, 32 actors mean {2:N3} ms / p95 {3:N3} ms." -f $report.checks.Count,$sourceResults.Count,$report.performance.frame_interval_ms.mean,$report.performance.frame_interval_ms.p95)
