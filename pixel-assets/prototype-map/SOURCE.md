# 營地美術來源與狀態

狀態：新增場景美術候選，待使用者確認。人體底稿沒有重畫。

使用內建 image_gen 工具（不是 CLI fallback）生成兩個圖集與一張水域分件。原始 PNG 已保留在本目錄，透明物件圖集的角落與物件間隙已確認 alpha=0。以 Aseprite 批次裁切、縮放及產生可編輯原檔；每個物件與地形原檔重新開啟後逐像素比對成功。詳見 prototype/reports/client/aseprite-art.log。

- `environment-atlas-v01.png`：帳篷、松樹、岩石、物資箱、石牆與爐灰圖集。各分件保留 `.aseprite`，正式場景使用前五項。爐灰分件保留作來源，未加入新的障礙。
- `ground-atlas-v01.png`：草地、土路與營地碎石土。Aseprite 原檔 `terrain-v01.aseprite` 分成草地、道路、營地三層；輸出 1024×768，Godot 以最近鄰顯示為 2048×1536 世界像素。
- 執行時 PNG：`godot-client/prototype/map/art/`。
- `pond-source-v01.png` / `pond-v01.aseprite`：水域候選，含淺水石底、漣漪與窄岸線，沿用原水域阻擋矩形。
- 可重現裁切工具：`scripts/prototype_map_art.lua`；只處理本分工來源與輸出。

這些圖集是 AI 生成候選；場景的 32 像素導航格與障礙 footprint 保持原操作檢查點設定，不把美術檢查視為最終使用者美術核准。

## 物件圖集提示

Use case: stylized-concept. Asset type: production pixel-art environment sprite atlas for an isometric-ish 2D Chinese wilderness squad game. Create ONE 1536x1024 PNG sprite sheet with real transparent alpha, exactly a 3-column by 2-row grid of six 512x512 cells. Each object must be fully contained in its own cell with at least 32px empty padding, centered, no touching other objects. Camera fixed orthographic three-quarter overhead, viewing north faces and roofs, consistent top-left warm light. Palette earthy ochre canvas, muted deep olive foliage, weathered dark timber, slate grey mossy stone. Sophisticated finely hand-pixelled game art, sharp stepped pixel edges, rich tactile material detail and clustered pixel shading, dark contour accents, about 2px clusters at this resolution. No blurry watercolor, no smooth vector flat shapes, no cartoon bright colors. TOP ROW left: one weathered large beige canvas expedition A-frame tent, sewn roof seams, folds, rope ties, wooden support poles, dark open doorway toward lower right, no surrounding scenery. TOP ROW center: one tall dense pine tree with irregular tiered detailed needles, bark trunk showing at bottom and a few exposed roots, viewed slightly from above. TOP ROW right: one broad group of angular moss-covered granite boulders, obvious rocky faces and cracks. BOTTOM ROW left: two weathered wooden supply crates with iron straps, a cloth pack resting beside them, small ground shadow. BOTTOM ROW center: one straight north-south ruined low stone wall strip, narrow and tall in the image, visible capped top and right face, roughly 1:3 width to height, uneven stones and moss. BOTTOM ROW right: a small contained cold campfire ring with charcoal, stones and two logs, no flames, no people. True isolated transparent silhouettes with transparent gaps; NO floor tile underneath, NO background, NO text, NO labels, NO grid lines, NO checkerboard painted into image. This atlas will be cropped into separate sprites and used in an actual playable Godot map; preserve practical clear silhouettes.

## 地表圖集提示

Use case: stylized-concept. Asset type: ground texture atlas for an actual playable 2D pixel-art wilderness camp. Create a 1536x512 image made of exactly THREE seamless square 512x512 texture tiles side by side with NO gaps, NO labels, NO borders. Flat orthographic straight-down surface texture only, uniform diffuse lighting, no perspective, no objects casting big shadows. LEFT THIRD: dark muted olive-green woodland moss and short grass with sparse tiny fallen needles, earth peeking through, finely detailed irregular pixel clusters, low contrast suitable behind 64px game characters. CENTER THIRD: worn ochre-brown packed dirt path with small pebbles, tiny cracks, occasional dull straw, softly variegated but no large feature, color approximately #7d7053. RIGHT THIRD: warm brown camp clearing dirt with irregular old flat stone fragments and leaf crumbs, subtle worn foot traffic, color approximately #827053. Fine sophisticated handcrafted pixel game textures with 1-2px clusters, earthly natural limited palette, dark contours on occasional tiny pebble, not cartoon, not blurry, not smooth gradients, not huge checkerboard tiles. Every tile fills its entire third edge to edge, each independently seamlessly repeatable. This texture is for ground surfaces only; NO tents, NO trees, NO people, NO walls, NO flowers, NO text.
