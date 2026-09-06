# 角色衣裝、步態與有界快取：增量驗收

日期：2026-09-06。分支 `codex/prototype-actors-20260906`；本次增量接續 `d6707612af51c0baae1057c5b90a98d9a46b7adb`，保留該 checkpoint。工作樹 `C:/Users/f7212/.codex/worktrees/ee20/遊戲開發`。

完成協調窗口要求的三項修正：

1. 衣裝以既有認可女性甲衣參考及其分件重建布料皺褶、領口、紅腰帶、層甲鉚釘、護腕與皮靴；男女四向皆有對應材質，原人體及資產庫保持唯讀。
2. 肩、肘、腕改為分段骨骼擺動，重疊關節端點避免裂縫；跑步雙臂交替，手腕隨前臂，近手在腰前維持可見。腿部 IK 依原骨長計算，以移動速度補償著地期。
3. 移除 16 張完整穿戴組合圖集，改為男女各 13 張裁去空白的獨立來源層。CPU 共用來源 Image；GPU 按需合成當前影格並共用 LRU，快取上限 64 格且 8 MiB。

角色入口仍是 `godot-client/prototype/actors/character_actor.gd`。四方法 `configure(Dictionary)`、`set_motion(Vector2)`、`set_equipment(Dictionary)`、`set_selected(bool)` 不變；世界 position 由客戶端管理，腳點 (0,0)，人物約 64 世界像素。32／56 為步行／跑步基準速度，步頻依實際速度調整；停止保留方向。遊戲中每人 1 個 Sprite2D。

男女各 4 個斜向、站立 4 格／步行 8 格／跑步 8 格，共 80 格；衣服、胸甲、佩劍獨立切換。正式原檔 `pixel-assets/prototype-actors/native/<female|male>-actor.aseprite` 各有 13 層、1,040 個可編輯 cel、12 個動作標籤。

## 本回合驗證

最後 `pwsh -NoProfile -File scripts/prototype_art_build.ps1 -VerifyOnly` 實跑成功，報告時間 2026-09-06 03:00:00 UTC。修正後的完整 Aseprite → Godot bake → Aseprite export 已實跑；最後一次 VerifyOnly 對其輸出重新驗收。

| 檢查 | 結果與證據 |
|---|---|
| Godot Windows 原生 GPU 預覽 | 66 項通過；actor-runtime-report.json、actor-runtime.log，錯誤日誌為空 |
| 真正合成貼圖逐像素讀回 | 男女全部 160 格、5,898,240 像素；對照 Aseprite proof 的透明度及可見 RGB，totalMismatch=0、maxdiff=0，實際差異為零 |
| Aseprite 原檔重開 | 男女各 13 層／80 格／12 tags／1,040 cels；全部影格讀回差異 0，aseprite-roundtrip.log |
| 完整步態循環 | gait-validation.json 共 21 項通過，涵蓋 16 組步行／跑步循環各 8 格 |
| 肩肘腕接縫、近手遮擋 | 身體手臂渲染層 4,608 個關節路徑採樣皆覆蓋；128 個移動關鍵格近手皆可見 |
| 著地及 IK | 80 對著地關鍵格補償根節點移動後，腳踝最大位移約 0.0000193 世界像素；最大 IK 到達誤差約 0.0000135 |
| 原認可素材保存 | 55 個 SHA-256 全符合，approved-source-integrity.json；西南原頭臉分件像素差異 0 |
| 四向及衣裝 | 四向像素不是同圖或單純鏡像；160 格非空、無碰到原畫布裁切邊界；男女各 8 種穿戴像素不同，aseprite-pixel-report.json |
| 介面與快取 | 四向、停步方向、動作、選取、穿戴、比例、位置責任、LRU 格數／bytes 上限、存活貼圖上限皆通過 |

本目錄 01–06 PNG 是 Godot viewport 實際讀回，分別展示全裝、衣服、人體、步行、跑步與 32 人效能。新增 `07-run-cycle-male.png`、`08-run-cycle-female.png` 各展示四向完整八格跑步循環。八張皆已檢視，用於審看材質、關節接縫及手腳位置。

