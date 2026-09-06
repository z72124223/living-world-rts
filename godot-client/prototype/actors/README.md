# 四斜向人物原型

`character_actor.gd` 是 Node2D 呈現元件。客戶端管理 `position`、人物 ID、尋路與存檔；腳點固定在局部 `(0,0)`。本元件不修改世界資料。

```gdscript
const CharacterActor = preload("res://prototype/actors/character_actor.gd")
var actor = CharacterActor.new()
add_child(actor)
actor.configure({"id": "person-1", "name": "人物甲", "gender": "female",
    "loadout": {"clothing": "cloth", "armor": "chest", "weapon": "sword"}})
actor.position = Vector2(256, 256)
actor.set_motion(Vector2(-1, 1).normalized() * 32.0)
actor.set_equipment({"armor": "none"})
actor.set_selected(true)
```

- `configure(data: Dictionary)`：接受 `male`／`female`。可選 `visual_scale` 預設 1；不改父節點或呼叫端的 `scale`。
- `set_motion(velocity: Vector2)`：速度小於 0.1 站立，0.1–44 步行，44 以上跑步。預設世界速度 32／56。停步保留方向；四個象限對應 `sw/se/nw/ne`，正交方向映射到可用斜向，沒有宣稱八方向完成。
- `set_equipment(loadout: Dictionary)`：可局部更新。衣服 `cloth/none`、胸甲 `chest/none`、佩劍 `sword/none`。
- `set_selected(selected: bool)`：只繪製足底選取圈。
- 預覽輔助：`set_preview_direction("nw")`、`get_visual_state()`。

遊戲高度約 64 世界像素。原生影格 192×192，以 0.5 倍顯示；2 倍素材保留放大時的臉部細節。圖集為 20 欄×4 列：每列 `idle 0–3 / walk 4–11 / run 12–19`，列為 `sw/se/nw/ne`。四向有獨立臉髮、前後衣甲接縫和佩劍側邊，不使用 Sprite2D flip。

每個性別有 8 組已合成穿戴圖集，名稱三位數依序是衣服、胸甲、佩劍，例如 `female-101.png`。貼圖在角色間共用；遊戲中每人只需 1 個 Sprite2D，沒有原始數千頂點人體網格。全部 16 張圖集的未壓縮 RGBA 像素約 180 MiB，依已使用組合載入並快取；目前沒有設定大型人群或低記憶體容量承諾。

獨立预覽：

```powershell
godot --path godot-client res://prototype/actors/actor_preview.tscn
```

快捷鍵 `1/2/3` 站立／步行／跑步，`C/A/S` 衣服／胸甲／佩劍，空白鍵巡覽。此場景不改主場景設定。

原始素材和再製流程見 `pixel-assets/prototype-actors/README.md`；實測見 `prototype/reports/actors/REPORT.md`。新增衣裝、背面和動作仍待使用者審美確認。
