# 男性人體・曲線／網格／骨架

- 素材編號：`human-male-base`；版本：`0.1.0`；狀態：**已確認成品**。
- 來源修訂：v01。收錄時間：2026-09-06T09:09:34+08:00。
- 256 × 256 透明畫布、8 個原檔圖層、1 格站姿、5 件人體網格、15 根骨骼。
- [Aseprite 原檔](source/male-body-contour-v01.aseprite)／[素材紀錄](asset.json)／[檔案雜湊清單](manifest.sha256.json)。
- [站姿](previews/rest.png)、[彎肘](previews/elbow.png)、[彎膝](previews/knee.png)為 Godot 實際執行截圖。
- [技術驗證](verification/report.json)：網格幾何與人體底稿輪廓差異 0 像素，骨架端點與權重檢查通過。

使用者確認「好 通過」，接著詢問如何做成實體遊戲；此確認適用目前男性人體曲線、網格與骨架樣品。

原檔是人體曲線的編輯來源；網格不可另改身形寬度。先複製此版本到工作區再編輯。重建 Aseprite 時，從專案根目錄執行 `scripts/build_body_contour_v03.lua`，傳入 `root=<專案絕對路徑>`、`from_master=true`、`character=male`。重新執行 Godot 驗證後，以新版本收錄。素材庫腳本會拒絕覆寫內容不同的既有來源與執行素材。

Godot 使用 `runtime/assets/` 的同尺寸分件貼圖、網格與骨架資料。現有 `body_rig.gd` 可設定 `mesh_path`、`rig_path`、`texture_prefix`、`reference_path` 與 `head_path` 載入。字型附帶 SIL OFL 授權。原始生成參考與提示詞在 `source/references/`。

單一方向人體基底與互動彎曲樣品；尚未製作完整動作集、衣裝綁定或大量 RTS 單位效能優化。
