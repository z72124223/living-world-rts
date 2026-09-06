# 角色衣裝與逐格原檔

本資料夾是新增的原型素材。`asset-library/` 與既有人體底稿唯讀；本次讀回其 manifest 的 55 個檔案 SHA-256 均符合。

- `native/female-actor.aseprite`、`native/male-actor.aseprite`：每份 13 圖層、80 影格、12 動作標籤、1,040 個可編輯 cel。身體與衣服的遠腿、近腿、遠臂、軀幹、近臂分開，另有胸甲、佩劍、頭髮臉。
- `native/*-garment-source.aseprite`：256×256 的獨立衣裝原始圖層，四向各一份。
- `source-textures/`：原身形輪廓與新增服裝、甲、劍、方向頭髮的分件。
- `baked-layers/`：Godot 使用原身形骨架和網格實際渲染的分層圖集；供 Aseprite 原檔再製。
- `references/`：內建 image_gen 的兩張新参考與完整提示詞。第一張只有有效左前／左後研究；右前／右後另生成第二張。參考圖不替代原檔或遊戲圖集。

已認可的西南頭臉像素直接保留，讀回差異為 0。新東南與兩個背面使用分別生成的頭髮／臉部方向；軀幹仍沿用已認可的中性人體輪廓，右向以左右投影重用輪廓並套獨立衣裝細節。這是骨架帶動後輸出的 2D 逐格原型，未宣稱每個動作都是全新手繪或具有 3D 轉身體積。像素驗證對鏡像並容許 ±2 像素對齊偏差，四向仍有實際不同圖像。

衣物與人體使用同一分件頂點、肩肘髖膝權重和動畫變換，避免兩套骨架不同步。胸甲跟軀幹，佩劍跟骨盆，近臂蓋在胸甲和劍上。佩劍投影固定在解剖左髖，背面調整側邊。保留原站姿彎肘，避免將單張底稿過度拉直後露出缺失像素；跑步加大腿、膝和擺臂動作，足點有共同基準。

用已保存的參考即可完全再製，無須重新呼叫 imagegen：

```powershell
pwsh -File scripts/prototype_art_build.ps1
# 只讀回現有圖集並跑實際 Godot 驗收：
pwsh -File scripts/prototype_art_build.ps1 -VerifyOnly
```

可用 `-GodotExe`、`-AsepriteExe` 指定其他本機路徑；本次為 Godot 4.6.3、Aseprite 1.3.18.3-dev。輸出限定本任務資料夾。完整流程為 Aseprite 衣裝分件 → Godot 骨架渲染 → Aseprite 逐層逐格原檔與 8 組穿戴圖集 → 原檔像素讀回 → GPU 預覽及小型效能實測。

新增服裝設計、背面、轉向連貫性和跑步動作均待使用者審美確認；原本男女身形的 approval 不被擴張為新素材的 approval。
