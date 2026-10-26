# 男女武將：人體曲線、網格與骨架樣品

Godot 4.6.3。外觀沿用已認可的女性輕甲參考，使用 Aseprite 分層、逐格原檔與 Godot 原生 Skeleton2D / Bone2D。這是局部美術與互動樣品，沒有接入 Rust 世界核心。

目前啟動會先進入男性人體樣品，可用右上按鈕切換女性。左側是人體曲線，右側是由同一輪廓生成的可變形網格與 15 根人體骨骼。女性 v03 已於 2026-09-06 獲得使用者確認，收錄為素材庫 1.0.0；男性 v01 收錄為 0.1.0，技術與造型均已確認。可選肩、肘、髖、膝並拖曳角度，或播放來回彎曲；可切換網格、骨架與曲線疊合。

女性原檔是 `../pixel-assets/aseprite/female-body-contour-v03.aseprite`，男性原檔是 `../pixel-assets/aseprite/male-body-contour-v01.aseprite`。兩者各有 8 層、1 格站姿、5 件人體網格；男性使用獨立的 `../scripts/male_rig_landmarks.lua` 配置肩、肘、腕、髖、膝、踝。人體底稿在 Aseprite 單獨繪製，網格直接沿用像素邊界。這仍是局部樣品，尚未作大規模 RTS 效能最佳化。

素材庫入口為 <http://127.0.0.1:8780/library/>，版本原檔、PNG 分件、網格、骨架、來源提示詞及實測截圖位於 `../asset-library/`。詳細目錄見 [素材庫說明](../asset-library/README.md)。`assets/body-catalog.json` 決定目前男女角色的素材路徑、版本與審美確認狀態。

輪廓驗證在真實 Godot 渲染器中移除網格貼圖，再比較幾何遮罩與 Aseprite 曲線稿，避免用透明貼圖掩蓋網格超出邊界。結果在 `verification/body-v03-report.json` 與 `verification/male-body-v01-report.json`，包含站姿、彎肘、彎膝截圖與輸入檔案的 SHA-256 雜湊。男女輪廓差異均為 0 像素。驗證命令：`godot --path godot-client -- --capture-contour-tests --character=male`，女性改為 `--character=female`。

修改 Aseprite 人體圖層後，執行 `scripts/build_body_contour_v03.lua` 重建時必須傳入 `--script-param root=<專案絕對路徑>`、`--script-param from_master=true`，男性另加 `--script-param character=male`。這會沿用已編輯的原檔曲線與顏色，不重置成初稿。完成 Godot 匯入、實測後，可執行 `python scripts/build_asset_library.py` 核對雜湊並收錄。既有版本的來源與執行素材不可覆寫為不同內容。

按「練武場」可回到原本的遊戲樣品。歷史 v02 對照仍保留在 `scenes/rig_check.tscn`：左側舊骨架、右側修正骨架，兩側使用同一個簡化人形網格。

校準模型依參考圖重建身形，並非從衣甲中精確恢復人體。它包含 360 個頂點、528 個三角形、6 個 Polygon2D 網格，綁定實際 Skeleton2D；修正版共有 17 根骨骼。舊髖點過低、膝點過低、骨段方向固定朝上及未分開腕踝端點的問題已修正，長度與角度由明確端點計算。身形及完整動作仍待美術驗收，衣裝仍使用原有分件動畫，沒有宣稱全套衣裝都已蒙皮。

人體網格的 Aseprite 原檔是 `../pixel-assets/aseprite/female-body-mesh-v02.aseprite`；可變形幾何與權重在 `assets/body-mesh.json`，關節座標來源為 `../scripts/rig_landmarks.lua`。`verification/rig-v02-report.json` 及三張 `rig-v02-*.png` 為實際引擎站姿、彎肘、彎膝驗證。此校準網格由幾何頂點直接建立，沒有使用貼身衣圖片當作身體。

操作：WASD / 方向鍵或點擊地面移動；空白鍵攻擊；B 顯示骨架。右側可以切換青衣 / 輕甲、空手 / 佩劍 / 長槍、骨架連動 / 逐格播放，也可暫停逐格查看。靠近木樁並面向它攻擊會增加命中次數及顯示特效，沒有新增角色 HP 或肢體傷害規則。

人物目前使用單一斜側面及左右鏡像。動畫是分件關鍵姿勢製作，再輸出逐格素材；不是已完成多方向手繪動畫。Aseprite 原檔在 `../pixel-assets/aseprite/`，包含人物、場景、木樁及六格劍光。人物原檔保留衣甲與武器獨立圖層。

在 Godot 開啟 `project.godot`，執行主場景即可。Web 與 Windows 打包位於 `web/` 與 `build/`，生成輸出不加入版本控制。

從專案根目錄重建：

1. 用 Aseprite 執行 `scripts/build_pixel_sample.lua`，傳入 `--script-param root=<本專案絕對路徑>`。
2. 用 Aseprite 執行 `scripts/build_rig_mesh.lua`，使用相同參數產生人體網格原檔與幾何；再執行 `scripts/verify_pixel_sample.lua`，讀回檢查人物動畫原檔。
3. `godot --headless --path godot-client --editor --import --quit`。
4. `godot --path godot-client -- --capture-rig-tests`：驗證人體網格權重、彎肘與彎膝的骨段端點。`godot --path godot-client res://scenes/main.tscn -- --capture-tests`：執行練武場操作驗證，輸出真實引擎截圖與 `verification/runtime-report.json`。
5. `godot --headless --path godot-client --export-release Web` 或 `--export-release Windows`。

原始圖片生成提示詞位於 `../pixel-assets/sources/prompts.txt`。內附字型來自 Noto Sans TC，授權見 `assets/FONT-LICENSE.txt`。Aseprite 本機編譯工具不隨專案散布。
