[CmdletBinding()]
param([switch]$SkipCargoTests, [int]$Port = 8793)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$runDirectory = Join-Path $projectRoot ('prototype/reports/world/run-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))
[IO.Directory]::CreateDirectory($runDirectory) | Out-Null
$control = Join-Path $PSScriptRoot 'prototype_world_control.ps1'
$settings = @{Port = $Port; SaveDirectory = (Join-Path $runDirectory 'saves'); RuntimeDirectory = (Join-Path $runDirectory 'runtime')}
Push-Location $projectRoot
try {
    if (-not $SkipCargoTests) {
        & cargo +1.97.1 test --workspace -- --nocapture 2>&1 | Tee-Object -FilePath (Join-Path $runDirectory 'cargo-test.log')
        if ($LASTEXITCODE -ne 0) { throw 'cargo test 未通過。' }
    }
    & $control -Action Start @settings
    try {
        & $control -Action Status @settings
        & godot --headless --path (Join-Path $projectRoot 'godot-client') --script res://prototype/bridge/bridge_smoke.gd -- "--url=http://127.0.0.1:$Port" 2>&1 | Tee-Object -FilePath (Join-Path $runDirectory 'godot-bridge.log')
        if ($LASTEXITCODE -ne 0) { throw 'Godot 橋接實測未通過。' }
    } finally { & $control -Action Stop @settings }
    & $control -Action Start -SkipBuild @settings
    try {
        $snapshot = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/snapshot" -TimeoutSec 3
        if ($snapshot.characters.Count -ne 4 -or $snapshot.characters[0].loadout.weapon -ne 'sword') { throw '重啟讀回世界內容不符。' }
        Write-Output 'LIFECYCLE_RESTART_PASS characters=4 equipment=sword'
    } finally { & $control -Action Stop @settings }
    Write-Output "WORLD_VERIFY_PASS evidence=$runDirectory"
} finally { Pop-Location }
