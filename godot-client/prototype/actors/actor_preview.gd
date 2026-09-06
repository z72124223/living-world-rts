extends Node2D
## Standalone wardrobe and four-direction motion preview. Actor positions are
## owned here; the shared actor only receives velocity and equipment.

const CharacterActor = preload("res://prototype/actors/character_actor.gd")
const Acceptance = preload("res://prototype/actors/actor_acceptance.gd")
const DIRECTIONS := ["sw", "se", "nw", "ne"]
const DIRECTION_NAMES := ["西南 ↙", "東南 ↘", "西北 ↖", "東北 ↗"]
const VECTORS := [Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]
const COLORS := {"ink": Color("e8ebe3"), "muted": Color("90a9aa"), "accent": Color("9ed8ba"), "gold": Color("e1c18a")}

var actors: Array[Node2D] = []
var actor_root: Node2D
var ui: Control
var font: Font
var motion := "idle"
var loadout := {"clothing": "cloth", "armor": "chest", "weapon": "sword"}
var selected_index := 0
var auto_demo := false
var demo_time := 0.0
var status_label: Label
var detail_label: Label
var caption_label: Label
var motion_buttons: Dictionary = {}
var equipment_buttons: Dictionary = {}
var gallery_labels: Array[Control] = []
var demo_button: Button
var benchmark_mode := false
var verification_mode := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0e191e"))
	font = load("res://assets/ui-font.otf")
	actor_root = Node2D.new()
	actor_root.name = "Actors"
	add_child(actor_root)
	_build_actors()
	_build_ui()
	apply_motion("idle")
	select_actor(0)
	var args := OS.get_cmdline_user_args()
	if "--verify" in args or "--verify-actors" in args:
		verification_mode = true
		var verifier: Node = Acceptance.new()
		add_child(verifier)
		verifier.call_deferred("run", self)


func _build_actors() -> void:
	for row in range(2):
		for column in range(4):
			var actor: Node2D = CharacterActor.new()
			actor.name = "%s_%s" % ["male" if row == 0 else "female", DIRECTIONS[column]]
			actor.position = Vector2(145 + column * 216, 372 + row * 275)
			actor.scale = Vector2.ONE * 2.6
			actor_root.add_child(actor)
			actor.configure({"id": actor.name, "name": "男性" if row == 0 else "女性", "gender": "male" if row == 0 else "female", "loadout": loadout.duplicate()})
			actors.append(actor)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	_label("角色工坊", Vector2(30, 20), 32, COLORS.ink)
	_label("四斜向衣裝與動作", Vector2(194, 34), 18, COLORS.accent)
	_label("已確認身形 · 獨立衣服、胸甲與佩劍", Vector2(32, 70), 15, COLORS.muted)
	_label("原型 / 01", Vector2(801, 32), 14, COLORS.gold)
	gallery_labels.append(_label("男性", Vector2(33, 128), 18, COLORS.gold))
	gallery_labels.append(_label("女性", Vector2(33, 403), 18, COLORS.gold))
	for row in range(2):
		for column in range(4):
			var index := row * 4 + column
			gallery_labels.append(_label(DIRECTION_NAMES[column], Vector2(80 + column * 216, 169 + row * 275), 15, COLORS.muted))
			var area := Button.new()
			area.position = Vector2(36 + column * 216, 205 + row * 275)
			area.size = Vector2(210, 176)
			area.flat = true
			area.focus_mode = Control.FOCUS_NONE
			area.modulate = Color(1, 1, 1, 0)
			area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			area.pressed.connect(func(): select_actor(index))
			ui.add_child(area)
	_label("預覽控制", Vector2(953, 35), 24, COLORS.ink)
	_label("動作", Vector2(954, 92), 15, COLORS.muted)
	var motion_keys := ["idle", "walk", "run"]
	var motion_titles := ["站立 1", "步行 2", "跑步 3"]
	for index in range(3):
		var key: String = motion_keys[index]
		motion_buttons[key] = _button(motion_titles[index], Rect2(954 + index * 96, 124, 90, 43), func(): auto_demo = false; apply_motion(key))
	_label("分層穿戴", Vector2(954, 203), 15, COLORS.muted)
	equipment_buttons.clothing = _button("", Rect2(954, 236, 282, 44), func(): toggle_equipment("clothing"))
	equipment_buttons.armor = _button("", Rect2(954, 290, 282, 44), func(): toggle_equipment("armor"))
	equipment_buttons.weapon = _button("", Rect2(954, 344, 282, 44), func(): toggle_equipment("weapon"))
	demo_button = _button("自動巡覽 · 空白鍵", Rect2(954, 427, 282, 43), func(): auto_demo = not auto_demo; demo_time = 0.0; refresh_labels())
	_label("選取角色", Vector2(954, 505), 15, COLORS.muted)
	detail_label = _label("", Vector2(954, 538), 16, COLORS.ink)
	detail_label.size = Vector2(282, 108)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label("點選人物查看資料\nC 衣服　A 胸甲　S 佩劍", Vector2(954, 670), 14, COLORS.muted)
	status_label = _label("", Vector2(33, 713), 17, COLORS.accent)
	caption_label = _label("新背面、衣裝與動作仍待使用者審美確認。", Vector2(33, 747), 14, COLORS.muted)
	refresh_labels()


