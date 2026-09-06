# 營地地圖與小隊操作交付

本工作樹：`C:/Users/f7212/.codex/worktrees/9bbf/遊戲開發`  
分支：`codex/prototype-client-20260906`  
共用起點：`5fecdf9c50ec1cc67ff6b77be8ba8c8cf8913d82`  
操作檢查點：`7e305b0653661680a426c2a01fe12402f22f2cab`

## 執行與接入

```powershell
godot --path godot-client res://prototype/client/prototype.tscn -- --demo
godot --path godot-client res://prototype/client/prototype.tscn -- --world
./scripts/prototype_map_verify.ps1
```

入口為 `res://prototype/client/prototype.tscn`。`--demo` 明確使用記憶體演示，介面標示「開發演示 · 暫存資料」，正式存讀檔按鈕停用。`--world` 必須有 `res://prototype/bridge/world_bridge.gd`，缺少時顯示「本機世界尚未連線」，不回退演示。未帶旗標時，有橋接即使用橋接；本分工未接入橋接的獨立工作樹會標示演示。

正式路徑動態建立約定橋接、連接 `snapshot_received` / `command_failed`，只呼叫 `connect_world("http://127.0.0.1:8793")`、`request_snapshot()`、`send_command(...)`。UI 不另存正式隊伍或存檔。位置直接取自快照，不由客戶端推進，也不插值穿越障礙；路線為帶唯一 request_id 的標準 move/routes/pace 指令。分隊、合流、裝備、互動、slot-1 存讀檔均送約定指令。

有 `res://prototype/actors/character_actor.gd` 時自動使用，呼叫 configure/set_motion/set_equipment/set_selected，足點由快照設定。缺少時使用 `temporary_actor.gd` 顯示已確認透明男女 PNG，約 64 世界像素；這個轉接器没有新增動畫，裝備只有狀態標記。正式 actor 的衣裝／動畫需由角色任務接入驗收。

協調窗口可依序 cherry-pick 本分支提交，再設定主場景與匯出。沒有改 `project.godot` 或 `export_presets.cfg`。正式匯出需將 `prototype/map/*.json` 列入非資源 include_filter，因 `map_config.json` 以 FileAccess 讀取；最終打包由協調窗口負責。沒有啟動新預覽服務，既有 8780 保留。

## 已實作

- 2048×1536、32 格、固定斜俯視，縮放 0.5–2 倍，方向鍵／中鍵平移，小地圖定位。
- 左鍵點選、拖曳框選、Shift 增選／移除，1–4 單選、Tab 全選、隊伍選單＋「選隊」。
- 右鍵下令；32 步行／56 跑步；牆、樹幹、岩石、帳篷、物資箱與水域使用同一導航阻擋資料。
- A* 格包含 12 像素角色淨空，斜向不得切角；路線簡化使用精確線段／矩形相交。停止後可從中途位置重新接到可見格中心。
- 目的地保留不同站位，避免人物到站疊在同一點；不對人物加互相等待的物理推擠鎖。行進間允許人物暫時交錯，不是完整時間預約式多人避讓。
- 停止、集合、分隊／合流；合流前用人物卡選來源成員、下拉選目標，再按「合流」。隊長 null 顯示「未指定」。
- 兩個探路點與返回營地。全體選取成員進入 64 像素後才送互動，過程不預先揭露事件文字。
- 地圖配置在 `godot-client/prototype/map/map_config.json`，包含已協調起點和三個事件點。導航障礙與道路在 camp_map.gd，來源美術另存 Aseprite。

## 證據與限制

`verification-headless.json` 與 `verification-rendered.json` 為同一可玩場景的真實 Godot 4.6.3 執行；腳本派送 Godot InputEvent 走實際輸入流程，並用固定步長加速演示時間。渲染使用 Windows OpenGL / NVIDIA GTX 1080 Ti，截圖直接由實際 Viewport 取得。不是人工逐鍵遊玩的時長紀錄，也不是 Rust 核心驗收。

檢查包含：四人、滑鼠／鍵盤選取、鏡頭、實牆繞行、唯一站位、停止、個人移動、裝備、分合流身分保留、探路到達、重複／遠距互動拒絕、返回、mock 禁止正式存檔、隊長空值、120 條固定亂數跨區路徑與途中重算、1280×800 介面範圍，以及新樹冠的選取人物遮擋。移動位置採樣 22,080 次；實際結果以 JSON failed 與逐項 passed 為準。

截圖：`01-camp-selected.png`、`02-wall-detour.png`、`03-north-observed.png`、`04-return-camp.png`、`05-canopy-visibility.png`。精修後覆寫為最新本機渲染；操作檢查點的舊圖仍可由 Git 取回。

尚待整合驗收：正式 Rust 連線、真實時間橋接移動、正式存讀檔／損壞存檔由世界任務驗證；正式角色衣装動畫；最終 Windows 匯出；新增場景美術的使用者確認。這些不宣稱完成。場景使用像素素材搭配 y-sort（依足點排序），選取角色被樹冠遮住時樹冠淡化。

LATTICE：已呼叫 lattice_runtime_status，收到 receipt-only / NOT_STARTED；control_snapshot 空參數被拒絕為 Invalid product snapshot arguments，沒有取得可驗證的本任務身分，未捏造 task ID。
