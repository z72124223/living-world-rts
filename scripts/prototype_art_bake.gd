extends SceneTree
## Offline GPU bake of approved body meshes and independently authored garments.
## Dense source meshes never enter character_actor.gd or the playable scene.
const PARTS := ["far_leg", "near_leg", "far_arm", "torso_pelvis", "near_arm"]
const LAYERS := ["body_far_leg", "cloth_far_leg", "body_near_leg", "cloth_near_leg", "body_far_arm", "cloth_far_arm", "body_torso_pelvis", "cloth_torso_pelvis", "sword", "chest", "body_near_arm", "cloth_near_arm", "head"]
var work_root := ""
var viewport: SubViewport
var rig: Node2D
var skeleton: Skeleton2D
var bones: Dictionary
var definitions: Dictionary
var visuals: Dictionary
var gender := "female"

func _initialize() -> void:
	work_root = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	call_deferred("bake")

func texture(path: String) -> ImageTexture:
	return ImageTexture.create_from_image(Image.load_from_file(path))

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
		for category in ["body_", "cloth_"]:
			var poly := Polygon2D.new()
			poly.name = category + str(m.name)
			var points := PackedVector2Array()
			for p in m.vertices:
				points.append(Vector2(p[0], p[1]))
			poly.polygon = points
			poly.uv = points
			var triangles: Array[PackedInt32Array] = []
			for t in m.triangles:
				triangles.append(PackedInt32Array(t))
			poly.polygons = triangles
			poly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			rig.add_child(poly)
			poly.skeleton = poly.get_path_to(skeleton)
			var weights: Dictionary = {}
			for i in range(m.weights.size()):
				for n in m.weights[i]:
					if not weights.has(n):
						var values := PackedFloat32Array()
						values.resize(points.size())
						weights[n] = values
					weights[n][i] = float(m.weights[i][n])
			for n in weights:
				poly.add_bone(skeleton.get_path_to(bones[n]), weights[n])
			visuals[poly.name] = poly
	for part in ["chest", "sword", "head"]:
		var sprite := Sprite2D.new()
		sprite.name = part
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var bone_name: String = {"chest": "torso", "sword": "hips", "head": "head"}[part]
		bones[bone_name].add_child(sprite)
		sprite.position = -Vector2(definitions[bone_name].at[0], definitions[bone_name].at[1])
		visuals[part] = sprite

func apply_pose(frame: int, dir_index: int) -> void:
	var moving := frame >= 4
	var running := frame >= 12
	var phase := float((frame - (12 if running else 4)) % 8) * TAU / 8.0 if moving else float(frame) * TAU / 4.0
	var stride := 23.0 if running else 12.0
	var swing := sin(phase) if moving else 0.0
	# Keep the approved relaxed bent elbow as the idle pose. Large straightening
	# of its two-dimensional source exposes unseen pixels and pinches the elbow.
	var angles := {"near_upper_arm": 0.0, "near_forearm": 0.0, "far_upper_arm": 0.0}
	angles.near_upper_arm += swing * (19.0 if running else 10.0)
	angles.far_upper_arm -= swing * (19.0 if running else 10.0)
	angles.near_forearm += (8.0 if running else 4.0) * cos(phase) if moving else 0.0
	angles["far_forearm"] = -maxf(0.0, swing) * (20.0 if running else 7.0)
	angles["near_thigh"] = -swing * stride
	angles["far_thigh"] = swing * stride
	angles["near_shin"] = maxf(0.0, swing) * (42.0 if running else 22.0)
	angles["far_shin"] = maxf(0.0, -swing) * (42.0 if running else 22.0)
	angles["torso"] = (-4.0 if running else 0.0) + sin(phase) * (1.0 if moving else 0.35)
	angles["head"] = -float(angles.torso)
	for n in bones:
		bones[n].apply_rest()
		bones[n].rotation = deg_to_rad(float(angles.get(n, 0.0)))
	var factor := 128.0 / (239.0 if gender == "male" else 229.0)
	var reflected := dir_index == 1 or dir_index == 3
	rig.scale = Vector2(-factor if reflected else factor, factor)
	# Stance foot contacts a common local floor; airborne run keys are explicit.
	var floor_y := 0.0
	for name_ in ["near_foot", "far_foot"]:
		var b: Dictionary = definitions[name_]
		var tip := Vector2(b.tip[0], b.tip[1]) - Vector2(b.at[0], b.at[1])
		var point: Vector2 = skeleton.to_local(bones[name_].to_global(tip))
		floor_y = maxf(floor_y, point.y + 5.0)
	var air := 4.0 if running and int((frame - 12) % 4) in [1, 2] else 0.0
	rig.position = Vector2(96.0, 168.0 - air) - Vector2(122.0 * rig.scale.x, floor_y * factor)

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
			for n in visuals:
				visuals[n].texture = texture(work_root + "/pixel-assets/prototype-actors/source-textures/" + gender + "-" + direction + "-" + n + ".png")
			for f in range(20):
				apply_pose(f, d)
				for n in LAYERS:
					for other in visuals:
						visuals[other].visible = other == n
					await process_frame
					await RenderingServer.frame_post_draw
					var im := viewport.get_texture().get_image()
					atlases[n].blit_rect(im, Rect2i(0, 0, 192, 192), Vector2i(f * 192, d * 192))
			print("BAKED ", gender, " ", direction)
		for n in LAYERS:
			atlases[n].save_png(work_root + "/pixel-assets/prototype-actors/baked-layers/" + gender + "-" + n + ".png")
		viewport.queue_free()
		await process_frame
	print("ACTOR BAKE COMPLETE")
	quit()
