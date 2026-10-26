# 人體與骨架校準 v02

使用者指出舊骨架比例與關節位置錯誤，要求先建立無衣物人體再對齊骨架。

交付為直接建立的無衣物、無性徵細節人形網格，不是把衣物塗成膚色。貼身衣生成圖只保留為未採用的中間參考；最終網格不用它的像素或衣物輪廓當皮膚。身形是依人物比例重建的估計，仍需使用者檢視。

- `character-before.json` 保留修改前的座標、長度、動畫與分件。
- 原版髖點 y=145/146，修正版 y=124；膝點 y=181/184，修正版 y=167/169。
- 修正版骨段端點接到肘、腕、膝、踝，方向與長度不再固定填值。
- 本輪測試證明幾何權重正規化、端點連接與彎曲連動，不能當作人體比例或完整動畫已通過美術驗收。

引擎做法參照 [Polygon2D 官方文件](https://docs.godotengine.org/en/stable/classes/class_polygon2d.html) 與 [Bone2D 官方文件](https://docs.godotengine.org/en/stable/classes/class_bone2d.html)。
