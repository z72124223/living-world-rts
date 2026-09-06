# 人物隊伍與存檔核心：接入與驗證

本分工可接入真正地圖客戶端。尚未整合地圖、角色美術或最終 Windows 套件，橋接測試不是整款遊戲驗收。

## 執行入口

在整合後專案根目錄執行：

```powershell
./scripts/prototype_world_control.ps1 -Action Start
./scripts/prototype_world_control.ps1 -Action Status
./scripts/prototype_world_control.ps1 -Action Stop
```

啟動預設會用本機已安裝可用的 `cargo +1.97.1 build --package world-prototype`；沒有改全域 rustup 預設。已打包時可傳 `-Executable <絕對exe路徑> -SkipBuild`。程序以 Hidden 啟動；Stop 透過只供本機啟動器使用的訊號檔要求保存並結束，核對 PID、啟動時間、執行檔與連接埠，不強制終止其他程序。未修改既有 8780 服務。

- 世界網址固定主機 `http://127.0.0.1:8793`。CLI 可用 `--port N`，沒有 `--host` 或任何非 loopback 綁定選項。
- 預設存檔：`%LOCALAPPDATA%/FourPersonPrototype/saves`；可由可信本機啟動器指定 `--save-dir`。
- 自動載入 `current.json`。每個成功命令回應前，以及每個有移動的 100ms 模擬步，原子保存世界。關閉時再保存一次。重啟繼續保存的路線，不計算程序關閉期間的離線時間。
- `save/load` 的 slot 僅接受 `slot-1` 到 `slot-9`，不接受路徑。`slot-1` 符合共用介面。
- `world.lock` 是 OS 檔案鎖，同一存檔目錄只允許一個寫入程序；正常／異常結束都會釋放鎖。
- 損壞 slot 回傳 422，現有世界不變；損壞 `current.json` 啟動失敗並保留檔案，不重置或覆蓋。需要人工確認使用哪份備份後再恢復。
- 格式版本為 1，寫入經同目錄暫存檔、`sync_all`、原子替換。一般程序中斷可回到最後完成的步進；硬碟／電源故障層級的耐久性未做實機斷電驗證。

## Godot 接入

```gdscript
const WorldBridge = preload("res://prototype/bridge/world_bridge.gd")
var world_bridge = WorldBridge.new()
add_child(world_bridge)
world_bridge.snapshot_received.connect(_on_snapshot)
world_bridge.command_failed.connect(_on_command_failed)
world_bridge.connect_world("http://127.0.0.1:8793")
world_bridge.send_command({
    "type": "move",
    "routes": [{"character_id": "1", "points": [[336, 816], [336, 848]]}],
    "pace": "walk"
})
```

公開方法與訊號完全依 `SESSION_BRIEF.md`。橋接自動補上缺少的 request_id、每 0.2 秒輪詢，使用 HTTPRequest 背景執行與命令／快照序列化，避免舊 GET 蓋掉命令結果。客戶端只呈現真實 snapshot；未新增 mock、正式存檔或第二套隊伍邏輯。送出失敗不自動重播，錯誤訊號含 request_id，結果不確定時可用同一 ID 重試。

HTTP：GET `/snapshot` 直接回 snapshot；POST `/command` 回 `{ok:true,snapshot}`，失敗回 `{ok:false,error}`。未知命令／人物／非法路線使用 400，重複 ID 搭配不同內容用 409，slot 不存在用 404，損壞存檔用 422，磁碟錯誤用 500。限制 request body 64 KiB、headers 8 KiB、8 個連線 worker、有限讀取時間；拒絕不相符 Host、跨來源、重複標頭、chunked 與超大內容。未提供 CORS。

相同 request_id 與相同命令再次送出只回目前快照，不再次執行；此收據隨世界保存、重啟與讀 slot 保留。slot load 是使用者要求的舊存檔回復，人物／裝備／位置／歷史回到該存檔，但 ID 分配器保留已使用的最高水位，避免重用已消耗 ID。快照 revision 在 load 後繼續遞增，sim_time_ms 可回復到存檔時間。

## 資料與原型行為

- 真實人物沿用 `world-core::character::Character`，原有七個測試與生死／指揮資格行為保留。HTTP 所有 ID 是字串。
- 起點依序 `[304,816]`、`[352,816]`、`[304,864]`、`[352,864]`；四名男女混合，第一小隊，預設 cloth/none/none。
- 世界預設 2048×1536，位置有限且位於 `[0,width) × [0,height)`；每條路線 1..512 點、總長 ≤32768 像素，人物選取不可重複。步行 32、跑步 56 像素／模擬秒。障礙路徑由客戶端計算，核心不驗地圖障礙。
- `scout-north=[1040,304]`、`scout-east=[1712,848]`、`return-camp=[336,848]`，半徑64。人物確實在範圍內才可互動；每人每個探路點只新增一次觀察事件。只有尚未回報的觀察才會新增返回事件；重複事件不複製歷史。
- split 的新小隊按選取順序指定第一名可指揮人物為初始隊長。既有隊長離隊或資格無效時，保留 `nominal_commander_id`，`commander_id=null`；不自動訂立代理或交還指揮權政策。UI 顯示「未指定」。
- split/merge 只改人物引用與組織，不複製 `Character`。HTTP merge 是平面小隊合流；含上下級結構時拒絕合流，需由核心 API 明確拆開。額外 snapshot 欄位為 nominal_commander_id、parent_squad_id、child_squad_ids，以及事件 character_id/event_key。
- Rust API 有 `add_character`、`join_squad`、`leave_squad`、`attach_squad`、`detach_squad`、`assign_commander`、`effective_commander`、`configure`。建立人物、階層隊伍與改配置未擴張 HTTP 命令。`Engine::update_world` 可將這類核心操作原子保存。
- 人物上限256、事件10000、成功命令收據4096、存檔8MiB；達限制即明確拒絕，不裁切人物或歷史。這些是有界原型限制，非最終容量。

## 已執行與待整合

完整驗證入口：`./scripts/prototype_world_verify.ps1`，使用隔離存檔、真正 Windows 二進位、Godot 4.6.3 與8793，結束後保存並關閉側程序。`-Port` 可改測試連接埠；未使用8791、8792或8780。

已通過：`cargo +1.97.1 test --workspace` 共25項（16核心，5存檔，4實際HTTP程序）；`cargo +1.97.1 clippy --workspace --all-targets -- -D warnings`；Godot headless bridge_smoke；啟動／狀態／保存關閉／重啟裝備读回。實際 HTTP 探路測試花約33秒走到北側並返回，沒有用加速 HTTP 命令替代。新增人物的重啟測試使用 Rust-only API，HTTP 合約沒有偷偷加入 spawn。

Godot 首輪測試找到 Windows listener 的非阻塞模式會被 accepted socket 繼承；worker 明確切回有逾時的阻塞讀取後已修正，並新增「客戶端延後傳送 bytes」的實際 HTTP 回歸測試。Godot 測試中的 JSON 浮點零比較也已修正。

待協調窗口：讀取本分支提交、切入真正地圖／角色、以視窗操作驗收尋路與 UI、設定最終主場景並完成一鍵打包。沒有執行這些跨分工工作，沒有 push、改 main 或修改 shared contract。

LATTICE runtime 有回應（receipt-only / NOT_STARTED）；任務快照查詢被拒（Invalid product snapshot arguments），沒有取得本分工 LATTICE task identity。本次結果以本機提交與工具實測回報，不宣稱已更新 LATTICE durable task。
