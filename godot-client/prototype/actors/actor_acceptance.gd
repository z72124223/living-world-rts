extends Node
## Run with the standalone preview and -- --verify-actors.
## This records functional evidence and a small rendered benchmark. It cannot
## establish subjective art approval or large-scale RTS capacity.

const CharacterActor = preload("res://prototype/actors/character_actor.gd")
const VECTORS := [Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]
const DIRECTIONS := ["sw", "se", "nw", "ne"]

var checks: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var report_dir := ""
var preview: Node2D
var gpu_available := false
var direction_evidence: Array[Dictionary] = []
var equipment_evidence: Array[Dictionary] = []


func run(preview_node: Node2D) -> void:
	preview = preview_node
	report_dir = ProjectSettings.globalize_path("res://").path_join("../prototype/reports/actors").simplify_path()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--actor-report-dir="):
			report_dir = argument.trim_prefix("--actor-report-dir=")
	var directory_error := DirAccess.make_dir_recursive_absolute(report_dir)
	if directory_error != OK:
		push_error("Could not create actor evidence directory: %s" % report_dir)
		get_tree().quit(2)
		return
	gpu_available = DisplayServer.get_name() != "headless"
	await _frames(3)
	await _verify_actor_contract()
	await _verify_equipment()
	await _capture_gallery()
	var performance := await _benchmark()
	preview.set_benchmark_view(false)
	preview.apply_loadout({"clothing": "cloth", "armor": "chest", "weapon": "sword"})
	preview.apply_motion("idle")
	var functional_passed := true
	for check in checks:
		functional_passed = functional_passed and bool(check.passed)
	var captures_passed := gpu_available and not captures.is_empty()
	for capture in captures:
		captures_passed = captures_passed and bool(capture.get("saved", false))
	var report := {
		"schema": "prototype-actor-acceptance/1",
		"timestamp_utc": Time.get_datetime_string_from_system(true, true),
		"passed": functional_passed and captures_passed and bool(performance.get("measured", false)),
		"functional_passed": functional_passed,
		"gpu_capture_passed": captures_passed,
		"environment": _environment(),
		"checks": checks,
		"four_direction_evidence": direction_evidence,
		"equipment_evidence": equipment_evidence,
		"captures": captures,
		"performance": performance,
		"art_approval": "PENDING_USER_REVIEW",
		"limits": ["Rendered sample contains 32 actors, not a large RTS capacity claim.", "Frame intervals include OS scheduling and vertical synchronization. The engine process-time monitor updates coarsely and is not a per-actor CPU profiler.", "Screenshots and structural checks do not replace user approval of new rear views, clothing, and animation."]
	}
	var report_file := FileAccess.open(report_dir.path_join("actor-runtime-report.json"), FileAccess.WRITE)
	if report_file == null:
		push_error("Could not write actor runtime report")
		get_tree().quit(2)
		return
	report_file.store_string(JSON.stringify(report, "\t"))
	report_file.close()
	print("ACTOR_ACCEPTANCE %s | checks=%d | report=%s" % ["PASS" if report.passed else "FAIL", checks.size(), report_dir.path_join("actor-runtime-report.json")])
	print("ACTOR_PERFORMANCE " + JSON.stringify(performance))
	get_tree().quit(0 if report.passed else 1)


