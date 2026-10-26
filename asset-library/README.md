# Living World RTS 素材庫

本機瀏覽入口：<http://127.0.0.1:8780/library/>。啟動方式：在專案根目錄執行 `python scripts/serve_pixel_sample.py`。

| 素材 | 版本 | 狀態 | 紀錄 |
|---|---|---|---|
| 女性人體曲線＋網格＋骨架 | 1.0.0（來源 v03）| 使用者已確認 | [素材檔案](characters/human-female-base/1.0.0/README.md) |
| 男性人體曲線＋網格＋骨架 | 0.1.0（來源 v01）| 使用者已確認 | [素材檔案](characters/human-male-base/0.1.0/README.md) |

每份紀錄包含固定素材編號、版本、審美認可狀態、Aseprite 原檔、PNG 分件、網格權重、骨架端點、生成參考、提示詞、Godot 實測截圖及 SHA-256 雜湊清單。`catalog.json` 是目錄，個別 `asset.json` 是詳細建檔資料。

在工作區編輯與驗證，成品以版本資料夾保存。`python scripts/build_asset_library.py` 會核對目前素材與 Godot 驗證的檔案雜湊，拒絕把未驗證或內容不同的來源覆寫進既有版本。後續改版先調整角色目錄的版本號，再收錄成新版本。

男女角色的最新審美確認以各自 `asset.json` 的 `approval` 為準；版本號不因單純確認而改變。原始網格檔內的草稿描述保留為生成當時的來源紀錄。早期試作仍保留在原處。
