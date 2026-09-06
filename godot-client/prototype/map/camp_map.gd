extends Node2D
## Rendering and navigation share the same physical obstacle rectangles.
const SIZE := Vector2(2048, 1536)
const CELL := 32
const CLEARANCE := 12.0
var points: Dictionary = {}
var grid := AStarGrid2D.new()
var obstacles: Array[Rect2] = []
var props: Array[Dictionary] = []
var ground_paths: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(160, 848), Vector2(592, 848), Vector2(720, 784), Vector2(1040, 784), Vector2(1712, 848), Vector2(1936, 848)]),
	PackedVector2Array([Vector2(1040, 784), Vector2(1072, 624), Vector2(1040, 304)]),
	PackedVector2Array([Vector2(336, 848), Vector2(336, 1200), Vector2(624, 1392)])]

func _ready() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://prototype/map/map_config.json"))
	for key in config.event_positions:
		var p: Array = config.event_positions[key]
		points[key] = Vector2(p[0],p[1])
	grid.region = Rect2i(0, 0, 64, 48)
	grid.cell_size = Vector2(32, 32)
	grid.offset = Vector2(16, 16)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	_add_prop("tent", Rect2(128, 576, 160, 96))
	_add_prop("tent", Rect2(432, 576, 160, 96))
	_add_prop("crate", Rect2(176, 976, 64, 48))
	_add_prop("crate", Rect2(464, 992, 64, 48))
	_add_prop("wall", Rect2(832, 448, 64, 272))
	_add_prop("wall", Rect2(832, 864, 64, 256))
	_add_prop("rock", Rect2(1312, 448, 128, 80))
	_add_prop("rock", Rect2(1472, 608, 96, 80))
	_add_prop("pond", Rect2(1248, 1088, 416, 224))
	var rng := RandomNumberGenerator.new()
	rng.seed = 61226
	for i in range(145):
		var p := Vector2(rng.randi_range(64, 1984), rng.randi_range(96, 1472)).snapped(Vector2(16, 16))
		if Rect2(64, 128, 608, 976).has_point(p) or _on_path(p, 135) or _near_event(p, 160):
			continue
		var area := Rect2(p - Vector2(20, 16), Vector2(40, 32))
		var overlaps := false
		for rect in obstacles:
			if rect.grow(48).intersects(area): overlaps = true
		if not overlaps: _add_prop("tree", area)
	_rebuild_grid()
	queue_redraw()

func _add_prop(kind: String, rect: Rect2) -> void:
	obstacles.append(rect)
	props.append({"kind": kind, "rect": rect})

func _near_event(p: Vector2, radius: float) -> bool:
	for target in points.values():
		if p.distance_to(target) < radius: return true
	return false

func _on_path(p: Vector2, width: float) -> bool:
	for line in ground_paths:
		for i in range(line.size() - 1):
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])) < width: return true
	return false

func _rebuild_grid() -> void:
	for y in range(48):
		for x in range(64):
			var cell := Vector2i(x, y)
			var p := Vector2(cell) * 32 + Vector2(16, 16)
			var blocked := not walkable(p)
			for rect in obstacles:
				if Rect2(p-Vector2(16,16),Vector2(32,32)).intersects(rect.grow(CLEARANCE+0.5)): blocked=true
			grid.set_point_solid(cell, blocked)

func walkable(p: Vector2) -> bool:
	if not Rect2(Vector2(32, 32), SIZE - Vector2(64, 64)).has_point(p): return false
	for rect in obstacles:
		if rect.grow(CLEARANCE).has_point(p): return false
	return true

func segment_clear(a: Vector2, b: Vector2) -> bool:
	if not walkable(a) or not walkable(b): return false
	for rect in obstacles:
		var safe := rect.grow(CLEARANCE + 0.5)
		var corners := [safe.position, Vector2(safe.end.x,safe.position.y),safe.end,Vector2(safe.position.x,safe.end.y)]
		if safe.has_point(a) or safe.has_point(b): return false
		for i in range(4):
			if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])!=null: return false
	return true

