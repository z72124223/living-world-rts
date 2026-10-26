$ErrorActionPreference = 'Stop'
$taskTemplate = Read-Host 'Persona 正式環境 inquiry template ID（itmpl_...）'
$taskSecret = Read-Host 'Persona 正式環境 API 金鑰（隱藏輸入）' -AsSecureString
$taskPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($taskSecret)
try {
    $taskPayload = @{
        templateId = $taskTemplate
        apiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($taskPointer)
        environment = 'production'
    } | ConvertTo-Json -Compress
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $taskNode = Join-Path $PSScriptRoot '../runtime/node.exe'
    if (-not (Test-Path -LiteralPath $taskNode)) { $taskNode = (Get-Command node.exe).Source }
    $taskPayload | & $taskNode (Join-Path $PSScriptRoot 'configure-persona.mjs')
    if ($LASTEXITCODE -ne 0) { throw '設定失敗。' }
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($taskPointer)
    $taskPayload = $null
    $taskSecret.Dispose()
}