func _verify_actor_contract() -> void:
	_check("eight preview actors", preview.actors.size() == 8, preview.actors.size())
	for gender_index in range(2):
		var actor: Node2D = preview.actors[gender_index * 4]
		var expected_gender := "male" if gender_index == 0 else "female"
		var anchor := actor.position
		var original_scale := actor.scale
		var indices: Array[int] = []
		var source_frames: Array[int] = []
		var texture_signatures: Array[String] = []
		for direction_index in range(4):
			actor.set_motion(VECTORS[direction_index].normalized() * 32.0)
			actor.set_motion(Vector2.ZERO)
			await _frames(2)
			var state: Dictionary = actor.get_visual_state()
			var records := _sprite_records(actor)
			indices.append(int(state.get("direction_index", -1)))
			source_frames.append(int(state.get("source_frame", -1)))
			texture_signatures.append(JSON.stringify(records))
			_check("%s %s direction preserved after stopping" % [expected_gender, DIRECTIONS[direction_index]], state.get("direction") == DIRECTIONS[direction_index] and state.get("motion") == "idle", state)
			_check("%s %s uses no mirrored sprite" % [expected_gender, DIRECTIONS[direction_index]], _no_mirror(records), records)
			direction_evidence.append({"gender": expected_gender, "requested_direction": DIRECTIONS[direction_index], "state": state, "sprites": records})
		var sorted_indices := indices.duplicate()
		sorted_indices.sort()
		_check(expected_gender + " four independent atlas rows", sorted_indices == [0, 1, 2, 3], indices)
		_check(expected_gender + " four distinct source frame indices", _unique_count(source_frames) == 4 and not source_frames.has(-1), source_frames)
		_check(expected_gender + " four distinct rendered sprite sources", _unique_count(texture_signatures) == 4 and not _sprite_records(actor).is_empty(), texture_signatures)
		for motion in ["walk", "run"]:
			actor.set_motion(Vector2(1, 1).normalized() * (32.0 if motion == "walk" else 56.0))
			var observed_frames: Array[int] = []
			for sample in range(20):
				await _frames(2)
				var state: Dictionary = actor.get_visual_state()
				observed_frames.append(int(state.get("frame", -1)))
			_check("%s %s animation advances" % [expected_gender, motion], _unique_count(observed_frames) > 1, observed_frames)
			_check("%s speed selects %s" % [expected_gender, motion], actor.get_visual_state().get("motion") == motion, actor.get_visual_state())
		_check(expected_gender + " actor does not own movement", actor.position.is_equal_approx(anchor), {"before": str(anchor), "after": str(actor.position)})
		_check(expected_gender + " actor preserves caller scale", actor.scale.is_equal_approx(original_scale), {"before": str(original_scale), "after": str(actor.scale)})
		actor.set_motion(Vector2.ZERO)
		var final_state: Dictionary = actor.get_visual_state()
		_check(expected_gender + " configured identity and 64px body height", final_state.get("gender") == expected_gender and is_equal_approx(float(final_state.get("world_height", 0)), 64.0), final_state)
		actor.set_selected(true)
		await _frames(1)
		_check(expected_gender + " selection activates", actor.get_visual_state().get("selected", false) == true, actor.get_visual_state())
		actor.set_selected(false)
		_check(expected_gender + " selection clears", actor.get_visual_state().get("selected", true) == false, actor.get_visual_state())
	preview.apply_motion("idle")
	preview.select_actor(0)


func _verify_equipment() -> void:
	for gender_index in range(2):
		var actor: Node2D = preview.actors[gender_index * 4]
		var gender := "male" if gender_index == 0 else "female"
		var signatures: Array[String] = []
		for combination in range(8):
			var equipment := {"clothing": "cloth" if (combination & 1) != 0 else "none", "armor": "chest" if (combination & 2) != 0 else "none", "weapon": "sword" if (combination & 4) != 0 else "none"}
			actor.set_equipment(equipment.duplicate())
			await _frames(2)
			var state: Dictionary = actor.get_visual_state()
			var sprites := _sprite_records(actor)
			signatures.append(JSON.stringify(sprites))
			_check("%s equipment combination %d" % [gender, combination], state.get("loadout", {}) == equipment, state.get("loadout", {}))
			equipment_evidence.append({"gender": gender, "requested": equipment, "actual": state.get("loadout", {}), "visible_sprites": sprites})
		_check(gender + " eight equipment render combinations", _unique_count(signatures) == 8, {"unique_visible_sprite_configurations": _unique_count(signatures)})


func _capture_gallery() -> void:
	var sets := [
		{"name": "01-four-directions-full-equipment", "loadout": {"clothing": "cloth", "armor": "chest", "weapon": "sword"}, "motion": "idle"},
		{"name": "02-clothing-only", "loadout": {"clothing": "cloth", "armor": "none", "weapon": "none"}, "motion": "idle"},
		{"name": "03-base-without-equipment", "loadout": {"clothing": "none", "armor": "none", "weapon": "none"}, "motion": "idle"},
		{"name": "04-four-directions-walk", "loadout": {"clothing": "cloth", "armor": "chest", "weapon": "sword"}, "motion": "walk"},
		{"name": "05-four-directions-run", "loadout": {"clothing": "cloth", "armor": "chest", "weapon": "sword"}, "motion": "run"},
	]
	for configuration in sets:
		preview.apply_loadout(configuration.loadout)
		preview.apply_motion(configuration.motion)
		await _frames(12)
		await _capture(configuration.name)


