# Living World RTS

即時戰略（RTS）＋角色扮演（RPG）的持續活世界。人物、武將身分、組織、資訊與歷史共同形成玩家的經歷。

## 目前決定（2026-09-06）

- 遊戲客戶端採 **Godot 4**；本輪角色、衣裝、武器、場景與動畫改採 **Aseprite 的 2D 像素流程**；世界規則核心維持 **Rust**。Blender 不參與本輪製作。
- 美術以低資源、高效能、高性價比及良好畫面為目標。依 2D / 3D 比較結果，使用者選擇直接製作 2D，並要求可操作的骨架、換裝、特效與遊戲邏輯樣品。
- 外觀參考為已認可的 B 像素女性輕甲圖。先前程序化 3D 人體與女性模型未達使用者要求，保留為歷史試作。
- 下一個工作階段優先驗證美術樣品與製作流程，再延續 MP0 的人物、組織與指揮骨架。

## 閱讀入口

| 內容 | 文件 |
|---|---|
| 已確認的世界規則與體驗守則 | [遊戲憲法](docs/GAME_CONSTITUTION.md) |
| 先前想法、差異化與待驗證項目 | [設計想法索引](docs/DESIGN_IDEAS.md) |
| Godot、Blender 與美術製作選型 | [技術決議 TD-002](docs/decisions/TD-002_GODOT_BLENDER_ART_PIPELINE.md) |
| 原創美術概念圖與生成來源 | [美術方向草案 v01](blender-assets/concepts/art-direction-v01.md)（概念參考，非遊戲截圖） |
| 女性角色概念與三種穿戴造型 | [女性角色・B 像素方向 v01](blender-assets/concepts/female-character-b-v01.md)（外觀參考已認可） |
| 目前的可操作美術樣品 | [女性武將像素練武場](godot-client/README.md)；[Aseprite 原檔](pixel-assets/aseprite/) |
| 已建檔的人體成品與新樣品 | [人物素材庫](asset-library/README.md)；女性 1.0.0 已確認，男性 0.1.0 已確認 |
| 先前的女性 3D 試作 | [女性輕甲靜態模型 v01](blender-assets/samples/female-light-armour-v01/README.md)（外觀未通過） |
| 先前樣品 | [人體與像素基底 v02](blender-assets/samples/body-pixel-v02/README.md)；[分件 v01](blender-assets/samples/modular-character-v01/README.md) 已被使用者否決 |
| 現況與下一步 | [開發順序](docs/DEVELOPMENT_ROADMAP.md) |
| 美術資產製作與匯入 | [Blender 工作流程](docs/BLENDER_WORKFLOW.md) |
| 客戶端／世界核心分工 | [Godot 客戶端](docs/GODOT_CLIENT_ARCH.md)、[Rust 世界核心](docs/RUST_SERVER_ARCH.md) |
| MP0 驗收範圍 | [MP0 規格](docs/milestones/MP0_SPEC.md) |
| 被取代的舊資料及來源 | [封存索引](docs/archive/2026-07-25/README.md) |

## 已有實作與資料權威

`crates/world-core` 已有人物核心與 7 個測試案例。`godot-client` 為獨立的 2D 人物美術與互動樣品，尚未接入 Rust 世界核心；組織樹、完整指揮鏈、完整遊戲客戶端及量產效能驗收尚未完成。樣品操作驗證與真實渲染保存在 `godot-client/verification`，不得以程式檢查通過代替美術認可。

`main` 分支及其正式設計文件是已合入版本的單一事實來源。工作分支保存待整合更新；研究文件、GitHub 舊議題與封存資料不自動成為正式規格。新決定需在文件中保留來源與狀態。

歷史議題 #4 的「具名身分死亡後不可再生成」已由 [GD-002](docs/decisions/GD-002_NAMED_IDENTITY_CYCLE.md) 取代：一次生命永久死亡，具名身分可由新的生命再次承載。
