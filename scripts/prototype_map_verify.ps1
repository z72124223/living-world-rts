param([switch]$HeadlessOnly)
$ErrorActionPreference = 'Stop'
$prototypeRoot = Split-Path -Parent $PSScriptRoot
$prototypeProject = Join-Path $prototypeRoot 'godot-client'
$prototypeReports = Join-Path $prototypeRoot 'prototype/reports/client'
$prototypeGodot = (Get-Command 'Godot_v4.6.3-stable_win64_console.exe' -ErrorAction Stop).Source
New-Item -ItemType Directory -Force -Path $prototypeReports | Out-Null
# Import only this isolated project. The sample project settings are not edited.
& $prototypeGodot --headless --path $prototypeProject --editor --import --quit *> (Join-Path $prototypeReports 'import.log')
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
& $prototypeGodot --headless --resolution 1280x800 --path $prototypeProject --script res://prototype/client/verify_client.gd -- --demo *> (Join-Path $prototypeReports 'headless.log')
if ($LASTEXITCODE -ne 0) { throw 'Headless client verification failed. Read prototype/reports/client/headless.log.' }
if (-not $HeadlessOnly) {
    $prototypeArgs = @('--path', ('"' + $prototypeProject + '"'), '--resolution', '1280x800', '--rendering-method', 'gl_compatibility', '--script', 'res://prototype/client/verify_client.gd', '--', '--demo')
    $prototypeProcess = Start-Process -FilePath $prototypeGodot -ArgumentList $prototypeArgs -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput (Join-Path $prototypeReports 'rendered-stdout.log') -RedirectStandardError (Join-Path $prototypeReports 'rendered-stderr.log')
    if ($prototypeProcess.ExitCode -ne 0) { throw 'Rendered client verification failed.' }
}
$prototypeLogs = @('headless.log', 'import.log')
if (-not $HeadlessOnly) { $prototypeLogs += 'rendered-stderr.log' }
foreach ($prototypeLog in $prototypeLogs) {
    if (Select-String -LiteralPath (Join-Path $prototypeReports $prototypeLog) -Pattern 'SCRIPT ERROR:|ERROR:|CHECK FAILED:' -Quiet) { throw "Godot reported errors in $prototypeLog" }
}
Get-Content -LiteralPath (Join-Path $prototypeReports 'verification-headless.json')
if (-not $HeadlessOnly) { Get-Content -LiteralPath (Join-Path $prototypeReports 'verification-rendered.json') }
