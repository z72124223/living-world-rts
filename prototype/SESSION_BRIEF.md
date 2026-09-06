# 四人小隊原型：本次跨任務共用介面

來源：使用者於 2026-09-06 同意製作 Windows 小隊原型，並要求開啟多個 Codex 任務分工，完成後回報原窗口。
協調窗口：`01a0712a-0d37-7dc2-bd31-b227142e5f76`（`查找 GitHub 專案`）。

## 已確認範圍

- Godot 4.6.3 + Aseprite 2D 像素；既有 Rust 人物核心繼續使用。Blender 不用於本輪。
- 男女人體曲線、網格與骨架均獲使用者通過。來源為 `asset-library/catalog.json` 及各版本 `asset.json` 的 approval；原始 mesh JSON 內的草稿描述是生成時的歷史註記。
- 保留已確認底稿，衣服、胸甲與武器另製分件。新衣裝與動畫仍需美術驗收。
- 本輪交付：小營地、四名真實人物資料、移動與繞障、選取、分隊／集合／合流、探路事件與存讀檔，最後由協調窗口整合成 Windows 可玩版本。
- 不做傳統 HP、肢體受傷減益、完整戰鬥、多人伺服器或付費／公開發佈。傷害替代規則尚未確認。
- 舊文件提到 Blender 或引擎未定之處，由上述較新的使用者決定取代；其餘人物身分、資訊與歷史原則仍依遊戲憲法。

## 檔案負責範圍

| 任務 | 可寫入範圍 |
|---|---|
| 角色衣裝與動畫 | `godot-client/prototype/actors/`、`pixel-assets/prototype-actors/`、`scripts/prototype_art_*` |
| 營地地圖與小隊操作 | `godot-client/prototype/client/`、`godot-client/prototype/map/`、`pixel-assets/prototype-map/`、`scripts/prototype_map_*` |
| 人物隊伍與存檔核心 | `crates/`、根 `Cargo.toml`／`Cargo.lock`、`godot-client/prototype/bridge/`、`scripts/prototype_world_*` |

各任務另可寫自己的 `prototype/reports/<actors|client|world>/`。不要修改共用 `project.godot`、`export_presets.cfg`、已收錄的 `asset-library/`、既有角色底稿、其他任務資料夾或此介面檔。必要介面變更回報協調窗口，由協調窗口統一修改。協調窗口負責最終主場景、打包、素材庫新版本與跨模組整合。

## 畫面與角色介面

- 先用固定 2D 斜俯視構圖，不旋轉相機。世界座標為像素，X 向右、Y 向下；地圖 2048 × 1536，基本格 32；角色足點為位置原點，默认遊戲比例的人體可見高度約 64 像素。這些是原型可調參數，不是最終容量承諾。
- 角色入口：`res://prototype/actors/character_actor.gd`，extends Node2D。
- 公開方法：`configure(data: Dictionary)`、`set_motion(velocity: Vector2)`、`set_equipment(loadout: Dictionary)`、`set_selected(selected: bool)`。腳點位於局部 (0,0)，全域 position 由客戶端管理；actor 不處理選取、尋路或世界存檔。
- `data` 至少有 id、name、gender（male/female）、loadout。loadout 三欄：clothing（cloth）、armor（none/chest）、weapon（none/sword）。
- 地圖任務在角色任務完成前，可用已確認的透明人物 PNG 作明確的暫時顯示；不能把這種顯示宣稱為新衣裝／動畫已完成。完成後以相同介面換入 actor。

## 世界資料與操作介面

世界核心是人物、隊伍、位置與事件的資料來源。客戶端負責輸入、可行走路徑計算與呈現，不維護另一套正式隊伍／存檔規則。

Godot 橋接入口：`res://prototype/bridge/world_bridge.gd`，extends Node。
訊號：`snapshot_received(snapshot: Dictionary)`、`command_failed(message: String)`。
方法：`connect_world(base_url: String)`、`send_command(command: Dictionary)`、`request_snapshot()`。
本機原型可用僅綁定 `127.0.0.1:8793` 的 HTTP 側程序；GET `/snapshot`、POST `/command`。這不是最終多人架構。

Snapshot 最少欄位：

```json
{"schema_version":1,"revision":1,"sim_time_ms":0,"characters":[{"id":"1","name":"人物甲","gender":"female","position":[256,256],"velocity":[0,0],"loadout":{"clothing":"cloth","armor":"none","weapon":"none"},"squad_id":"squad-1"}],"squads":[{"id":"squad-1","name":"第一小隊","member_ids":["1"],"commander_id":"1"}],"events":[{"id":"event-1","sim_time_ms":0,"text":"隊伍在營地集合。"}]}
```

- 所有 ID 以字串傳輸，分隊／合流／存讀檔不得複製或重置人物 ID。
- 每個 command 有唯一 `request_id` 與 `type`。HTTP 回應為 `{ok:true,snapshot:{...}}` 或 `{ok:false,error:"..."}`，錯誤亦使用適當狀態碼。
- `move`：`routes:[{character_id,points:[[x,y],...]}]`、`pace:walk|run`。Godot 算繞障路線，Rust 依時間推進位置；起步建議步行 32、跑步 56 像素/秒，可調整。
- `stop`：`character_ids:[...]`。
- `split`：`character_ids:[...]`、`name`，產生新隊伍。
- `merge`：`source_squad_id`、`target_squad_id`。
- `set_equipment`：`character_id`、`loadout`。
- `interact`：`character_id`、`event_key`（原型可用 scout-north、scout-east、return-camp）；保留事件與重複觸發規則，沒有戰鬥數值。
- `save`／`load`：`slot:slot-1`。讀回後人物、隊伍、裝備、位置與事件一致；需要有損壞存檔及原子寫入處理。
- 初始化示例世界包含四名男女混合人物與一支小隊。探路事件只揭露已觀察資訊，不顯示完整隱藏世界。
- 地圖客戶端可在獨立演示模式用符合介面的 mock，但正式整合必須切換至 Rust 橋接；不得宣稱 mock 已接上核心。

## 執行、驗證與回報

- 每個任務只在自己的 Codex 工作樹工作，完成後提交本機 `codex/` 分支，回報 SHA 與改動檔案。不要 push、修改 main、刪除／重置其他工作區，或直接把檔案寫回原專案。
- 先完成有證據的實作，不只交規劃。角色與地圖須有 Godot 實際執行畫面；核心须有唯一 ID、分合流、移動、存讀檔與錯誤情境的實質測試。
- 完成或遇到真正阻塞時，呼叫 `send_message_to_thread` 回報協調窗口。回報內容：角色分工、工作樹、分支、SHA、實際成果入口、已跑測試、未完成事項及整合方式。回報是內部協作，不需再問使用者。
- 不自行新增更多 Codex 任務，不自行封存。瀏覽器只用 Codex 內建；角色／地圖如需預覽服務分別用 8791／8792，保留現有 8780 服務。
- 本機 Godot 在 PATH；Aseprite：`C:/Users/f7212/AppData/Local/Programs/Aseprite-build/build/bin/aseprite.exe`。Aseprite 批次模式需等待程序完成；Windows 背景 helper 用 Hidden。需要影像生成時使用 imagegen 技能；人體底稿不可隨意重畫。
