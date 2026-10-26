# 真實 3D 底模與美術材質試樣

本次只比較同一實體模型的灰模、卡通著色、前後側視角與俯視尺度。`preview.png` 由實際 Blender 渲染圖排版，沒有生成式圖片重繪；`preview.html` 切換預先渲染的視角，不是即時 3D 網頁。

- `model.blend`：可編輯模型、材質節點、UV 布面貼圖與鏡頭。貼圖已打包，使用 Blender 5.1.2 開啟後 F12 可重現正面。
- `01-clay.png` 至 `06-rts-96.png`：六張實際渲染；灰模與上色正面使用相同幾何及鏡頭。
- `build.py`：先讀取既有 MakeHuman 衍生底模，再建立／修改衣服、頭髮、材質與場景；只寫本資料夾。
- `present.py`：只排版渲染圖與文字，不修飾角色像素。
- `build-report.json`、`render.log`：本回合實際建模與渲染紀錄。
- `verify-rerender.png`、`verify-render.log`、`verification.json`：從保存的 `.blend` 新開程序再渲染的核對證據。

材質是法線方向的三階色塊、512×512 布面圖與 Freestyle 輪廓。它呈現卡通 3D 外觀，不代表已達簡化手繪定版。後領、袖口、臉部與服裝細節仍需美術整理；本版只做靜態樣品。保留原骨架及部分新衣服權重，但鞋、縫線等尚未完成正式綁定，沒有驗收動畫、換裝或 Godot 即時效能。Cycles／Freestyle 的外觀不會自動原樣轉成遊戲引擎材質。

人體基底取自原專案的 `blender-assets/samples/body-pixel-v02/body-rig.blend`，其圖形來源為固定 MakeHuman 提交 `a8bc2d54ff0ac92e78ff71431b1023eda42bf482`，圖形資產 CC0；本版不宣稱人體由零雕塑。來源授權副本見 `LICENSE.ASSETS.md`。不使用 MakeHuman 應用程式碼。

在本工作樹根目錄重建：

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background --factory-startup --python-exit-code 1 --python 'art-experiments/3d-toon-v01/build.py'
& 'C:/Users/f7212/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' 'art-experiments/3d-toon-v01/present.py'
```

`build.py` 依目前本機來源絕對路徑重建；跨電腦可直接使用已打包貼圖的 `model.blend`，或先調整腳本的 SOURCE 路徑。
