extends Node
## Run with the standalone preview and -- --verify-actors.
## This records functional evidence and a small rendered benchmark. It cannot
## establish subjective art approval or large-scale RTS capacity.

const CharacterActor = preload("res://prototype/actors/character_actor.gd")
const GaitReview = preload("res://prototype/actors/gait_review.gd")
const VECTORS := [Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]
const DIRECTIONS := ["sw", "se", "nw", "ne"]

var checks: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var report_dir := ""
var preview: Node2D
var gpu_available := false
var direction_evidence: Array[Dictionary] = []
var equipment_evidence: Array[Dictionary] = []
var gait_evidence: Array[Dictionary] = []
var cache_snapshots: Array[Dictionary] = []
var composite_pixel_evidence: Dictionary = {}
var texture_memory_peak_bytes := 0
var texture_memory_start_bytes := 0
var texture_memory_samples := 0


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
	texture_memory_start_bytes = int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	_sample_texture_memory()
	await _frames(3)
	_record_cache("preview_ready")
	await _verify_actor_contract()
	await _verify_equipment()
	_record_cache("after_equipment_combinations")
	await _verify_composite_pixels()
	_record_cache("after_composite_pixel_readback")
	await _capture_gallery()
	await _capture_run_contact_sheets()
	var performance := await _benchmark()
	_record_cache("after_benchmark")
	_verify_cache_bounds()
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
		"schema": "prototype-actor-acceptance/2",
		"timestamp_utc": Time.get_datetime_string_from_system(true, true),
		"passed": functional_passed and captures_passed and bool(performance.get("measured", false)),
		"functional_passed": functional_passed,
		"gpu_capture_passed": captures_passed,
		"environment": _environment(),
		"checks": checks,
		"four_direction_evidence": direction_evidence,
		"equipment_evidence": equipment_evidence,
		"composite_pixel_evidence": composite_pixel_evidence,
		"run_contact_sheet_evidence": gait_evidence,
		"captures": captures,
		"performance": performance,
		"texture_memory": {"monitor": "Performance.RENDER_TEXTURE_MEM_USED", "baseline_bytes": texture_memory_start_bytes, "peak_bytes": texture_memory_peak_bytes, "final_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)), "samples": texture_memory_samples, "measurement_window": "After preview actors are created, through functional checks, contact sheets, and benchmark. Earlier initialization transients are not captured.", "scope": "Entire rendered viewport, including fonts and other textures; not actor-only allocation."},
		"character_cache": {"final_stats": CharacterActor.get_cache_stats(), "snapshots": cache_snapshots, "scope": "Actor-reported bounded cache. Cache byte limits exclude CPU source images and textures retained only by active actors; those allocations are reported separately."},
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
			var records := _sprite_records(actor, state)
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
			var sprites := _sprite_records(actor, state)
			signatures.append(JSON.stringify(sprites))
			_check("%s equipment combination %d" % [gender, combination], state.get("loadout", {}) == equipment, state.get("loadout", {}))
			equipment_evidence.append({"gender": gender, "requested": equipment, "actual": state.get("loadout", {}), "visible_sprites": sprites})
		_check(gender + " eight equipment state/source combinations", _unique_count(signatures) == 8, {"unique_visible_sprite_source_and_loadout_configurations": _unique_count(signatures)})


func _verify_composite_pixels() -> void:
	const TOLERANCE := 1
	var frame_results: Array[Dictionary] = []
	var failures: Array[Dictionary] = []
	var samples := 0
	var total_mismatch := 0
	var total_pixels := 0
	var max_difference := 0
	var max_alpha_difference := 0
	var max_rgb_difference := 0
	var saved_loadout: Dictionary = preview.loadout.duplicate()
	if gpu_available:
		for gender_index in range(2):
			var gender := "male" if gender_index == 0 else "female"
			var proof_path := ProjectSettings.globalize_path("res://").path_join("../pixel-assets/prototype-actors/previews/%s-all.png" % gender).simplify_path()
			var proof := Image.load_from_file(proof_path)
			if proof == null or proof.is_empty() or proof.get_size() != Vector2i(3840, 768):
				failures.append({"gender": gender, "error": "Missing or invalid 3840x768 Aseprite proof", "path": proof_path})
				continue
			proof.convert(Image.FORMAT_RGBA8)
			var proof_bytes := proof.get_data()
			var actor: Node2D = preview.actors[gender_index * 4]
			actor.set_equipment({"clothing": "cloth", "armor": "chest", "weapon": "sword"})
			for source_frame in range(80):
				var column := source_frame % 20
				var direction_index := int(source_frame / 20)
				var motion := "idle" if column < 4 else ("walk" if column < 12 else "run")
				var local_frame := column - int({"idle": 0, "walk": 4, "run": 12}[motion])
				actor.set_motion(Vector2.ZERO if motion == "idle" else VECTORS[direction_index].normalized() * (32.0 if motion == "walk" else 56.0))
				actor.set_preview_direction(DIRECTIONS[direction_index])
				actor.set_preview_frame(local_frame)
				await RenderingServer.frame_post_draw
				var state: Dictionary = actor.get_visual_state()
				var crop_values: Array = state.get("composite_crop", [])
				var source_values: Array = state.get("source_rect", [])
				var sprite := _find_actor_sprite(actor)
				if crop_values.size() != 4 or source_values != [column * 192, direction_index * 192, 192, 192] or int(state.get("source_frame", -1)) != source_frame or sprite == null or sprite.texture == null:
					failures.append({"gender": gender, "source_frame": source_frame, "error": "Invalid source rectangle, crop, frame, or visible texture", "state": state})
					continue
				var crop := Rect2i(int(crop_values[0]), int(crop_values[1]), int(crop_values[2]), int(crop_values[3]))
				var actual := sprite.texture.get_image()
				if actual == null or actual.is_empty() or actual.get_size() != crop.size or not Rect2i(0, 0, 192, 192).encloses(crop):
					failures.append({"gender": gender, "source_frame": source_frame, "error": "GPU image size differs from the declared crop or crop exceeds the original cell", "crop": crop_values})
					continue
				actual.convert(Image.FORMAT_RGBA8)
				var source := Rect2i(column * 192, direction_index * 192, 192, 192)
				var comparison := _compare_rgba_frame(proof_bytes, proof.get_width(), actual.get_data(), crop, source, TOLERANCE)
				comparison["gender"] = gender
				comparison["source_frame"] = source_frame
				comparison["direction"] = DIRECTIONS[direction_index]
				comparison["motion"] = motion
				comparison["local_frame"] = local_frame
				comparison["composite_crop"] = crop_values
				comparison["source_rect"] = source_values
				frame_results.append(comparison)
				samples += 1
				total_mismatch += int(comparison.totalMismatch)
				total_pixels += int(comparison.pixels_compared)
				max_difference = maxi(max_difference, int(comparison.maxdiff))
				max_alpha_difference = maxi(max_alpha_difference, int(comparison.max_alpha_diff))
				max_rgb_difference = maxi(max_rgb_difference, int(comparison.max_rgb_diff))
	else:
		failures.append({"error": "NOT_RUN: actual composite GPU texture readback requires a rendered display"})
	# A frozen test frame must never leak into the live gallery or benchmark.
	for actor in preview.actors:
		actor.set_preview_frame(-1)
	preview.apply_loadout(saved_loadout)
	preview.apply_motion("idle")
	await _frames(2)
	composite_pixel_evidence = {"samples": samples, "expected_samples": 160, "totalMismatch": total_mismatch, "pixels_compared": total_pixels, "maxdiff": max_difference, "max_alpha_diff": max_alpha_difference, "max_rgb_diff": max_rgb_difference, "tolerance_per_channel_255": TOLERANCE, "equipment": {"clothing": "cloth", "armor": "chest", "weapon": "sword"}, "comparison": "Actual Sprite2D.texture.get_image() against external Aseprite proof for all 192x192 pixels. Pixels outside the runtime crop are transparent; compare alpha everywhere and RGB wherever either image has nonzero alpha.", "proof_paths": ["pixel-assets/prototype-actors/previews/male-all.png", "pixel-assets/prototype-actors/previews/female-all.png"], "failures": failures, "frames": frame_results}
	_check("all 160 composited GPU frames match Aseprite proof pixels within 1/255", samples == 160 and total_mismatch == 0 and failures.is_empty(), {"samples": samples, "totalMismatch": total_mismatch, "maxdiff": max_difference, "failures": failures})


func _compare_rgba_frame(proof: PackedByteArray, proof_width: int, actual: PackedByteArray, crop: Rect2i, source: Rect2i, tolerance: int) -> Dictionary:
	var mismatch := 0
	var alpha_mismatch := 0
	var rgb_mismatch := 0
	var max_alpha := 0
	var max_rgb := 0
	var first_mismatches: Array[Dictionary] = []
	for y in range(192):
		for x in range(192):
			var expected_offset := ((source.position.y + y) * proof_width + source.position.x + x) * 4
			var inside_crop := crop.has_point(Vector2i(x, y))
			var actual_offset := ((y - crop.position.y) * crop.size.x + x - crop.position.x) * 4 if inside_crop else -1
			var actual_alpha := int(actual[actual_offset + 3]) if inside_crop else 0
			var expected_alpha := int(proof[expected_offset + 3])
			var alpha_delta := absi(actual_alpha - expected_alpha)
			max_alpha = maxi(max_alpha, alpha_delta)
			var rgb_delta := 0
			if actual_alpha > 0 or expected_alpha > 0:
				for channel in range(3):
					var actual_value := int(actual[actual_offset + channel]) if inside_crop else 0
					rgb_delta = maxi(rgb_delta, absi(actual_value - int(proof[expected_offset + channel])))
			max_rgb = maxi(max_rgb, rgb_delta)
			if alpha_delta > tolerance:
				alpha_mismatch += 1
			if rgb_delta > tolerance:
				rgb_mismatch += 1
			if alpha_delta > tolerance or rgb_delta > tolerance:
				mismatch += 1
				if first_mismatches.size() < 8:
					first_mismatches.append({"x": x, "y": y, "alpha_diff": alpha_delta, "rgb_max_diff": rgb_delta})
	return {"pixels_compared": 192 * 192, "totalMismatch": mismatch, "alpha_mismatch_pixels": alpha_mismatch, "rgb_mismatch_pixels": rgb_mismatch, "maxdiff": maxi(max_alpha, max_rgb), "max_alpha_diff": max_alpha, "max_rgb_diff": max_rgb, "first_mismatches": first_mismatches}


func _find_actor_sprite(node: Node) -> Sprite2D:
	if node is Sprite2D and node.is_visible_in_tree():
		return node as Sprite2D
	for child in node.get_children():
		var sprite := _find_actor_sprite(child)
		if sprite != null:
			return sprite
	return null


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


func _capture_run_contact_sheets() -> void:
	preview.set_review_view(true)
	for gender in ["male", "female"]:
		var sheet: Node2D = GaitReview.new()
		sheet.gender = gender
		preview.add_child(sheet)
		await _frames(3)
		var evidence: Array[Dictionary] = sheet.get_frame_evidence()
		var frame_states_valid := evidence.size() == 32
		for frame in evidence:
			var state: Dictionary = frame.state
			var local_frame := int(frame.requested_local_run_frame)
			var direction_index := DIRECTIONS.find(str(frame.direction))
			frame_states_valid = frame_states_valid and state.get("gender") == gender and state.get("motion") == "run" and state.get("direction") == frame.direction and int(state.get("frame", -1)) == 12 + local_frame and int(state.get("source_frame", -1)) == direction_index * 20 + 12 + local_frame
		_check(gender + " contact sheet contains every frozen run frame in four directions", frame_states_valid, evidence)
		await _frames(3)
		var after_wait: Array[Dictionary] = sheet.get_frame_evidence()
		var frozen := true
		for index in range(evidence.size()):
			frozen = frozen and int(evidence[index].state.get("source_frame", -1)) == int(after_wait[index].state.get("source_frame", -2))
		_check(gender + " contact sheet frames stay frozen", frozen, {"frames": evidence.size(), "waited_process_frames": 3})
		var filename := "07-run-cycle-male" if gender == "male" else "08-run-cycle-female"
		await _capture(filename)
		gait_evidence.append({"gender": gender, "capture": filename + ".png", "rows": DIRECTIONS, "columns": "local run frames 0..7", "equipment": sheet.loadout.duplicate(), "frames": evidence, "appearance_review": "PENDING_USER_REVIEW"})
		_record_cache("run_contact_sheet_" + gender)
		sheet.queue_free()
		await _frames(2)
	preview.set_review_view(false)


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
	var draw_call_samples: Array[float] = []
	var texture_byte_samples: Array[float] = []
	var cache_before := _record_cache("benchmark_sample_start")
	var previous_tick := Time.get_ticks_usec()
	for sample in range(240):
		await get_tree().process_frame
		var current_tick := Time.get_ticks_usec()
		frame_intervals.append(float(current_tick - previous_tick) / 1000.0)
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		draw_call_samples.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		texture_byte_samples.append(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
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
		"draw_calls": _statistics(draw_call_samples),
		"render_texture_memory_bytes": _statistics(texture_byte_samples),
		"character_cache_before_sample": cache_before,
		"character_cache_after_sample": _record_cache("benchmark_sample_end"),
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


func _sprite_records(node: Node, visual_state: Dictionary = {}) -> Array[Dictionary]:
	if visual_state.is_empty() and node.has_method("get_visual_state"):
		visual_state = node.get_visual_state()
	var result: Array[Dictionary] = []
	if node is Sprite2D and node.is_visible_in_tree():
		var sprite := node as Sprite2D
		result.append({"name": str(sprite.name), "texture": sprite.texture.resource_path if sprite.texture != null else "", "texture_present": sprite.texture != null, "gender": visual_state.get("gender", ""), "source_frame": visual_state.get("source_frame", -1), "loadout": visual_state.get("loadout", {}).duplicate(), "frame": sprite.frame, "frame_coords": str(sprite.frame_coords), "hframes": sprite.hframes, "vframes": sprite.vframes, "region_enabled": sprite.region_enabled, "region_rect": str(sprite.region_rect), "flip_h": sprite.flip_h, "flip_v": sprite.flip_v})
	for child in node.get_children():
		result.append_array(_sprite_records(child, visual_state))
	return result


func _record_cache(stage: String) -> Dictionary:
	var stats: Dictionary = CharacterActor.get_cache_stats()
	var snapshot := {"stage": stage, "stats": stats.duplicate(true), "render_texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))}
	cache_snapshots.append(snapshot)
	return stats


func _verify_cache_bounds() -> void:
	var bounded := not cache_snapshots.is_empty()
	var live_count_bounded := not cache_snapshots.is_empty()
	for snapshot in cache_snapshots:
		var stats: Dictionary = snapshot.stats
		var capacity_entries := int(stats.get("capacity_entries", -1))
		var entries := int(stats.get("entries", -1))
		var capacity_bytes := int(stats.get("capacity_bytes", -1))
		var bytes := int(stats.get("bytes", -1))
		var peak_bytes := int(stats.get("peak_bytes", -1))
		bounded = bounded and capacity_entries > 0 and entries >= 0 and entries <= capacity_entries and capacity_bytes > 0 and bytes >= 0 and bytes <= capacity_bytes and peak_bytes >= bytes and peak_bytes <= capacity_bytes
		var active_actors := int(stats.get("active_actor_count", -1))
		var live_textures := int(stats.get("frame_texture_count", -1))
		live_count_bounded = live_count_bounded and active_actors >= 0 and live_textures >= 0 and live_textures <= capacity_entries + active_actors
	_check("reported frame cache stays within explicit entry and byte limits", bounded, cache_snapshots)
	_check("live frame textures stay within cache slots plus active actor references", live_count_bounded, cache_snapshots)


func _sample_texture_memory() -> void:
	texture_memory_peak_bytes = maxi(texture_memory_peak_bytes, int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)))
	texture_memory_samples += 1


func _process(_delta: float) -> void:
	_sample_texture_memory()


func _no_mirror(sprites: Array[Dictionary]) -> bool:
	if sprites.is_empty():
		return false
	for sprite in sprites:
		if sprite.flip_h or sprite.flip_v or not sprite.get("texture_present", false):
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
