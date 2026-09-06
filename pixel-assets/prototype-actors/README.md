# 角色衣裝與逐格原檔

本資料夾是新增原型素材。asset-library/ 與既有人體底稿唯讀；manifest 55個原檔SHA-256均通過。既有已認可身形、原西南臉部未重畫。

native/female-actor.aseprite、male-actor.aseprite：每份13圖層、80影格、12動作標籤、1,040個可編輯cel。身體與衣服的遠腿、近腿、遠臂、軀幹、近臂分開，另有胸甲、佩劍、頭髮臉。native/*-garment-source.aseprite 包含256px材質分件及肩／肘／腕分段的動畫來源。source-textures/ 保存分件；baked-layers/ 保存Godot實際渲染圖層；previews/*-all.png 是原檔比對用的離線合成證據，不進遊戲常駐資源。

本次修正直接查看 pixel-assets/sources/female-armoured-reference.png，重用既有 godot-client/assets/parts/ 中由該參考及同風格cloth參考切出的像素群，包含布褶明暗、交疊衣領、紅色腰帶、弧形護甲片、金屬倒角與鉚釘、皮革及分段靴面，再沿已認可身形逐列重新貼合。沒有把隨機噪點或水平線條冒稱材料。衣服與靴子有2–3個來源像素的穿戴厚度，原人體像素和原檔保持不變。

手臂動畫的舊y方向權重在伸直時會把肘部壓向腹部。本版將原身形手臂像素依實際肩、肘、腕分段，補被遮住的關節重疊區，分別轉動上臂／前臂／手，衣袖及腕甲跟同一段。跑步雙臂隨腿部交替，手腕不再停在叉腰姿勢。站姿保留原已认可姿勢；新動作來源不是新的已批准人體版本。

腿部使用原骨架長度的雙節逆向運動學，以32/56世界像素速度生成腳接地軌跡；接地時踝部隨角色前進作相反位移，擺腿時抬腳，極限伸展時共同調整骨盆。驗收檢查完整16個移動循環的接縫、手露出及腳步，不只檢查frame值。足點仍是(0,0)。8/12FPS逐格顯示在關鍵格之間仍有階梯式位移；數值腳鎖證據只適用四斜向基準速度的關鍵格，不宣稱任意曲線路徑或連續3D步態。

四向沿用已認可中性輪廓，右向水平投影配獨立方向臉髮、前後衣甲及解剖左髖佩劍。references/ 包含先前內建image_gen兩張方向研究和完整提示詞；此輪衣料修正使用上述既有參考，不再生成或替換人體。新增衣裝、背面及動作 art_approval 保持 PENDING_USER_REVIEW。

完整再製（無須再次呼叫imagegen）：
~~~powershell
pwsh -File scripts/prototype_art_build.ps1
pwsh -File scripts/prototype_art_build.ps1 -VerifyOnly
~~~
可指定 -GodotExe、-AsepriteExe。使用Godot4.6.3與Aseprite1.3.18.3-dev；流程為Aseprite材質分件 → Godot原骨架/分段手臂/腳鎖渲染 → Aseprite逐層逐格原檔與裁切圖集 → 原檔像素讀回 → 步態量測 → 真正GPU預覽/效能。

裁切使用Aseprite正式 Image:shrinkBounds() API：https://aseprite.org/api/image#imageshrinkbounds 。遊戲中只讀獨立layers和有界當格合成快取；不再產生16套完整穿戴圖集。
