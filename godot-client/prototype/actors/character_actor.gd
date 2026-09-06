extends Node2D
## Pure presentation actor. Caller owns position, routes, identity and persistence.
## 2x Aseprite-exported RGBA frames preserve source detail when the camera zooms.
## A common foot anchor (96, 168) is displayed at 0.5 scale, for ~64 world pixels.

const CELL := Vector2(192, 192)
const ANCHOR := Vector2(96, 168)
const DIRECTIONS := ["sw", "se", "nw", "ne"]
const COUNTS := {"idle": 4, "walk": 8, "run": 8}
const OFFSETS := {"idle": 0, "walk": 4, "run": 12}
const FPS := {"idle": 4.0, "walk": 8.0, "run": 12.0}
static var _texture_cache: Dictionary = {}
var identity: Dictionary = {}
var gender := "female"
var loadout := {"clothing": "cloth", "armor": "none", "weapon": "none"}
var direction := "sw"
var motion := "idle"
var _clock := 0.0
var _selected := false
var _visual_scale := 1.0
var _sprite: Sprite2D
var _texture_path := ""

func _ready() -> void:
	_ensure_sprite()
	_apply_texture()
	_update_frame()

func _ensure_sprite() -> void:
	if is_instance_valid(_sprite):
		return
	_sprite = Sprite2D.new()
	_sprite.name = "BakedCharacter"
	_sprite.centered = false
	_sprite.hframes = 20
	_sprite.vframes = 4
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_apply_scale()

func configure(data: Dictionary) -> void:
	identity = data.duplicate(true)
	gender = "male" if str(data.get("gender", "female")) == "male" else "female"
	_visual_scale = clampf(float(data.get("visual_scale", 1.0)), 0.1, 8.0)
	_ensure_sprite()
	_apply_scale()
	set_equipment(data.get("loadout", loadout))

func _apply_scale() -> void:
	_sprite.scale = Vector2.ONE * _visual_scale * 0.5
	_sprite.position = -ANCHOR * _visual_scale * 0.5
	queue_redraw()

func set_motion(velocity: Vector2) -> void:
	var speed := velocity.length()
	var next_motion := "idle" if speed < 0.1 else ("run" if speed >= 44.0 else "walk")
	if next_motion != motion:
		motion = next_motion
		_clock = 0.0
	if speed >= 0.1:
		# Cardinal headings deliberately resolve to the closest available diagonal.
		# A stop never resets the last facing direction.
		direction = ("s" if velocity.y >= 0.0 else "n") + ("e" if velocity.x > 0.0 else "w")
	_update_frame()

func set_equipment(equipment: Dictionary) -> void:
	if equipment.has("clothing"):
		loadout.clothing = "none" if str(equipment.clothing) == "none" else "cloth"
	if equipment.has("armor"):
		loadout.armor = "chest" if str(equipment.armor) == "chest" else "none"
	if equipment.has("weapon"):
		loadout.weapon = "sword" if str(equipment.weapon) == "sword" else "none"
	_ensure_sprite()
	_apply_texture()
	_update_frame()

func set_selected(selected: bool) -> void:
	_selected = selected
	queue_redraw()

func set_preview_direction(value: String) -> void:
	if value in DIRECTIONS:
		direction = value
	_update_frame()

func _apply_texture() -> void:
	var key := ("1" if loadout.clothing == "cloth" else "0") + ("1" if loadout.armor == "chest" else "0") + ("1" if loadout.weapon == "sword" else "0")
	_texture_path = "res://prototype/actors/atlases/%s-%s.png" % [gender, key]
	if not _texture_cache.has(_texture_path):
		_texture_cache[_texture_path] = load(_texture_path)
	_sprite.texture = _texture_cache[_texture_path]

func _process(delta: float) -> void:
	_clock += delta
	_update_frame()

func _update_frame() -> void:
	if not is_instance_valid(_sprite):
		return
	var local_frame := int(_clock * float(FPS[motion])) % int(COUNTS[motion])
	_sprite.frame_coords = Vector2i(int(OFFSETS[motion]) + local_frame, DIRECTIONS.find(direction))

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38) * _visual_scale)
	draw_circle(Vector2.ZERO, 12.0, Color(0.02, 0.025, 0.025, 0.28))
	if _selected:
		draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 32, Color("9cdec6"), 1.5, false)
	draw_set_transform(Vector2.ZERO)

func get_visual_state() -> Dictionary:
	var frame_index := int(_clock * float(FPS[motion])) % int(COUNTS[motion])
	var column := int(OFFSETS[motion]) + frame_index
	return {"gender": gender, "direction": direction, "direction_index": DIRECTIONS.find(direction),
		"atlas_row": DIRECTIONS.find(direction), "motion": motion, "frame": column,
		"source_frame": DIRECTIONS.find(direction) * 20 + column, "texture": _texture_path,
		"source_rect": [column * 192, DIRECTIONS.find(direction) * 192, 192, 192],
		"loadout": loadout.duplicate(), "selected": _selected,
		"source_height": 239 if gender == "male" else 229,
		"world_height": 64.0 * _visual_scale, "foot_anchor": [0, 0], "runtime_mesh_vertices": 4,
		"direction_art_status": "new_turns_and_clothing_await_user_review"}
