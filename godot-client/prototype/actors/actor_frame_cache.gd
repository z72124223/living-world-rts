extends RefCounted
## Shared frame compositor. Only independent layer Images stay resident on the CPU.
## The GPU cache holds at most 64 cropped frames / 8 MiB, whichever limit is first.
## A Sprite2D can keep an evicted frame alive; stats count those references separately.

const MANIFEST_PATH := "res://prototype/actors/layers/manifest.json"
const CAPACITY_ENTRIES := 64
const CAPACITY_BYTES := 8 * 1024 * 1024

static var _manifest: Dictionary = {}
static var _manifest_attempted := false
static var _sources: Dictionary = {}
static var _cache: Dictionary = {}
static var _live_textures: Dictionary = {}
static var _actors: Dictionary = {}
static var _tick := 0
static var _bytes := 0
static var _peak_bytes := 0
static var _hits := 0
static var _misses := 0
static var _evictions := 0
static var _source_cpu_bytes := 0
static var _source_texture_largest_bytes := 0
static var _source_texture_upload_total_bytes := 0
static var _peak_frame_texture_count := 0
static var _peak_frame_texture_bytes := 0

static func gender_layout(gender: String) -> Dictionary:
	if not _manifest_attempted:
		_manifest_attempted = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary and int(parsed.get("version", 0)) == 2:
			_manifest = parsed
		else:
			push_error("Actor layer manifest is missing or is not version 2: " + MANIFEST_PATH)
	var genders: Dictionary = _manifest.get("genders", {})
	return genders.get(gender, {})

static func frame_key(gender: String, loadout: Dictionary, column: int, row: int) -> String:
	var equipment := ("1" if loadout.get("clothing", "none") == "cloth" else "0")
	equipment += "1" if loadout.get("armor", "none") == "chest" else "0"
	equipment += "1" if loadout.get("weapon", "none") == "sword" else "0"
	return "%s/%s/%d/%d" % [gender, equipment, column, row]

static func _load_sources(gender: String) -> bool:
	if _sources.has(gender):
		return true
	var layout := gender_layout(gender)
	if layout.is_empty():
		return false
	var layers: Array = []
	var total_bytes := 0
	for definition: Dictionary in layout.get("layers", []):
		var path := str(definition.get("path", ""))
		# Imported .ctex resources work both in the editor and in exported projects.
		# Ignore the ResourceLoader cache, then release the source GPU resource after
		# readback. The retained Image is CPU-only; no layer Texture2D is saved here.
		var imported := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if imported == null:
			push_error("Unable to read actor layer: " + path)
			return false
		var source := imported.get_image()
		if source == null or source.is_empty():
			push_error("Actor layer has no readable Image: " + path)
			return false
		var upload_bytes := source.get_data().size()
		_source_texture_largest_bytes = maxi(_source_texture_largest_bytes, upload_bytes)
		_source_texture_upload_total_bytes += upload_bytes
		imported = null
		if source.is_compressed() and source.decompress() != OK:
			push_error("Unable to decompress actor layer: " + path)
			return false
		if source.get_format() != Image.FORMAT_RGBA8:
			source.convert(Image.FORMAT_RGBA8)
		var part: Array = definition.get("rect", [])
		if part.size() != 4:
			push_error("Actor layer rect must contain x, y, width, height: " + path)
			return false
		var rect := Rect2i(int(part[0]), int(part[1]), int(part[2]), int(part[3]))
		if rect.size.x <= 0 or rect.size.y <= 0 or source.get_width() != rect.size.x * int(layout.get("columns", 20)) or source.get_height() != rect.size.y * int(layout.get("rows", 4)):
			push_error("Actor layer atlas dimensions do not match its frame rect: " + path)
			return false
		layers.append({"image": source, "rect": rect, "slot": str(definition.get("slot", "body"))})
		total_bytes += source.get_data().size()
	if layers.is_empty():
		push_error("Actor layer manifest has no layers for " + gender)
		return false
	_sources[gender] = layers
	_source_cpu_bytes += total_bytes
	return true

static func _slot_enabled(slot: String, loadout: Dictionary) -> bool:
	match slot:
		"body":
			return true
		"clothing":
			return loadout.get("clothing", "none") == "cloth"
		"armor":
			return loadout.get("armor", "none") == "chest"
		"weapon":
			return loadout.get("weapon", "none") == "sword"
	return false

