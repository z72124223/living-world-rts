extends SceneTree
## Offline bake: original body mesh, garment material fields, articulated arm
## cutouts and planted-foot IK. Runtime receives cropped reusable layer atlases.
const LAYERS := ["body_far_leg", "cloth_far_leg", "body_near_leg", "cloth_near_leg", "body_far_arm", "cloth_far_arm", "body_torso_pelvis", "cloth_torso_pelvis", "sword", "chest", "body_near_arm", "cloth_near_arm", "head"]
var work_root := ""
var viewport: SubViewport
var rig: Node2D
var skeleton: Skeleton2D
var bones: Dictionary
var definitions: Dictionary
var visuals: Dictionary
var gender := "female"
var pose_records: Array = []
var max_ik_error := 0.0

func _initialize() -> void:
	work_root = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	call_deferred("bake")

func source_path(n: String, direction: String = "sw") -> String:
	return work_root + "/pixel-assets/prototype-actors/source-textures/" + gender + "-" + direction + "-" + n + ".png"

func blend_weights(a: String, b: String, t: float) -> Dictionary:
	var value := clampf(t, 0.0, 1.0)
	return {a: 1.0 - value, b: value}

func skin_weights(part: String, p: Vector2) -> Dictionary:
	var male := gender == "male"
	if part == "torso_pelvis":
		if p.y < (51.0 if male else 58.0):
			return blend_weights("head", "torso", (p.y - (44.0 if male else 51.0)) / 7.0)
		return blend_weights("torso", "hips", (p.y - (88.0 if male else 87.0)) / (26.0 if male else 23.0))
	var side := "far" if part == "far_leg" else "near"
	var knee := float(definitions[side + "_shin"].at[1])
	var ankle := float(definitions[side + "_foot"].at[1])
	if p.y < (138.0 if male else 134.0):
		return blend_weights("hips", side + "_thigh", (p.y - (123.0 if male else 122.0)) / (15.0 if male else 12.0))
	if p.y < knee + 5.0:
		return blend_weights(side + "_thigh", side + "_shin", (p.y - knee + 5.0) / 10.0)
	return blend_weights(side + "_shin", side + "_foot", (p.y - ankle + 4.0) / 8.0)

func make_poly(n: String, points: PackedVector2Array, tris: Array, per_vertex: Array) -> void:
	var poly := Polygon2D.new()
	poly.name = n
	poly.polygon = points
	poly.uv = points
	poly.polygons = tris
	poly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rig.add_child(poly)
	poly.skeleton = poly.get_path_to(skeleton)
	var weights: Dictionary = {}
	for i in range(per_vertex.size()):
		for key in per_vertex[i]:
			if not weights.has(key):
				var values := PackedFloat32Array()
				values.resize(points.size())
				weights[key] = values
			weights[key][i] = float(per_vertex[i][key])
	for key in weights:
		poly.add_bone(skeleton.get_path_to(bones[key]), weights[key])
	poly.set_meta("source_name", n)
	visuals[n] = [poly]

func make_cloth_grid(part: String) -> void:
	var im := Image.load_from_file(source_path("cloth_" + part))
	var r := im.get_used_rect().grow(4)
	var x0 := int(floor(float(r.position.x) / 4.0)) * 4
	var y0 := int(floor(float(r.position.y) / 4.0)) * 4
	var nx := int(ceil(float(r.end.x - x0) / 4.0)) + 1
	var ny := int(ceil(float(r.end.y - y0) / 4.0)) + 1
	var points := PackedVector2Array()
	var ws: Array = []
	var tris: Array[PackedInt32Array] = []
	for y in range(ny):
		for x in range(nx):
			var p := Vector2(x0 + x * 4, y0 + y * 4)
			points.append(p)
			ws.append(skin_weights(part, p))
	for y in range(ny - 1):
		for x in range(nx - 1):
			var i := y * nx + x
			tris.append(PackedInt32Array([i, i + 1, i + nx]))
			tris.append(PackedInt32Array([i + 1, i + nx + 1, i + nx]))
	make_poly("cloth_" + part, points, tris, ws)

