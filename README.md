# Living World RTS

即時戰略（RTS）＋角色扮演（RPG）的持續活世界。人物、武將身分、組織、資訊與歷史共同形成玩家的經歷。

## 目前決定（2026-09-06）

- 遊戲客戶端採 **Godot 4**；建模、材質與動畫採 **Blender**；世界規則核心維持 **Rust**。
- 美術以低資源、高效能、高性價比及良好畫面為目標，像素表現列入候選；尚未鎖定純 2D、2.5D 或即時 3D。
- 最新美術回饋：v01 人體／骨架與整體造型不通過；本輪改以 B「像素圖像」為修正基準，先審核人體和像素呈現，再重製衣甲。
- 下一個工作階段優先驗證美術樣品與製作流程，再延續 MP0 的人物、組織與指揮骨架。

## 閱讀入口

| 內容 | 文件 |
|---|---|
| 已確認的世界規則與體驗守則 | [遊戲憲法](docs/GAME_CONSTITUTION.md) |
| 先前想法、差異化與待驗證項目 | [設計想法索引](docs/DESIGN_IDEAS.md) |
| Godot、Blender 與美術製作選型 | [技術決議 TD-002](docs/decisions/TD-002_GODOT_BLENDER_ART_PIPELINE.md) |
| 原創美術概念圖與生成來源 | [美術方向草案 v01](blender-assets/concepts/art-direction-v01.md)（概念參考，非遊戲截圖） |
| 目前的美術修正樣品 | [人體與 B 像素方向 v02](blender-assets/samples/body-pixel-v02/README.md)（待美術審核）；[v01](blender-assets/samples/modular-character-v01/README.md) 已被使用者否決 |
| 現況與下一步 | [開發順序](docs/DEVELOPMENT_ROADMAP.md) |
| 美術資產製作與匯入 | [Blender 工作流程](docs/BLENDER_WORKFLOW.md) |
| 客戶端／世界核心分工 | [Godot 客戶端](docs/GODOT_CLIENT_ARCH.md)、[Rust 世界核心](docs/RUST_SERVER_ARCH.md) |
| MP0 驗收範圍 | [MP0 規格](docs/milestones/MP0_SPEC.md) |
| 被取代的舊資料及來源 | [封存索引](docs/archive/2026-07-25/README.md) |

## 已有實作與資料權威

目前程式位於 `crates/world-core`，已有人物核心與 7 個測試案例。已有一份可編輯的 Blender 分件角色試作，通過 Godot 骨架、分件與動作匯入檢查；組織樹、完整指揮鏈、Godot 遊戲客戶端、量產模型及引擎效能驗收尚未完成。

`main` 分支及其正式設計文件是已合入版本的單一事實來源。工作分支保存待整合更新；研究文件、GitHub 舊議題與封存資料不自動成為正式規格。新決定需在文件中保留來源與狀態。

歷史議題 #4 的「具名身分死亡後不可再生成」已由 [GD-002](docs/decisions/GD-002_NAMED_IDENTITY_CYCLE.md) 取代：一次生命永久死亡，具名身分可由新的生命再次承載。