func _benchmark() -> Dictionary:
	if not gpu_available:
		return {"measured": false, "reason": "NOT_RUN: headless display does not prove rendered actor performance."}
	preview.set_benchmark_view(true)
	var crowd := Node2D.new()
	crowd.name = "MeasuredActors32"
	preview.add_child(crowd)
	for index in range(32):
		var actor: Node2D = CharacterActor.new()
		actor.position = Vector2(89 + (index % 8) * 109, 257 + int(index / 8) * 139)
		actor.scale = Vector2.ONE * 1.5
		crowd.add_child(actor)
		actor.configure({"id": "benchmark-%d" % index, "name": "效能樣本", "gender": "male" if index % 2 == 0 else "female", "loadout": {"clothing": "cloth", "armor": "chest", "weapon": "sword"}})
		actor.set_motion(VECTORS[index % 4].normalized() * (32.0 if index % 3 == 0 else 56.0))
	# Godot's Performance monitor refreshes coarsely; two seconds avoids
	# carrying font-loading or scene-initialization timings into this sample.
	var warmup_start := Time.get_ticks_usec()
	var warmup_frames := 0
	while Time.get_ticks_usec() - warmup_start < 2000000 or warmup_frames < 60:
		await get_tree().process_frame
		warmup_frames += 1
	var warmup_seconds := float(Time.get_ticks_usec() - warmup_start) / 1000000.0
	var frame_intervals: Array[float] = []
	var process_times: Array[float] = []
	var previous_tick := Time.get_ticks_usec()
	for sample in range(240):
		await get_tree().process_frame
		var current_tick := Time.get_ticks_usec()
		frame_intervals.append(float(current_tick - previous_tick) / 1000.0)
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		previous_tick = current_tick
	var metrics := {
		"measured": true,
		"actors": 32,
		"visible_actors": 32,
		"hidden_preview_actors_process_disabled": true,
		"equipment": "cloth + chest armor + sword",
		"motions": "mixed walk/run, four diagonal directions",
		"body_world_height_px": 64,
		"display_scale": 1.5,
		"warmup_frames": warmup_frames,
		"warmup_seconds": warmup_seconds,
		"sample_frames": frame_intervals.size(),
		"frame_interval_ms": _statistics(frame_intervals),
		"engine_process_time_monitor_ms": _statistics(process_times),
		"estimated_fps_from_mean_interval": 1000.0 / float(_statistics(frame_intervals).mean),
		"draw_calls_last_frame": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"rendered_objects_last_frame": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"engine_max_fps": Engine.max_fps,
		"scope": "Small native desktop viewport sample; no large RTS capacity conclusion."
	}
	await _capture("06-performance-32-actors")
	crowd.queue_free()
	await _frames(2)
	return metrics


func _capture(filename: String) -> void:
	if not gpu_available:
		captures.append({"name": filename, "saved": false, "reason": "NOT_RUN: headless display"})
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := report_dir.path_join(filename + ".png")
	var error := image.save_png(path)
	captures.append({"name": filename, "path": path, "saved": error == OK, "width": image.get_width(), "height": image.get_height(), "error": error})


func _sprite_records(node: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if node is Sprite2D and node.is_visible_in_tree():
		var sprite := node as Sprite2D
		result.append({"name": str(sprite.name), "texture": sprite.texture.resource_path if sprite.texture != null else "", "frame": sprite.frame, "frame_coords": str(sprite.frame_coords), "hframes": sprite.hframes, "vframes": sprite.vframes, "region_enabled": sprite.region_enabled, "region_rect": str(sprite.region_rect), "flip_h": sprite.flip_h, "flip_v": sprite.flip_v})
	for child in node.get_children():
		result.append_array(_sprite_records(child))
	return result


func _no_mirror(sprites: Array[Dictionary]) -> bool:
	if sprites.is_empty():
		return false
	for sprite in sprites:
		if sprite.flip_h or sprite.flip_v:
			return false
	return true


func _unique_count(values: Array) -> int:
	var unique := {}
	for value in values:
		unique[value] = true
	return unique.size()


func _statistics(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {}
	var sorted := samples.duplicate()
	sorted.sort()
	var sum := 0.0
	for value in samples:
		sum += value
	return {"mean": sum / samples.size(), "p95": sorted[clampi(int(ceil(samples.size() * 0.95)) - 1, 0, samples.size() - 1)], "min": sorted[0], "max": sorted[-1]}


func _environment() -> Dictionary:
	return {"godot": Engine.get_version_info(), "os": OS.get_name(), "os_version": OS.get_version(), "processor": OS.get_processor_name(), "processor_count": OS.get_processor_count(), "display_server": DisplayServer.get_name(), "rendering_method": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(), "gpu_vendor": RenderingServer.get_video_adapter_vendor(), "viewport_size": str(get_viewport().get_visible_rect().size), "gpu_viewport_readback": gpu_available}


func _check(name: String, passed: bool, evidence: Variant) -> void:
	checks.append({"name": name, "passed": passed, "evidence": evidence})
	if not passed:
		push_error("ACTOR_CHECK_FAIL " + name + " " + str(evidence))


func _frames(count: int) -> void:
	for frame in range(count):
		await get_tree().process_frame
