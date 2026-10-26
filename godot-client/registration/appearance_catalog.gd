extends RefCounted
## Server-owned IDs only. Never load a resource path supplied by an account or child.
const PORTRAITS := {
	"arrival-male": {"sex": "M", "texture": preload("res://registration/assets/arrival-male.png")},
	"arrival-female": {"sex": "F", "texture": preload("res://registration/assets/arrival-female.png")},
	"settlement-female-01": {"sex": "F", "texture": preload("res://registration/assets/settlement-female-01.png")},
}

static func resolve(appearance_id: Variant, sex: Variant) -> Texture2D:
	if not appearance_id is String or not sex is String:
		return null
	var appearance: Dictionary = PORTRAITS.get(appearance_id, {})
	if appearance.get("sex", "") != sex:
		return null
	return appearance.get("texture")

static func presentation(account: Dictionary, draft_entry: String) -> Dictionary:
	var character: Variant = account.get("character")
	if character is Dictionary:
		if character.get("state", "") != "active":
			return {"texture": null, "caption": "角色已停用", "message": "此角色目前無法使用。"}
		var texture := resolve(character.get("appearance"), character.get("sex"))
		if account.get("sex") != character.get("sex"):
			texture = null
		if texture == null:
			return {"texture": null, "caption": "角色外貌暫無法顯示", "message": "外貌資料或素材尚未備妥。\n角色登記資料保持不變。"}
		return {
			"texture": texture,
			"caption": "沿用子女外貌　・　不可調整" if character.get("entry") == "reincarnation" else "首次傳送　・　外貌不可調整",
			"message": "",
		}
	if draft_entry == "reincarnation":
		return {"texture": null, "caption": "配對後沿用子女姓名與外貌", "message": "等待入世配對\n\n確認入世後隨機接手合適的子女，\n在此顯示對方既有的模樣。"}
	if account.get("identity") != "verified":
		return {"texture": resolve("arrival-male", "M"), "caption": "角色示意　・　等待實名查核", "message": ""}
	var sex: Variant = account.get("sex")
	return {"texture": resolve("arrival-female" if sex == "F" else "arrival-male", sex), "caption": "首次傳送　・　外貌不可調整", "message": ""}
