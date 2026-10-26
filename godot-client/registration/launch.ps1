param([switch]$VerifyLaunch, [switch]$Demo)
$ErrorActionPreference = 'Stop'
$taskMutex = [Threading.Mutex]::new($false, 'Local\YiyuRegistrationGame')
$taskOwnsMutex = $false
$taskService = $null
try {
    $taskOwnsMutex = $taskMutex.WaitOne(0)
    if (-not $taskOwnsMutex) { throw '異域已在執行中，請切換到原視窗。' }
    $taskData = Join-Path $env:LOCALAPPDATA $(if ($Demo) { 'Yiyu/demo-logs' } else { 'Yiyu/registration' })
    New-Item -ItemType Directory -Force -Path $taskData | Out-Null
    $taskNode = Join-Path $PSScriptRoot 'runtime/node.exe'
    $taskExecutable = Join-Path $PSScriptRoot '異域.exe'
    $taskServiceFile = Join-Path $PSScriptRoot $(if ($Demo) { 'service/demo.mjs' } else { 'service/server.mjs' })
    $taskServiceName = if ($Demo) { 'yiyu-registration-demo' } else { 'yiyu-registration' }
    $taskPort = if ($Demo) { 8788 } else { 8787 }
    $taskHealthUrl = 'http://127.0.0.1:' + $taskPort + '/health'
    $taskGameArguments = @()
    if ($Demo) { $taskGameArguments = @('--', '--registration-demo') }
    foreach ($taskRequired in @($taskNode, $taskExecutable, $taskServiceFile)) {
        if (-not (Test-Path -LiteralPath $taskRequired)) { throw '遊戲檔案不完整，請保留整個資料夾。' }
    }
    $taskHealth = $null
    try { $taskHealth = Invoke-RestMethod $taskHealthUrl -TimeoutSec 2 } catch {}
    if ($null -ne $taskHealth -and ($taskHealth.service -ne $taskServiceName -or ($Demo -and $taskHealth.mode -ne 'demo') -or (-not $Demo -and $taskHealth.mode -eq 'demo'))) { throw '帳號服務模式不符或埠已被其他程式占用。' }
    if ($Demo -and $null -ne $taskHealth) { throw '測試服務已在使用中，請先關閉原測試窗口後重試。' }
    if ($null -eq $taskHealth) {
        $taskService = Start-Process -FilePath $taskNode -ArgumentList @('"' + $taskServiceFile + '"') -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskData 'service-output.log') -RedirectStandardError (Join-Path $taskData 'service-error.log')
        $taskDeadline = [DateTime]::UtcNow.AddSeconds(12)
        while ([DateTime]::UtcNow -lt $taskDeadline) {
            if ($taskService.HasExited) { throw '帳號服務啟動失敗，請檢查本機帳號服務紀錄。' }
            try {
                $taskHealth = Invoke-RestMethod $taskHealthUrl -TimeoutSec 1
                if ($taskHealth.service -eq $taskServiceName -and (-not $Demo -or $taskHealth.mode -eq 'demo')) { break }
            } catch {}
            Start-Sleep -Milliseconds 150
        }
        if ($null -eq $taskHealth -or $taskHealth.service -ne $taskServiceName -or ($Demo -and $taskHealth.mode -ne 'demo')) { throw '帳號服務啟動逾時或模式不符。' }
    }
    if ($VerifyLaunch) {
        $taskStarted = Get-Date
        $taskVerifyArguments = @('--quit-after', '120', '--log-file', ('"' + (Join-Path $taskData 'launch-verification.log') + '"')) + $taskGameArguments
        $taskGame = Start-Process -FilePath $taskExecutable -ArgumentList $taskVerifyArguments -WorkingDirectory $PSScriptRoot -Wait -PassThru
        if ($taskGame.ExitCode -ne 0) { throw '原生遊戲啟動驗收失敗。' }
        if (Select-String -LiteralPath (Join-Path $taskData 'launch-verification.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet) { throw '原生遊戲紀錄包含載入錯誤。' }
        if ((Get-Item -LiteralPath (Join-Path $taskData 'launch-verification.log')).LastWriteTime -lt $taskStarted) { throw '沒有取得本次啟動紀錄。' }
        Write-Output ('YIYU_BUNDLE_LAUNCH_VERIFIED ' + $taskHealth.service)
    } else {
        if ($Demo) {
            Start-Process -FilePath $taskExecutable -ArgumentList $taskGameArguments -WorkingDirectory $PSScriptRoot -Wait
        } else {
            Start-Process -FilePath $taskExecutable -WorkingDirectory $PSScriptRoot -Wait
        }
    }
} catch {
    if ($VerifyLaunch) { throw }
    else {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show($_.Exception.Message, '異域') | Out-Null
    }
} finally {
    if ($null -ne $taskService -and -not $taskService.HasExited) { Stop-Process -Id $taskService.Id -ErrorAction SilentlyContinue }
    if ($taskOwnsMutex) { $taskMutex.ReleaseMutex() }
    $taskMutex.Dispose()
}
