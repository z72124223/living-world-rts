# 四人小隊整合驗證

入口：`godot-client/prototype/launch.tscn`。Windows 套件由 `scripts/prototype_package.ps1` 產生於 `dist/four-person-prototype/`，直接開啟 `林間營地.exe`，Godot 自動啟動同資料夾的 Rust 世界程序。關閉會等待已送出的命令完成，再要求世界原子保存並退出。存檔使用 `%LOCALAPPDATA%/FourPersonPrototype/saves`。

## 本回合已驗證

- `integration.json`：35 項檢查通過，53.4 秒真實時間，1,148 次權威位置採樣未進入障礙。實際 Godot 場景／人物／HTTP 橋接／Rust 程序；測試派送鍵盤事件並操作相同遊戲方法，沒有加速或替換世界資料。
- 流程包含四人、換胸甲與武器、分隊、走牆口、停止、兩組分別往北方及東方、四名隊員各自記錄觀察、返回營地、合流、集合、slot-1 存讀檔恢复人物／隊伍／位置／裝備／歷史。
- `launcher-create.json`、`launcher-restore.json`：已匯出的 Windows 遊戲自動啟動世界、動態地圖素材載入、換裝、保存、正常關閉，再開啟讀回皆通過。兩次測試後遊戲與子程序均已退出，8793 無 listener；8780 原樣保留。
- `01-integrated-camp.png`、`02-integrated-scout.png`、`03-integrated-return.png` 是原生 Godot Viewport 截圖。這一輪使用第一版角色；新版衣甲、動作與快取需後續接入。

整合修正：正式模式缺橋接時不回退 mock；各人物各自保留探路目的地，兩組探路不再互相覆蓋；移動或停止只取消被選人物的探路意圖；到達後逐人保存觀察。紀錄介面顯示觀察者姓名。

早期失敗證據保留於本機 `run-*` 目錄：驗證程式最初誤認 save 會增加世界 revision，已改驗實際回應及 load 恢復；合流測試補上明確選取來源成員的前提。官方 release export 不支援原本使用的 standalone script 方式，套件改以顯式診斷參數執行同一主場景。未將這些失敗標成通過。

## 重跑

測試用 `RTS_VERIFY_OUTPUT` 指定證據資料夾，`RTS_SAVE_DIRECTORY` 指定全新隔離存檔。完成後透過正常 close_requested 流程保存退出。

- `godot --path godot-client -- --verify-integration`：完整真實時間探路流程；先執行 release Rust 編譯。
- `林間營地.exe -- --verify-bundle`：套件冒煙檢查；另設 `RTS_LAUNCH_VERIFY_PHASE=create`，再使用同一存檔以 `restore` 執行。可用 `RTS_EXPECTED_SNAPSHOT` 指向完整流程的 expected-restart.json，核對所有人物／隊伍／觀察紀錄。

## 範圍

新衣裝、方向動畫和場景美術仍待使用者確認；既有男女人體素材仍保持原核准版本。未做戰鬥、傳統 HP、肢體傷勢效果、網路多人或完整人群避讓。此處不代表最終大型 RTS 容量。中途關閉會保留世界路線，但客戶端尚未持久保存到達後互動意圖，重啟後可再次下達探路命令。

成果僅在本機 `codex/prototype-integration-20260906`；沒有 push、合併預設分支或部署，原專案 13 項暫存變更保留。