static func acquire(gender: String, loadout: Dictionary, column: int, row: int) -> Texture2D:
	_tick += 1
	var key := frame_key(gender, loadout, column, row)
	if _cache.has(key):
		_hits += 1
		_cache[key].used = _tick
		return _cache[key].texture
	_misses += 1
	if not _load_sources(gender):
		return null
	var layout := gender_layout(gender)
	var crop: Array = layout.get("crop", [0, 0, 192, 192])
	var crop_origin := Vector2i(int(crop[0]), int(crop[1]))
	var image := Image.create(int(crop[2]), int(crop[3]), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for layer: Dictionary in _sources[gender]:
		if not _slot_enabled(layer.slot, loadout):
			continue
		var part: Rect2i = layer.rect
		var source_rect := Rect2i(Vector2i(column * part.size.x, row * part.size.y), part.size)
		image.blend_rect(layer.image, source_rect, part.position - crop_origin)
	var size_bytes := image.get_data().size()
	# Evict before allocating the new GPU frame. Active sprites may still hold
	# a prior frame; those textures are deliberately counted outside the LRU.
	while not _cache.is_empty() and (_cache.size() >= CAPACITY_ENTRIES or _bytes + size_bytes > CAPACITY_BYTES):
		_evict_oldest()
	var texture := ImageTexture.create_from_image(image)
	_live_textures[texture.get_instance_id()] = {"weak": weakref(texture), "bytes": size_bytes}
	if size_bytes <= CAPACITY_BYTES:
		_cache[key] = {"texture": texture, "bytes": size_bytes, "used": _tick}
		_bytes += size_bytes
		_peak_bytes = maxi(_peak_bytes, _bytes)
	_sample_live_textures()
	return texture

static func _evict_oldest() -> void:
	var oldest_key := ""
	var oldest_tick := 9223372036854775807
	for key: String in _cache:
		if int(_cache[key].used) < oldest_tick:
			oldest_tick = int(_cache[key].used)
			oldest_key = key
	_bytes -= int(_cache[oldest_key].bytes)
	_cache.erase(oldest_key)
	_evictions += 1

static func track_actor(actor: Node, texture: Texture2D) -> void:
	if texture == null:
		_actors.erase(actor.get_instance_id())
		return
	_actors[actor.get_instance_id()] = {"weak": weakref(actor), "texture_id": texture.get_instance_id()}

static func release_actor(actor_id: int) -> void:
	_actors.erase(actor_id)

static func _sample_live_textures() -> Dictionary:
	var count := 0
	var size_bytes := 0
	for texture_id: int in _live_textures.keys():
		var record: Dictionary = _live_textures[texture_id]
		if record.weak.get_ref() == null:
			_live_textures.erase(texture_id)
		else:
			count += 1
			size_bytes += int(record.bytes)
	_peak_frame_texture_count = maxi(_peak_frame_texture_count, count)
	_peak_frame_texture_bytes = maxi(_peak_frame_texture_bytes, size_bytes)
	return {"count": count, "bytes": size_bytes}

static func stats() -> Dictionary:
	var live := _sample_live_textures()
	var cached_ids: Dictionary = {}
	for entry: Dictionary in _cache.values():
		cached_ids[entry.texture.get_instance_id()] = true
	var uncached_ids: Dictionary = {}
	for actor_id: int in _actors.keys():
		var record: Dictionary = _actors[actor_id]
		if record.weak.get_ref() == null:
			_actors.erase(actor_id)
		elif not cached_ids.has(record.texture_id):
			uncached_ids[record.texture_id] = true
	var uncached_bytes := 0
	for texture_id: int in uncached_ids:
		if _live_textures.has(texture_id):
			uncached_bytes += int(_live_textures[texture_id].bytes)
	return {
		"capacity_entries": CAPACITY_ENTRIES, "entries": _cache.size(),
		"capacity_bytes": CAPACITY_BYTES, "bytes": _bytes, "peak_bytes": _peak_bytes,
		"hits": _hits, "misses": _misses, "evictions": _evictions,
		"source_cpu_bytes": _source_cpu_bytes, "source_gender_count": _sources.size(),
		"source_gpu_textures_retained": 0,
		"source_texture_largest_bytes": _source_texture_largest_bytes,
		"source_texture_upload_total_bytes": _source_texture_upload_total_bytes,
		# Render-thread destruction can be deferred. This is a conservative sum
		# of all readback uploads, NOT a measured peak of GPU physical memory.
		"source_gpu_transient_upper_bound_bytes": _source_texture_upload_total_bytes,
		"frame_texture_count": live.count, "frame_texture_bytes": live.bytes,
		"peak_frame_texture_count": _peak_frame_texture_count,
		"peak_frame_texture_bytes": _peak_frame_texture_bytes,
		"active_actor_count": _actors.size(),
		"uncached_active_texture_count": uncached_ids.size(),
		"uncached_active_texture_bytes": uncached_bytes,
		"retained_frame_texture_count_upper_bound": CAPACITY_ENTRIES + _actors.size(),
		"transient_frame_texture_count_upper_bound": CAPACITY_ENTRIES + _actors.size() + 1,
		"gpu_byte_measurement": "RGBA image payload estimate; renderer allocation overhead and deferred frees excluded",
		"strategy": "shared cropped-frame GPU LRU; independent source layers retained as CPU Images only"
	}
