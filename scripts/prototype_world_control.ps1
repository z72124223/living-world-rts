[CmdletBinding()]
param(
    [ValidateSet('Build','Start','Status','Stop')][string]$Action = 'Status',
    [ValidateRange(1,65535)][int]$Port = 8793,
    [string]$SaveDirectory = (Join-Path $env:LOCALAPPDATA 'FourPersonPrototype/saves'),
    [string]$RuntimeDirectory = (Join-Path $env:LOCALAPPDATA 'FourPersonPrototype/runtime'),
    [string]$Executable,
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $Executable) { $Executable = Join-Path $projectRoot 'target/debug/world-prototype.exe' }
$Executable = [IO.Path]::GetFullPath($Executable)
$RuntimeDirectory = [IO.Path]::GetFullPath($RuntimeDirectory)
$SaveDirectory = [IO.Path]::GetFullPath($SaveDirectory)
$recordPath = Join-Path $RuntimeDirectory "world-$Port.json"
$baseUrl = "http://127.0.0.1:$Port"

function Read-ManagedProcess {
    if (-not (Test-Path -LiteralPath $recordPath)) { return $null }
    $record = Get-Content -Raw -LiteralPath $recordPath | ConvertFrom-Json
    $process = Get-Process -Id $record.process_id -ErrorAction SilentlyContinue
    if (-not $process) { return $null }
    if ($record.executable -ne $Executable -or $process.Path -ne $Executable -or
        $process.StartTime.ToUniversalTime().Ticks.ToString() -ne $record.started_utc_ticks -or
        $record.base_url -ne $baseUrl) { throw 'PID 記錄與程序不符，拒絕接管或停止其他程序。' }
    return @{ Record = $record; Process = $process }
}

if ($Action -eq 'Build' -or ($Action -eq 'Start' -and -not $SkipBuild)) {
    Push-Location $projectRoot
    try {
        # Use the installed working toolchain, without altering the global rustup default.
        & cargo +1.97.1 build --package world-prototype
        if ($LASTEXITCODE -ne 0) { throw 'Rust 世界核心編譯失敗。' }
    } finally { Pop-Location }
    if ($Action -eq 'Build') { Write-Output "WORLD_BUILD_PASS $Executable"; return }
}

$managed = Read-ManagedProcess
if ($Action -eq 'Status') {
    if (-not $managed) { Write-Output 'WORLD_STOPPED'; return }
    $snapshot = Invoke-RestMethod -Uri "$baseUrl/snapshot" -TimeoutSec 3
    Write-Output ("WORLD_RUNNING pid={0} url={1} characters={2} revision={3}" -f $managed.Process.Id,$baseUrl,$snapshot.characters.Count,$snapshot.revision)
    return
}
if ($Action -eq 'Stop') {
    if (-not $managed) { Write-Output 'WORLD_STOPPED'; return }
    $shutdownName = [string]$managed.Record.shutdown_name
    if ($shutdownName -notmatch '^shutdown-[a-f0-9]{32}\.signal$') { throw '停止訊號名稱不合法。' }
    $shutdownPath = [IO.Path]::GetFullPath((Join-Path $RuntimeDirectory $shutdownName))
    if ([IO.Path]::GetDirectoryName($shutdownPath) -ne $RuntimeDirectory.TrimEnd('\','/')) { throw '停止訊號超出執行資料夾。' }
    [IO.File]::WriteAllText($shutdownPath, 'stop')
    if (-not $managed.Process.WaitForExit(10000)) { throw '世界核心未在期限內完成存檔關閉；未強制終止。' }
    if ($null -ne $managed.Process.ExitCode -and $managed.Process.ExitCode -ne 0) { throw '世界核心關閉失敗，請檢查 stderr 記錄；保留程序與訊號記錄供診斷。' }
    Remove-Item -LiteralPath $shutdownPath -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $recordPath
    Write-Output "WORLD_STOP_PASS pid=$($managed.Process.Id) current.json flushed"
    return
}
if ($managed) { Write-Output "WORLD_ALREADY_RUNNING pid=$($managed.Process.Id) url=$baseUrl"; return }
if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) { throw "找不到世界執行檔：$Executable" }
if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) { throw "連接埠 $Port 已被占用，未更動既有服務。" }
[IO.Directory]::CreateDirectory($RuntimeDirectory) | Out-Null
$shutdownName = "shutdown-$([Guid]::NewGuid().ToString('N')).signal"
$shutdownPath = Join-Path $RuntimeDirectory $shutdownName
$stdoutPath = Join-Path $RuntimeDirectory "world-$Port.stdout.log"
$stderrPath = Join-Path $RuntimeDirectory "world-$Port.stderr.log"
$arguments = @('--port', "$Port", '--save-dir', ('"{0}"' -f $SaveDirectory), '--shutdown-file', ('"{0}"' -f $shutdownPath))
$process = Start-Process -FilePath $Executable -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
$record = @{ process_id = $process.Id; executable = $Executable; started_utc_ticks = $process.StartTime.ToUniversalTime().Ticks.ToString(); base_url = $baseUrl; save_directory = $SaveDirectory; shutdown_name = $shutdownName }
$record | ConvertTo-Json | Set-Content -LiteralPath $recordPath -Encoding utf8
$ready = $false
for ($attempt = 0; $attempt -lt 40; $attempt++) {
    $process.Refresh()
    if ($process.HasExited) { throw "世界核心啟動失敗。請讀取 $stderrPath" }
    try {
        $snapshot = Invoke-RestMethod -Uri "$baseUrl/snapshot" -TimeoutSec 1
        $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
        if ($snapshot.schema_version -eq 1 -and $listener.OwningProcess -contains $process.Id -and $listener.LocalAddress -notcontains '0.0.0.0') { $ready = $true; break }
    } catch { Start-Sleep -Milliseconds 100 }
}
if (-not $ready) { throw "世界核心尚未回應，程序紀錄留在 $recordPath。" }
Write-Output "WORLD_START_PASS pid=$($process.Id) url=$baseUrl saves=$SaveDirectory"