func cell_for(p: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(p.x / 32), 1, 62), clampi(floori(p.y / 32), 1, 46))

func nearest_free(p: Vector2, reserved: Array[Vector2] = []) -> Vector2:
	var origin := cell_for(p)
	var best := Vector2(-1, -1)
	var best_distance := INF
	for radius in range(12):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var cell := origin + Vector2i(x, y)
				if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell): continue
				var candidate := grid.get_point_position(cell)
				var occupied := false
				for other in reserved:
					if candidate.distance_to(other) < 31: occupied = true
				if occupied: continue
				var distance := candidate.distance_squared_to(p)
				if distance < best_distance:
					best = candidate
					best_distance = distance
		if best.x >= 0: break
	return best

func route(start: Vector2, target: Vector2) -> PackedVector2Array:
	var from := cell_for(start)
	var to := cell_for(target)
	if not walkable(start) or grid.is_point_solid(to): return PackedVector2Array()
	if grid.is_point_solid(from) or not segment_clear(start,grid.get_point_position(from)):
		# Stopping beside a corner can leave a valid position in a blocked centre cell.
		# Find a visible grid entry without ever teleporting the authority position.
		var found := false
		for radius in range(1,4):
			for y in range(-radius,radius+1):
				for x in range(-radius,radius+1):
					var candidate := cell_for(start)+Vector2i(x,y)
					if not grid.is_in_boundsv(candidate) or grid.is_point_solid(candidate): continue
					if segment_clear(start,grid.get_point_position(candidate)):
						from=candidate
						found=true
						break
				if found: break
			if found: break
		if not found: return PackedVector2Array()
	# Physical corners are checked after A*, not merely tile adjacency.
	var raw := grid.get_point_path(from, to)
	if raw.is_empty(): return raw
	var result := PackedVector2Array([start])
	for p in raw:
		if result[-1].distance_to(p) < 0.1: continue
		if not segment_clear(result[-1], p): return PackedVector2Array()
		result.append(p)
	# Greedy line-of-sight smoothing retains the shared 12 px body clearance.
	var smooth := PackedVector2Array([start])
	var cursor := 0
	while cursor < result.size() - 1:
		var next := result.size() - 1
		while next > cursor + 1 and not segment_clear(result[cursor], result[next]): next -= 1
		smooth.append(result[next])
		cursor = next
	return smooth

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("354b3b"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 937
	var greens := [Color("3c513e"), Color("405541"), Color("435740"), Color("394e3c")]
	for y in range(48):
		for x in range(64):
			var p := Vector2(x * 32, y * 32)
			draw_rect(Rect2(p, Vector2(32, 32)), greens[rng.randi_range(0, 3)])
			var leaf := p + Vector2(rng.randi_range(0, 24), rng.randi_range(0, 24))
			draw_rect(Rect2(leaf, Vector2(3, 6)), Color("506349"))
			if rng.randf() < 0.15: draw_rect(Rect2(leaf + Vector2(8, 0), Vector2(3, 3)), Color("a9a276"))
	for line in ground_paths:
		draw_polyline(line, Color("525742"), 148, false)
		draw_polyline(line, Color("726c4e"), 112, false)
		draw_polyline(line, Color("7d7455"), 80, false)
	for i in range(1900):
		var p := Vector2(rng.randi_range(48, 2000), rng.randi_range(48, 1488))
		if _on_path(p, 55): draw_rect(Rect2(p.snapped(Vector2(4, 4)), Vector2(rng.randi_range(4, 10), 3)), Color("8e805f"))
	# Camp clearing, hearth and supply ring are deliberately walkable.
	draw_circle(points["return-camp"], 124, Color("807858"))
	draw_circle(points["return-camp"], 108, Color("8e805f"))
	for i in range(14):
		var p: Vector2 = points["return-camp"] + Vector2.from_angle(i * TAU / 14) * 112
		draw_rect(Rect2(p, Vector2(10, 6)), Color("a29a76"))
	draw_rect(Rect2(0, 0, 2048, 1536), Color("202f2b"), false, 28)
