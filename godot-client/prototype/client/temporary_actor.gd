extends Node2D
## Explicit temporary display of approved PNG. No clothing/animation approval implied.
var data: Dictionary = {}
var chosen := false
var sprite := Sprite2D.new()
var label := Label.new()

func configure(value: Dictionary) -> void:
	data = value.duplicate(true)
	if sprite.get_parent() == null:
		add_child(sprite)
		add_child(label)
		label.add_theme_font_override("font", load("res://assets/ui-font.otf"))
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_shadow_color", Color("192b28"))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	var path := "res://assets/body-v03-preview.png" if value.get("gender", "female") == "female" else "res://assets/male-body-v01-preview.png"
	sprite.texture = load(path)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * (64.0 / 228.0)
	sprite.position = Vector2(0, -34)
	label.text = str(data.get("name", data.get("id", "")))
	label.position = Vector2(-30, 12)
	queue_redraw()

func set_motion(_velocity: Vector2) -> void:
	pass

func set_equipment(loadout: Dictionary) -> void:
	data["loadout"] = loadout.duplicate(true)
	queue_redraw()

func set_selected(value: bool) -> void:
	chosen = value
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 17, Color(0.05, 0.1, 0.08, 0.5))
	if chosen: draw_arc(Vector2.ZERO, 22, 0, TAU, 32, Color("e8cc7f"), 3)
	draw_set_transform(Vector2.ZERO)
	# Small status marks communicate an equipment command, not finished armour art.
	var loadout: Dictionary = data.get("loadout", {})
	if loadout.get("armor", "none") == "chest": draw_rect(Rect2(-5, -73, 5, 5), Color("aac2c6"))
	if loadout.get("weapon", "none") == "sword": draw_rect(Rect2(3, -73, 5, 5), Color("dfbb75"))
