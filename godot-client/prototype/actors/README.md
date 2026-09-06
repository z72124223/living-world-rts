# 四斜向人物原型

公開入口仍是 Node2D 的 character_actor.gd。客戶端管理 position、人物 ID、尋路及存檔；角色腳點是局部 (0,0)，預設約 64 世界像素。

~~~gdscript
const CharacterActor = preload("res://prototype/actors/character_actor.gd")
var actor = CharacterActor.new()
add_child(actor)
actor.configure({"id": "person-1", "name": "人物甲", "gender": "female",
    "loadout": {"clothing": "cloth", "armor": "chest", "weapon": "sword"}})
actor.position = Vector2(256, 256)
actor.set_motion(Vector2(-1, 1).normalized() * 32.0)
actor.set_equipment({"armor": "none"})
actor.set_selected(true)
~~~

- configure(data: Dictionary)：male/female，visual_scale 可選，預設 1，不改呼叫端的 scale。
- set_motion(velocity: Vector2)：速度 <0.1 站立、0.1–44 步行、≥44 跑步。步頻依實際速度 / 32 或 / 56 同步，停止保留方向。
- set_equipment(loadout: Dictionary)：可局部更新。clothing=cloth/none、armor=chest/none、weapon=sword/none。
- set_selected(selected: bool)：足底選取圈，不處理選取輸入。
- 預覽輔助：set_preview_direction("nw")、set_preview_frame(0..7)（當前動作內的格；-1解凍）、get_visual_state()、靜態 get_cache_stats()。

四方向是 sw/se/nw/ne；正交速度映射到可用斜向，沒有八方向完成的宣稱。原生編輯影格仍為192×192、20欄×4列；各列 idle 0–3 / walk 4–11 / run 12–19。真實顯示貼圖是裁切後的單格合成圖，Sprite2D hframes/vframes=1，足點從 manifest.anchor 讀入，以0.5倍顯示。外部不應直接控制內部Sprite的frame_coords。

換裝容量：來源是 layers/manifest.json 指定的男女各13張獨立圖層，含身體與頭、衣裝、胸甲、武器。各層裁掉跨影格共用空白後保存在獨立圖集。來源貼圖讀回後只保留CPU Image，GPU來源資源釋放；目前兩性别來源RGBA共31,275,520 bytes（約29.83 MiB）。新的裝備增加一份對應slot來源，無須產生所有穿戴組合。

actor_frame_cache.gd 只合成需要的當前影格，GPU快取同時限制64格與8MiB，最久未用者先移除。角色可持有已被快取移除的目前影格，因此保留貼圖數另有「64 + 活躍角色數」上界；配置新格的瞬間再加1。get_cache_stats() 分開列出cache、active、CPU來源、來源暫時上傳估計；不把cache上限誤當整個程序的記憶體上限。每個角色仍只繪製1個Sprite，沒有遊戲內人體密集網格。

獨立預覽：

~~~powershell
godot --path godot-client res://prototype/actors/actor_preview.tscn
~~~

快捷鍵1/2/3切換站立/步行/跑步，C/A/S切換衣/甲/劍，空白鍵巡覽。完整驗證：
~~~powershell
pwsh -File scripts/prototype_art_build.ps1 -VerifyOnly
~~~

Windows 匯出需在非資源 include_filter 明確列入 prototype/actors/layers/manifest.json（或 *.json），並包含所有 layers/*.png 的 Godot 匯入資源；只選全資源匯出不保證包含 JSON。讀取來源使用 ResourceLoader.load(...).get_image()，可使用匯出的 .ctex，不依賴開發工作樹內的 PNG 原始檔。

實測與限制見 prototype/reports/actors/REPORT.md；新增衣裝、背面與動作仍待使用者審美確認。
