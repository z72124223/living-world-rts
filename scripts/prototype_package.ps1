[CmdletBinding()]
param([switch]$SkipRustBuild)
$ErrorActionPreference = 'Stop'
$prototypeRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$packageDirectory = Join-Path $prototypeRoot 'dist/four-person-prototype'
$prototypeGodot = (Get-Command 'Godot_v4.6.3-stable_win64_console.exe' -ErrorAction Stop).Source
Push-Location $prototypeRoot
try {
    if (-not $SkipRustBuild) {
        & cargo +1.97.1 build --release --package world-prototype
        if ($LASTEXITCODE -ne 0) { throw '世界核心編譯失敗。' }
    }
    New-Item -ItemType Directory -Path $packageDirectory -Force | Out-Null
    & $prototypeGodot --headless --path godot-client --editor --import --quit *> (Join-Path $packageDirectory 'import.log')
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $packageDirectory 'import.log') -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) { throw 'Godot 匯入失敗，請查看 import.log。' }
    & $prototypeGodot --headless --path godot-client --export-release Windows *> (Join-Path $packageDirectory 'export.log')
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $packageDirectory 'export.log') -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) { throw 'Godot 匯出失敗，請查看 export.log。' }
    Copy-Item -LiteralPath (Join-Path $prototypeRoot 'target/release/world-prototype.exe') -Destination (Join-Path $packageDirectory 'world-prototype.exe')
    @'
林間營地・四人小隊原型

直接開啟「林間營地.exe」。請將 world-prototype.exe 與遊戲放在同一個資料夾。
不需要安裝 Godot、Aseprite 或 Rust。第一次開啟會建立四人世界。
存檔位置：%LOCALAPPDATA%\FourPersonPrototype\saves
關閉遊戲視窗會保存進度；下次開啟會接續。工具列也可手動存檔／讀檔。

左鍵點選／拖曳框選，Shift 增選，1–4 單選，Tab 全選。
右鍵移動，S 停止，G 集合；滾輪縮放，中鍵／方向鍵移動鏡頭。
用探路按鈕前往北方或東方，再返回營地留下紀錄。
可分隊、合流、換胸甲與佩劍。

這是可玩原型。新衣裝、方向動畫與地圖素材仍待美術確認。
本版本未實作戰鬥與傷害；人物行進時可能交錯，尚無完整群體避讓。
'@ | Set-Content -LiteralPath (Join-Path $packageDirectory '開始遊玩.txt') -Encoding utf8
    Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $packageDirectory '林間營地.exe'),(Join-Path $packageDirectory 'world-prototype.exe') | Select-Object Path,Hash | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $packageDirectory 'build-hashes.json') -Encoding utf8
    Write-Output "PACKAGE_READY $packageDirectory"
} finally { Pop-Location }
