# 角色衣裝與動畫：可用本機 checkpoint

日期：2026-09-06。分支 `codex/prototype-actors-20260906`；共同起点 `5fecdf9c50ec1cc67ff6b77be8ba8c8cf8913d82`。工作樹 `C:/Users/f7212/.codex/worktrees/ee20/遊戲開發`。

完成的角色入口為 `godot-client/prototype/actors/character_actor.gd`，獨立預覽為同目錄 `actor_preview.tscn`。公開四方法依 `SESSION_BRIEF.md`，客戶端可直接 preload/new/configure，以世界 velocity 32／56 切换步行／跑步，停止保留方向；position 仍由客戶端管理。腳点為 `(0,0)`，人物約 64 世界像素，比例可調。

男女各有 4 個斜向、站立 4 格／步行 8 格／跑步 8 格，共 80 影格；衣服、胸甲、佩劍獨立切換，共 8 組穿戴圖集。各角色正式編輯原檔為 `pixel-assets/prototype-actors/native/<female|male>-actor.aseprite`，每份 13 層、1,040 個可編輯 cel、12 個動作標籤。來源為獲認可人體及新衣甲分件的骨架動畫預先渲染，遊戲中每人僅 1 個 Sprite2D，原人體密集網格不進遊戲角色。

本回合實測：

| 檢查 | 結果與證據 |
|---|---|
| Godot 原生 GPU 預覽 | 59 項通過；`actor-runtime-report.json`，`actor-runtime.log`，錯誤日誌為空 |
| 四向、停步朝向、動作影格、選取、穿戴、比例與位置責任 | 全通過，報告內保留 source_frame、atlas row、Sprite2D 與穿戴狀態 |
| Aseprite 真正原檔重開 | 男女每份 13 層／80 格／12 tags／1,040 cels；全穿戴 80 格逐像素讀回差異 0，`aseprite-roundtrip.log` |
| 四向實際像素 | 容許 ±2 像素平移後與左右鏡像比較仍有差異，前後亦不同；`aseprite-pixel-report.json` |
| 原認可素材保存 | manifest 55 個 SHA-256 均符合；`approved-source-integrity.json`。西南原頭臉分件差異 0 |
| 圖集邊界及衣裝 | 160 格皆非空、無接觸裁切邊界；男女各 8 種穿戴像素不同 |
| 再製驗收入口 | `pwsh -File scripts/prototype_art_build.ps1 -VerifyOnly` 實跑通過；完整 Aseprite → Godot bake → Aseprite export 的各步已實跑 |

GPU 截圖：`01-four-directions-full-equipment.png`、`02-clothing-only.png`、`03-base-without-equipment.png`、`04-four-directions-walk.png`、`05-four-directions-run.png`、`06-performance-32-actors.png`。這些都是 Godot 實際 viewport 讀回，未以生成概念圖替代。

效能樣本為 Windows 10.0.19045、Intel i7-8700（12 執行緒）、NVIDIA GTX 1080 Ti、Godot 4.6.3 / OpenGL Compatibility、1280×800、VSync=1。只量同畫面 32 人混合步行／跑步，隱藏的原 8 人停止 process；暖機至少 2 秒，記錄 240 影格。平均 **5.883 ms**、95 百分位 **5.951 ms**，末影格 124 個繪製呼叫（包含預覽介面）。這是此電腦與此小型場景的結果，沒有大型 RTS 人數容量結論。全部 16 組圖集未壓縮 RGBA 像素估計約 180 MiB；貼圖按使用組合共用與快取。

仍待驗收：新增衣装、背面、東南頭臉与跑步动作的使用者審美確認；協調窗口與地圖／世界資料的實際整合、Windows 最終打包。右向身體重用獲認可輪廓的水平投影，同時配獨立新頭髮／臉、前後衣甲與佩劍；未宣稱全角度手繪或 3D 轉身。新素材的 `art_approval` 維持 `PENDING_USER_REVIEW`，不能沿用底稿 approval。沒有新增 HP、傷害或戰鬥公式。

LATTICE runtime_status 本回合可呼叫，回傳 receipt-only / NOT_STARTED，未提供此工作的 task_ref；協調窗口確認也未取得。沒有捏造或新增 LATTICE 任務身分。本機成果與此報告提供實際續接依據。

僅改本分工允許範圍；未改主場景設定、世界核心、地圖、既有素材庫或 8780 服務；未 push、merge、部署或封存。協調窗口可 cherry-pick 本分支提交後，以 `res://prototype/actors/character_actor.gd` 替換暫時人物顯示。
