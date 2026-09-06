extends Node2D
## Pure presentation actor. Caller owns position, routes, identity and persistence.
## Independent Aseprite layers are composited through a bounded shared frame cache.
## Cropped frames keep the original (96, 168) canvas foot point, at 0.5 scale.

const FrameCache = preload("res://prototype/actors/actor_frame_cache.gd")
const DIRECTIONS := ["sw", "se", "nw", "ne"]
const COUNTS := {"idle": 4, "walk": 8, "run": 8}
const OFFSETS := {"idle": 0, "walk": 4, "run": 12}
const FPS := {"idle": 4.0, "walk": 8.0, "run": 12.0}
var identity: Dictionary = {}
var gender := "female"
var loadout := {"clothing": "cloth", "armor": "none", "weapon": "none"}
var direction := "sw"
var motion := "idle"
var _clock := 0.0
var _playback_speed := 1.0
var _preview_frame := -1
var _selected := false
var _visual_scale := 1.0
var _sprite: Sprite2D
var _texture_path := ""
var _frame_key := ""

func _enter_tree() -> void:
	# A removed actor releases its visible frame; reattaching can reuse the LRU.
	_update_frame()

func _ready() -> void:
	_ensure_sprite()
	_apply_texture()
	_update_frame()

func _ensure_sprite() -> void:
	if is_instance_valid(_sprite):
		return
	_sprite = Sprite2D.new()
	_sprite.name = "CompositedCharacter"
	_sprite.centered = false
	_sprite.hframes = 1
	_sprite.vframes = 1
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
	var layout: Dictionary = FrameCache.gender_layout(gender)
	var anchor: Array = layout.get("anchor", [96, 168])
	_sprite.scale = Vector2.ONE * _visual_scale * 0.5
	_sprite.position = -Vector2(float(anchor[0]), float(anchor[1])) * _visual_scale * 0.5
	queue_redraw()

func set_motion(velocity: Vector2) -> void:
	var speed := velocity.length()
	var next_motion := "idle" if speed < 0.1 else ("run" if speed >= 44.0 else "walk")
	if next_motion != motion:
		motion = next_motion
		_clock = 0.0
	# Match the stride clock to the caller's actual speed, including slower
	# route segments. Previewing a frozen frame never advances this clock.
	_playback_speed = 1.0 if motion == "idle" else speed / (56.0 if motion == "run" else 32.0)
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

func set_preview_frame(local_index: int) -> void:
	_preview_frame = -1 if local_index < 0 else local_index % int(COUNTS[motion])
	_update_frame()

func _apply_texture() -> void:
	_frame_key = ""
	_apply_scale()

func _process(delta: float) -> void:
	if _preview_frame < 0:
		_clock += delta * _playback_speed
	_update_frame()

func _exit_tree() -> void:
	if is_instance_valid(_sprite):
		_sprite.texture = null
	_frame_key = ""
	FrameCache.release_actor(get_instance_id())

func _local_frame() -> int:
	if _preview_frame >= 0:
		return _preview_frame % int(COUNTS[motion])
	return int(_clock * float(FPS[motion])) % int(COUNTS[motion])

func _update_frame() -> void:
	if not is_instance_valid(_sprite):
		return
	var column := int(OFFSETS[motion]) + _local_frame()
	var row := DIRECTIONS.find(direction)
	var key: String = FrameCache.frame_key(gender, loadout, column, row)
	if key == _frame_key:
		return
	var texture: Texture2D = FrameCache.acquire(gender, loadout, column, row)
	if texture == null:
		return
	_sprite.texture = texture
	_frame_key = key
	_texture_path = "composite://" + key
	FrameCache.track_actor(self, texture)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38) * _visual_scale)
	draw_circle(Vector2.ZERO, 12.0, Color(0.02, 0.025, 0.025, 0.28))
	if _selected:
		draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 32, Color("9cdec6"), 1.5, false)
	draw_set_transform(Vector2.ZERO)

func get_visual_state() -> Dictionary:
	var frame_index := _local_frame()
	var column := int(OFFSETS[motion]) + frame_index
	var layout: Dictionary = FrameCache.gender_layout(gender)
	return {"gender": gender, "direction": direction, "direction_index": DIRECTIONS.find(direction),
		"atlas_row": DIRECTIONS.find(direction), "motion": motion, "frame": column,
		"source_frame": DIRECTIONS.find(direction) * 20 + column, "texture": _texture_path,
		"source_rect": [column * 192, DIRECTIONS.find(direction) * 192, 192, 192],
		"source_manifest": FrameCache.MANIFEST_PATH, "composite_crop": layout.get("crop", []),
		"composite_anchor": layout.get("anchor", []), "playback_speed": _playback_speed,
		"preview_frame": _preview_frame,
		"loadout": loadout.duplicate(), "selected": _selected,
		"source_height": 239 if gender == "male" else 229,
		"world_height": 64.0 * _visual_scale, "foot_anchor": [0, 0], "runtime_mesh_vertices": 4,
		"direction_art_status": "new_turns_and_clothing_await_user_review"}

static func get_cache_stats() -> Dictionary:
	return FrameCache.stats()