著地數值限於四斜向、32／56 基準速度的離散關鍵格；8／12 fps 格間仍可能看到一格步進造成的相對移動，不能當作連續時間完全無滑步保證。美術審美仍待使用者確認。

## 記憶體與 32 人效能

舊版 16 個完整組合約 180 MiB 未壓縮 RGBA 圖集已移除。當前數據區分來源 CPU、GPU 貼圖像素估計與 Godot viewport 監測：

| 類別 | 最後實測／估計 |
|---|---|
| 男女共用來源 CPU Image | 31,275,520 bytes，約 29.83 MiB |
| 持續保留的來源 GPU 貼圖 | 0；讀出 CPU Image 後釋放來源 Texture2D |
| LRU 限制 | 64 格且 8,388,608 bytes，兩限制同時套用 |
| LRU 歷史峰值 | 3,858,136 bytes，約 3.68 MiB |
| 所有存活合成影格峰值，含角色保留的已逐出格 | 69 張、3,986,728 bytes，約 3.80 MiB |
| 32 人採樣時 LRU 外仍被角色引用的格 | 5 張、292,904 bytes |
| Godot viewport 貼圖記憶體監測峰值 | 14,694,077 bytes，約 14.01 MiB，含字型及預覽介面 |

角色正在顯示的影格即使被 LRU 逐出，仍會保留到角色換格。存活合成貼圖總數上限為 64 加有效角色數，建立新格當下最多再加 1。採樣有 32 位可見角色及 8 位停止 process 的隱藏預覽角色，引用計數為 40。合成貼圖 bytes 是 RGBA payload 估計，不含渲染器配置開銷或延後釋放；來源 CPU 不包含在 8 MiB GPU 快取限制內。

來源透過 Godot 匯入 Texture2D 後 get_image()，初始化可能短暫上傳來源。單張最大 2,288,000 bytes，全部上傳量／保守瞬時上限 31,275,520 bytes；這不是實測初始化峰值。Godot 貼圖監測從預覽角色建立後開始，未涵蓋更早的載入瞬間。

效能環境：Windows 10.0.19045、Intel i7-8700／12 執行緒、NVIDIA GTX 1080 Ti、Godot 4.6.3／OpenGL Compatibility、1280×800、VSync=1。32 位可見角色混合四向步行／跑步，全衣甲佩劍；暖機 341 格／2.002 秒，採樣 240 格。平均 **5.881 ms**、p95 **5.954 ms**、最大 6.932 ms；每格 **124 次繪製呼叫**，含預覽介面。僅為本電腦小場景樣本，不推論大型 RTS 容量。

## 接入與尚待確認

協調窗口在前一 checkpoint 後套用本次增量即可，入口及四方法不變。匯出須在非資源 include_filter 明確包含 `prototype/actors/layers/manifest.json`（或 *.json），並包含 manifest 內全部 PNG 的 Godot 匯入資源。角色以 ResourceLoader 讀取貼圖，可使用匯出後 .ctex；本分工未修改全域 export preset。

`pixel-assets/prototype-actors/previews/*-all.png` 是離線完整畫布驗證圖，遊戲角色不依賴它；完整像素驗收腳本需在來源工作樹執行。最後世界接入及 Windows 套件冒煙驗收由原協調窗口執行，本報告不宣稱已完成。

新衣裝、背面、東南頭臉及跑步維持 **PENDING_USER_REVIEW**。右向身體重用原認可輪廓的水平投影，搭配獨立頭髮／臉、前後衣甲與佩劍；未宣稱全角度手繪或 3D 模型。

LATTICE runtime_status 回傳 receipt-only／NOT_STARTED，未提供本工作 task_ref，協調窗口亦確認未取得；未捏造任務身分。僅修改本分工允許的角色、美術、製作腳本與驗收目錄，未改世界核心、地圖、主場景設定或 8780 服務；未新增 HP、傷害或戰鬥公式，未 push、merge 或部署。
