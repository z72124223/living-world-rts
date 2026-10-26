param([switch]$SkipExecutableSmoke)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskBundle = Join-Path $taskRoot 'playable/yiyu-registration-20260906'
New-Item -ItemType Directory -Force -Path $taskBundle, (Join-Path $taskBundle 'service'), (Join-Path $taskBundle 'runtime') | Out-Null
& godot --headless --path (Join-Path $taskRoot 'godot-client') --export-release 'Yiyu Windows' (Join-Path $taskBundle '異域.exe')
if ($LASTEXITCODE -ne 0) { throw 'Godot 匯出失敗。' }
if ($SkipExecutableSmoke) {
    Write-Output 'NOT RUN: 此次只打包，不啟動遊戲執行檔。'
} else {
    $taskSmokeLog = Join-Path $taskBundle 'export-smoke.log'
    $taskSmokeStarted = Get-Date
    $taskSmoke = Start-Process -FilePath (Join-Path $taskBundle '異域.exe') -ArgumentList @('--headless','--quit-after','2','--log-file',('"' + $taskSmokeLog + '"')) -WindowStyle Hidden -Wait -PassThru
    if ($taskSmoke.ExitCode -ne 0 -or (Get-Item -LiteralPath $taskSmokeLog).LastWriteTime -lt $taskSmokeStarted -or (Select-String -LiteralPath $taskSmokeLog -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw '匯出執行檔素材或腳本驗收失敗。' }
}
$taskFiles = @('server.mjs','core.mjs','providers.mjs','vault.mjs','demo.mjs','configure-persona.mjs','moderate.mjs','設定實名服務.ps1')
foreach ($taskFile in $taskFiles) {
    Copy-Item -LiteralPath (Join-Path $taskRoot "registration-service/$taskFile") -Destination (Join-Path $taskBundle "service/$taskFile")
}
$taskNode = (Get-Command node.exe).Source
if ((& $taskNode --version) -ne 'v24.16.0') { throw '此封裝已驗證的 Node 版本為 v24.16.0，請先驗證版本變更。' }
Copy-Item -LiteralPath $taskNode -Destination (Join-Path $taskBundle 'runtime/node.exe')
$taskNodeLicense = Join-Path $taskRoot 'registration-service/LICENSE-NODE.txt'
if (-not (Test-Path -LiteralPath $taskNodeLicense)) { throw '找不到 Node 授權檔。' }
Copy-Item -LiteralPath $taskNodeLicense -Destination (Join-Path $taskBundle 'runtime/NODE-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $taskRoot 'godot-client/registration/LICENSE-GODOT.txt') -Destination (Join-Path $taskBundle 'GODOT-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $taskRoot 'godot-client/login/assets/OFL.txt') -Destination (Join-Path $taskBundle 'FONT-LICENSE.txt')
$taskUtf8Bom = [System.Text.UTF8Encoding]::new($true)
[IO.File]::WriteAllText((Join-Path $taskBundle 'Start-Yiyu.ps1'), [IO.File]::ReadAllText((Join-Path $taskRoot 'godot-client/registration/launch.ps1')), $taskUtf8Bom)
[IO.File]::WriteAllText((Join-Path $taskBundle 'service/設定實名服務.ps1'), [IO.File]::ReadAllText((Join-Path $taskRoot 'registration-service/設定實名服務.ps1')), $taskUtf8Bom)
# ASCII wrapper supports paths containing Chinese without placing credentials in arguments.
[IO.File]::WriteAllText((Join-Path $taskBundle '啟動異域.cmd'), '@echo off' + "`r`n" + 'powershell.exe -NoProfile -WindowStyle Hidden -File "%~dp0Start-Yiyu.ps1"' + "`r`n", [Text.Encoding]::ASCII)
[IO.File]::WriteAllText((Join-Path $taskBundle '測試創建角色.cmd'), '@echo off' + "`r`n" + 'powershell.exe -NoProfile -WindowStyle Hidden -File "%~dp0Start-Yiyu.ps1" -Demo' + "`r`n", [Text.Encoding]::ASCII)
Copy-Item -LiteralPath (Join-Path $taskRoot 'docs/registration/PLAYABLE.txt') -Destination (Join-Path $taskBundle '閱讀說明.txt')
Write-Output "已建立本機可執行版本：$taskBundle"