func _label(text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	ui.add_child(label)
	return label


func _button(text: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", COLORS.ink)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("21393d") if state == "normal" else Color("385952")
		style.border_color = Color("466367")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	ui.add_child(button)
	return button


func apply_motion(next_motion: String) -> void:
	motion = next_motion
	for index in range(actors.size()):
		var velocity: Vector2 = VECTORS[index % 4].normalized() * (56.0 if motion == "run" else 32.0)
		actors[index].set_motion(velocity)
		if motion == "idle":
			actors[index].set_motion(Vector2.ZERO)
	refresh_labels()


func apply_loadout(next_loadout: Dictionary) -> void:
	loadout = next_loadout.duplicate()
	for actor in actors:
		actor.set_equipment(loadout.duplicate())
	refresh_labels()


func toggle_equipment(key: String) -> void:
	var enabled_value: String = {"clothing": "cloth", "armor": "chest", "weapon": "sword"}[key]
	loadout[key] = "none" if loadout[key] == enabled_value else enabled_value
	apply_loadout(loadout)


func select_actor(index: int) -> void:
	selected_index = index
	for current in range(actors.size()):
		actors[current].set_selected(current == index)
	refresh_labels()
	queue_redraw()


func refresh_labels() -> void:
	if not is_instance_valid(status_label):
		return
	var motion_names := {"idle": "站立", "walk": "步行", "run": "跑步"}
	for key in motion_buttons:
		motion_buttons[key].modulate = COLORS.accent if motion == key else Color.WHITE
	equipment_buttons.clothing.text = "衣服 · %s    C" % ("穿著" if loadout.clothing == "cloth" else "卸下")
	equipment_buttons.armor.text = "胸甲 · %s    A" % ("穿著" if loadout.armor == "chest" else "卸下")
	equipment_buttons.weapon.text = "佩劍 · %s    S" % ("裝備" if loadout.weapon == "sword" else "卸下")
	demo_button.text = "停止巡覽 · 空白鍵" if auto_demo else "自動巡覽 · 空白鍵"
	status_label.text = "四向同步 · %s　｜　8 名角色　｜　足點固定" % motion_names[motion]
	if benchmark_mode:
		status_label.text = "32 名角色同畫面 · GPU 實際繪製與影格計時"
	var state: Dictionary = actors[selected_index].get_visual_state()
	detail_label.text = "%s · %s\n%s / 第 %s 格\n世界高度 %s px" % ["男性" if state.get("gender") == "male" else "女性", DIRECTION_NAMES[selected_index % 4], motion_names.get(str(state.get("motion", "idle")), "站立"), state.get("frame", 0), state.get("world_height", 64)]


func set_benchmark_view(enabled: bool) -> void:
	benchmark_mode = enabled
	actor_root.visible = not enabled
	# Hidden actors must not pollute the 32-actor CPU sample.
	actor_root.process_mode = Node.PROCESS_MODE_DISABLED if enabled else Node.PROCESS_MODE_INHERIT
	for label in gallery_labels:
		label.visible = not enabled
	queue_redraw()
	refresh_labels()


func _process(delta: float) -> void:
	if auto_demo and not verification_mode:
		demo_time += delta
		if demo_time >= 3.0:
			demo_time = 0.0
			apply_motion({"idle": "walk", "walk": "run", "run": "idle"}[motion])
	if not benchmark_mode:
		refresh_labels()


func _unhandled_key_input(event: InputEvent) -> void:
	if verification_mode or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1: auto_demo = false; apply_motion("idle")
		KEY_2: auto_demo = false; apply_motion("walk")
		KEY_3: auto_demo = false; apply_motion("run")
		KEY_C: toggle_equipment("clothing")
		KEY_A: toggle_equipment("armor")
		KEY_S: toggle_equipment("weapon")
		KEY_SPACE: auto_demo = not auto_demo; demo_time = 0.0
	refresh_labels()


func _draw() -> void:
	draw_rect(Rect2(928, 0, 352, 800), Color("14252a"))
	draw_line(Vector2(927, 0), Vector2(927, 800), Color("365055"), 1)
	draw_line(Vector2(32, 107), Vector2(888, 107), Color("33494e"), 1)
	if benchmark_mode:
		for row in range(4):
			for column in range(8):
				_draw_floor_ellipse(Vector2(89 + column * 109, 257 + row * 139), Vector2(29, 10), Color("1c3338"))
		return
	for row in range(2):
		for column in range(4):
			var panel := Rect2(35 + column * 216, 159 + row * 275, 206, 231)
			draw_style_box(_panel_style(row * 4 + column == selected_index), panel)
			_draw_floor_ellipse(Vector2(145 + column * 216, 374 + row * 275), Vector2(56, 13), Color("0d1b21"))
			draw_line(Vector2(100 + column * 216, 374 + row * 275), Vector2(190 + column * 216, 374 + row * 275), Color("466264"), 1)
			draw_line(Vector2(145 + column * 216, 370 + row * 275), Vector2(145 + column * 216, 378 + row * 275), Color("668b87"), 1)


func _draw_floor_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(33):
		var angle := TAU * float(index) / 32.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)


func _panel_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b3034") if selected else Color("17282e")
	style.border_color = Color("87b69e") if selected else Color("2a444a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
