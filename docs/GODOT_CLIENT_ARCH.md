# Godot 客戶端：分工與試作邊界

更新：2026-09-06。引擎選型已確認；以下是待實作的分工，不代表已有客戶端。

## Godot 負責的內容

模型／圖像呈現、鏡頭、燈光、動畫、聲音、輸入、選取、介面與打包。世界規則由既有 Rust 核心提供，參見 [Rust 世界核心](RUST_SERVER_ARCH.md)。

畫面設計需表現人物輪廓、旗號、行動與局勢；細節是否保留，依玩家觀看距離及判斷需求決定。顯示資訊必須遵守玩家與 NPC 共用的情報規則。美術展示若臨時提供自由鏡頭，須標明展示用途，不能因此鎖定正式遊戲視野。

## 第一輪試作

- 先做 [TD-002](decisions/TD-002_GODOT_BLENDER_ART_PIPELINE.md) 的美術樣品，不建立帳號、連線大廳或完整世界伺服器。
- 客戶端預定放在根目錄 `godot-client/`；目前尚未建立。模型源檔沿用 `blender-assets/`，匯出後進入客戶端資產目錄。
- 可比較文字場景與腳本驅動的製作方式；腳本語言、渲染器及 Rust 接合方式由試作決定，尚無選型承諾。
- 畫面用資料必須能和權威人物 ID 對應。展示假資料只用於美術測試，不複製正式世界規則。

## 像素與效能

像素美術不直接等於低硬體需求。即時 3D 仍需計算動畫、幾何、光影與世界模擬；預渲染圖像則要計算方向、動作、換裝素材量與記憶體成本。

樣品應比較固定條件下的幀時間、資源用量、畫面辨識與動作清晰度。像素畫面要檢查縮放和移動是否抖動，文字介面能否清楚閱讀。低畫質設定也須讓玩家看懂關鍵動作與旗號。

Godot 提供大量物件繪製等最佳化工具；不能把物件繪製的數量宣稱當成完整骨架動畫、導航、AI 或世界模擬的承載能力。這些成本需分別測量。

## 自動化與畫面驗證

官方支援透過命令列匯入、執行場景及匯出版本；Godot 文字場景可供直接檢查。實作時需以目前安裝版的參數為準。

無畫面模式適合匯入、規則與腳本檢查。畫面、材質和動作必須另以真實渲染的圖片／短片或可執行樣品檢查；匯入成功不等於視覺或效能通過。輸出版本另需相符的匯出模板，目前未驗證打包。

## 官方參考（2026-09-06 查核）

- [Godot 4.6 命令列操作](https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html)
- [文字場景格式](https://docs.godotengine.org/en/stable/engine_details/file_formats/tscn.html)
- [解析度與整數縮放](https://docs.godotengine.org/en/4.6/tutorials/rendering/multiple_resolutions.html)
- [3D 效能與動畫成本](https://docs.godotengine.org/en/4.6/tutorials/performance/optimizing_3d_performance.html)