func add_part_sprite(group: String, image_name: String, bone_name: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = image_name
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bones[bone_name].add_child(sprite)
	sprite.position = -Vector2(definitions[bone_name].at[0], definitions[bone_name].at[1])
	sprite.set_meta("source_name", image_name)
	if not visuals.has(group):
		visuals[group] = []
	visuals[group].append(sprite)

func setup() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(192, 192)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	rig = Node2D.new()
	viewport.add_child(rig)
	var prefix := "male-body-v01" if gender == "male" else "body-v03"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/" + prefix + "-rig.json"))
	var mesh: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/" + prefix + "-mesh.json"))
	bones = {}; definitions = {}; visuals = {}
	skeleton = Skeleton2D.new()
	rig.add_child(skeleton)
	for b in data.bones:
		definitions[b.name] = b
		var bone := Bone2D.new()
		bone.name = b.name
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(float(b.length))
		bone.set_bone_angle(float(b.angle))
		var at := Vector2(b.at[0], b.at[1])
		if b.parent == "":
			skeleton.add_child(bone)
		else:
			bones[b.parent].add_child(bone)
			at -= Vector2(definitions[b.parent].at[0], definitions[b.parent].at[1])
		bone.position = at
		bone.rest = Transform2D(0.0, at)
		bones[b.name] = bone
	for m in mesh.meshes:
		if str(m.name).ends_with("_arm"):
			continue
		var points := PackedVector2Array()
		for p in m.vertices:
			points.append(Vector2(p[0], p[1]))
		var tris: Array[PackedInt32Array] = []
		for t in m.triangles:
			tris.append(PackedInt32Array(t))
		make_poly("body_" + str(m.name), points, tris, m.weights)
		make_cloth_grid(str(m.name))
	for side in ["far", "near"]:
		for category in ["body", "cloth"]:
			for segment in ["upper_arm", "forearm", "hand"]:
				var bone_name: String = side + "_" + segment
				if bone_name == "near_hand":
					bone_name = "hand"
				add_part_sprite(category + "_" + side + "_arm", category + "_" + side + "_" + segment, bone_name)
	for n in ["chest", "sword", "head"]:
		add_part_sprite(n, n, {"chest": "torso", "sword": "hips", "head": "head"}[n])

func skeleton_point(bone_name: String, endpoint: bool = false) -> Vector2:
	var b: Dictionary = definitions[bone_name]
	var tip := Vector2.ZERO
	if endpoint:
		tip = Vector2(b.tip[0], b.tip[1]) - Vector2(b.at[0], b.at[1])
	return skeleton.to_local(bones[bone_name].to_global(tip))

func solve_leg(side: String, target: Vector2) -> float:
	var a := skeleton_point(side + "_thigh")
	var l1 := float(definitions[side + "_thigh"].length)
	var l2 := float(definitions[side + "_shin"].length)
	var delta := target - a
	var d := clampf(delta.length(), absf(l1 - l2) + .001, l1 + l2 - .001)
	var offset := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var thigh_angle := delta.angle() + offset
	var knee := a + Vector2.from_angle(thigh_angle) * l1
	var shin_angle := (target - knee).angle()
	var r1 := thigh_angle - float(definitions[side + "_thigh"].angle)
	var r2 := shin_angle - float(definitions[side + "_shin"].angle) - r1
	bones[side + "_thigh"].rotation = r1
	bones[side + "_shin"].rotation = r2
	# Flat source boot/foot orientation during planted stance, no toe skating.
	bones[side + "_foot"].rotation = -r1 - r2
	return skeleton_point(side + "_foot").distance_to(target)

func arm_pose(side: String, phase: float, running: bool) -> void:
	var swing := cos(phase + (PI if side == "far" else 0.0))
	var upper := PI / 2.0 - swing * (0.78 if running else 0.45)
	var flex := (1.20 if running else 0.32) + 0.10 * sin(phase)
	var forearm := upper + flex
	var torso_rotation: float = bones.torso.rotation
	var r1 := upper - float(definitions[side + "_upper_arm"].angle)
	var r2 := forearm - float(definitions[side + "_forearm"].angle)
	bones[side + "_upper_arm"].rotation = r1 - torso_rotation
	bones[side + "_forearm"].rotation = r2 - r1
	var wrist := "hand" if side == "near" else "far_hand"
	bones[wrist].rotation = forearm - float(definitions[wrist].angle) - r2

func array_point(p: Vector2) -> Array:
	return [p.x, p.y]

func apply_pose(frame: int, dir_index: int) -> Dictionary:
	var moving := frame >= 4
	var running := frame >= 12
	var local_frame := frame - (12 if running else 4) if moving else frame
	var phase := float(local_frame) * TAU / (8.0 if moving else 4.0)
	for n in bones:
		bones[n].apply_rest()
	var factor := 128.0 / (239.0 if gender == "male" else 229.0)
	var world_factor := factor * 0.5
	var right := dir_index == 1 or dir_index == 3
	var back := dir_index >= 2
	rig.scale = Vector2(-factor if right else factor, factor)
	var floor_y := 244.0 if gender == "male" else 239.0
	rig.position = Vector2(96, 168) - Vector2(122.0 * rig.scale.x, floor_y * factor)
	var record := {"gender": gender, "direction": ["sw", "se", "nw", "ne"][dir_index], "frame": frame, "motion": "run" if running else ("walk" if moving else "idle"), "feet": {}, "joints": {}}
	if moving:
		bones.hips.position.y += 24.0 + 3.0 * sin(phase * 2.0)
		bones.torso.rotation = deg_to_rad(-7.0 if running else -2.0)
		bones.head.rotation = -bones.torso.rotation
		var direction := Vector2(-1, -1 if back else 1).normalized()
		var speed := 56.0 if running else 32.0
		var fps := 12.0 if running else 8.0
		var duty := 0.375 if running else 0.5
		var cycle_seconds := 8.0 / fps
		var half_stride := speed * cycle_seconds * duty * 0.5
		var targets: Dictionary = {}
		var metadata: Dictionary = {}
		for side in ["near", "far"]:
			var t := fposmod(float(local_frame) / 8.0 + (0.5 if side == "far" else 0.0), 1.0)
			var contact := t < duty
			var displacement := half_stride - speed * cycle_seconds * t
			var lift := 0.0
			if not contact:
				var u := (t - duty) / (1.0 - duty)
				displacement = lerpf(-half_stride, half_stride, u)
				lift = sin(u * PI) * (8.0 if running else 4.0)
			var b: Dictionary = definitions[side + "_foot"]
			var target := Vector2(b.at[0], b.at[1]) + (direction * displacement + Vector2(0, -lift)) / world_factor
			targets[side] = target
			metadata[side] = {"contact": contact, "phase": t, "speed": speed, "fps": fps}
		# Lower the pelvis only as much as needed at the reach extreme. Both
		# legs are then solved from this common hip position, preserving stance.
		var pelvis_adjust := 0.0
		for side in ["near", "far"]:
			var hip := skeleton_point(side + "_thigh")
			var length_total := float(definitions[side + "_thigh"].length) + float(definitions[side + "_shin"].length) - .05
			var dx: float = targets[side].x - hip.x
			var vertical := sqrt(maxf(0.0, length_total * length_total - dx * dx))
			pelvis_adjust = maxf(pelvis_adjust, float(targets[side].y) - vertical - hip.y)
		bones.hips.position.y += pelvis_adjust
		for side in ["near", "far"]:
			var target: Vector2 = targets[side]
			var error := solve_leg(side, target)
			max_ik_error = maxf(max_ik_error, error * world_factor)
			var actual := (rig.transform * skeleton_point(side + "_foot") - Vector2(96, 168)) * 0.5
			record.feet[side] = metadata[side].duplicate()
			record.feet[side]["world_local"] = array_point(actual)
			record.feet[side]["ik_error_world_px"] = error * world_factor
		arm_pose("near", phase, running)
		arm_pose("far", phase, running)
	else:
		bones.torso.rotation = deg_to_rad(sin(phase) * .35)
		bones.head.rotation = -bones.torso.rotation
	for n in ["hips", "torso", "near_upper_arm", "near_forearm", "hand", "far_upper_arm", "far_forearm", "far_hand", "near_thigh", "near_shin", "near_foot", "far_thigh", "far_shin", "far_foot"]:
		record.joints[n] = array_point((rig.transform * skeleton_point(n) - Vector2(96, 168)) * 0.5)
	for n in ["hand", "far_hand"]:
		record.joints[n + "_tip"] = array_point((rig.transform * skeleton_point(n, true) - Vector2(96, 168)) * 0.5)
	return record

func bake() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for current_gender in ["female", "male"]:
		gender = current_gender
		setup()
		var atlases: Dictionary = {}
		for n in LAYERS:
			atlases[n] = Image.create(3840, 768, false, Image.FORMAT_RGBA8)
		for d in range(4):
			var direction: String = ["sw", "se", "nw", "ne"][d]
			for group in visuals:
				for node in visuals[group]:
					node.texture = ImageTexture.create_from_image(Image.load_from_file(source_path(str(node.get_meta("source_name")), direction)))
			for f in range(20):
				pose_records.append(apply_pose(f, d))
				for n in LAYERS:
					for group in visuals:
						for node in visuals[group]:
							node.visible = group == n
					await process_frame
					await RenderingServer.frame_post_draw
					var im := viewport.get_texture().get_image()
					atlases[n].blit_rect(im, Rect2i(0, 0, 192, 192), Vector2i(f * 192, d * 192))
			print("BAKED ", gender, " ", direction)
		for n in LAYERS:
			atlases[n].save_png(work_root + "/pixel-assets/prototype-actors/baked-layers/" + gender + "-" + n + ".png")
		viewport.queue_free()
		await process_frame
	var file := FileAccess.open(work_root + "/prototype/reports/actors/gait-joints.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"max_ik_error_world_px": max_ik_error, "poses": pose_records}, "\t"))
	file.close()
	print("ACTOR BAKE COMPLETE max_ik_error_world_px=", max_ik_error)
	quit()
