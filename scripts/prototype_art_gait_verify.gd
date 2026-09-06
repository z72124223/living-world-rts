extends SceneTree
## Quantitative whole-cycle checks over the actual offline rendered limb layers.
## Foot contact is checked in moving world coordinates at each authored key.
var work_root := ""
var images: Dictionary = {}
var checks: Array = []

func _initialize() -> void:
	work_root = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	call_deferred("verify")

func point(value: Array) -> Vector2:
	return Vector2(value[0], value[1])

func check(name_: String, passed: bool, evidence: Variant) -> void:
	checks.append({"name": name_, "passed": passed, "evidence": evidence})

func image_for(gender: String, layer: String) -> Image:
	var key := gender + "-" + layer
	if not images.has(key):
		images[key] = Image.load_from_file(work_root + "/pixel-assets/prototype-actors/baked-layers/" + key + ".png")
	return images[key]

func local_pixel(record: Dictionary, world_point: Vector2) -> Vector2i:
	return Vector2i((world_point * 2.0 + Vector2(96, 168)).round()) + Vector2i(int(record.frame) % 20 * 192, ["sw", "se", "nw", "ne"].find(record.direction) * 192)

func has_limb_pixel(record: Dictionary, layer: String, p: Vector2, radius: int = 2) -> bool:
	var im := image_for(record.gender, layer)
	var at := local_pixel(record, p)
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if im.get_pixel(at.x + x, at.y + y).a >= .9:
				return true
	return false

func verify() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(work_root + "/prototype/reports/actors/gait-joints.json"))
	var groups: Dictionary = {}
	var max_drift := 0.0
	var contact_pairs := 0
	var uncovered: Array = []
	var seam_samples := 0
	var hidden_near_hand: Array = []
	var hand_samples := 0
	var ranges: Array = []
	for record: Dictionary in data.poses:
		if record.motion == "idle":
			continue
		var key: String = record.gender + "/" + record.direction + "/" + record.motion
		if not groups.has(key):
			groups[key] = []
		groups[key].append(record)
		for side in ["near", "far"]:
			var wrist := "hand" if side == "near" else "far_hand"
			var chain := [side + "_upper_arm", side + "_forearm", wrist]
			for segment in range(2):
				var a := point(record.joints[chain[segment]])
				var b := point(record.joints[chain[segment + 1]])
				for step in range(9):
					seam_samples += 1
					var p := a.lerp(b, float(step) / 8.0)
					if not has_limb_pixel(record, "body_" + side + "_arm", p):
						uncovered.append({"pose": key, "frame": record.frame, "side": side, "segment": segment, "step": step})
		# Near hands must remain in the final image even when they pass in front
		# of the waist. Compare a distal skin pixel unaffected by sleeve overlap.
		var arm := image_for(record.gender, "body_near_arm")
		var cloth := image_for(record.gender, "cloth_near_arm")
		var proof_key: String = str(record.gender) + "-proof"
		if not images.has(proof_key):
			images[proof_key] = Image.load_from_file(work_root + "/pixel-assets/prototype-actors/previews/" + str(record.gender) + "-all.png")
		var proof: Image = images[proof_key]
		var at := local_pixel(record, point(record.joints.hand_tip))
		var found := false
		var visible_hand := false
		for y in range(-3, 4):
			for x in range(-3, 4):
				var color := arm.get_pixel(at.x + x, at.y + y)
				if color.a >= .99 and cloth.get_pixel(at.x + x, at.y + y).a < .01:
					found = true
					if color.is_equal_approx(proof.get_pixel(at.x + x, at.y + y)):
						visible_hand = true
		hand_samples += 1
		if not found or not visible_hand:
			hidden_near_hand.append({"pose": key, "frame": record.frame, "skin_sample_found": found})
	for key: String in groups:
		var cycle: Array = groups[key]
		var near_min := Vector2(INF, INF)
		var near_max := Vector2(-INF, -INF)
		var far_min := Vector2(INF, INF)
		var far_max := Vector2(-INF, -INF)
		for i in range(8):
			var a: Dictionary = cycle[i]
			var b: Dictionary = cycle[(i + 1) % 8]
			var direction := Vector2(-1 if str(a.direction).ends_with("w") else 1, 1 if str(a.direction).begins_with("s") else -1).normalized()
			for side in ["near", "far"]:
				var fa: Dictionary = a.feet[side]
				var fb: Dictionary = b.feet[side]
				if fa.contact and fb.contact and float(fb.phase) > float(fa.phase):
					var advance := direction * float(fa.speed) / float(fa.fps)
					var drift := (point(fb.world_local) - point(fa.world_local) + advance).length()
					max_drift = maxf(max_drift, drift)
					contact_pairs += 1
			var near_hand := point(a.joints.hand_tip)
			var far_hand := point(a.joints.far_hand_tip)
			near_min = near_min.min(near_hand); near_max = near_max.max(near_hand)
			far_min = far_min.min(far_hand); far_max = far_max.max(far_hand)
		var near_range := near_max - near_min
		var far_range := far_max - far_min
		ranges.append({"cycle": key, "near_hand_range_world_px": [near_range.x, near_range.y], "far_hand_range_world_px": [far_range.x, far_range.y]})
		check(key + " wrists travel through the full cycle", near_range.length() > 8.0 and far_range.length() > 8.0, ranges[-1])
	check("all eight keys in each of sixteen moving cycles", groups.size() == 16 and data.poses.size() == 160, groups.size())
	check("IK ankle reach error below 0.05 world pixels", float(data.max_ik_error_world_px) < .05, data.max_ik_error_world_px)
	check("planted ankle stays fixed as root advances at 32/56 speed", max_drift < .05 and contact_pairs >= 64, {"max_world_drift_px": max_drift, "contact_pairs": contact_pairs})
	check("rendered arm silhouette covers shoulder elbow wrist paths", uncovered.is_empty(), {"samples": seam_samples, "uncovered": uncovered})
	check("near hands stay visible over torso and waist in all moving keys", hidden_near_hand.is_empty(), {"samples": hand_samples, "failures": hidden_near_hand})
	var passed := true
	for item: Dictionary in checks:
		passed = passed and bool(item.passed)
	var report := {"passed": passed, "checks": checks, "hand_motion_ranges": ranges,
		"limits": "Stance drift is measured at authored key times before final nearest-pixel display; between keys 8/12fps stepping may show up to one frame of relative motion. Rendered alpha/skin samples and full-cycle GPU contact sheets accompany the numeric checks; aesthetic approval remains pending."}
	var file := FileAccess.open(work_root + "/prototype/reports/actors/gait-validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("GAIT VALIDATION ", "PASS" if passed else "FAIL", " max_stance_drift=", max_drift, " uncovered=", uncovered.size(), " hidden_hands=", hidden_near_hand.size())
	quit(0 if passed else 1)
