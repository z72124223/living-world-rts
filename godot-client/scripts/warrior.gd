extends CharacterBody2D

signal strike
var data: Dictionary
var skeleton: Skeleton2D
var bones: Dictionary = {}
var sprites: Dictionary = {}
var flat: Sprite2D
var overlay: Node2D
var outfit := "armour"
var weapon := "sword"
var mode := "bones"
var motion := "idle"
var preview_motion := "idle"
var elapsed := 0.0
var frame_index := 0
var paused := false
var show_bones := false
var attacking := false
var strike_emitted := false
var facing := 1.0
var destination := Vector2.ZERO
var has_destination := false
var user_control := true
var frame_textures: Dictionary = {}

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/character.json"))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	skeleton = Skeleton2D.new()
	skeleton.name = "Skeleton2D"
	skeleton.position = -Vector2(data.foot[0],data.foot[1])
	add_child(skeleton)
	for b in data.bones:
		var bone := Bone2D.new()
		bone.name = b.name
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(float(b.length))
		bone.set_bone_angle(float(b.angle))
		var origin := Vector2(b.at[0],b.at[1])
		if b.parent != "":
			bones[b.parent].add_child(bone)
			var parent_data: Dictionary = _bone_data(b.parent)
			origin -= Vector2(parent_data.at[0],parent_data.at[1])
		else:
			skeleton.add_child(bone)
		bone.position = origin
		bone.rest = Transform2D(0.0,origin)
		bones[b.name] = bone
	for p in data.parts:
		var image := Sprite2D.new()
		image.name = p.name
		image.texture = load("res://assets/parts/"+p.name+".png")
		var b: Dictionary = _bone_data(p.bone)
		image.position = Vector2(128,128)-Vector2(b.at[0],b.at[1])
		image.z_index = int(p.z)
		bones[p.bone].add_child(image)
		sprites[p.name] = image
	flat = Sprite2D.new()
	flat.name = "AsepriteFramePlayback"
	flat.position = Vector2(128,128)-Vector2(data.foot[0],data.foot[1])
	flat.hframes = 6
	flat.vframes = 3
	add_child(flat)
	for variant in data.variants:
		frame_textures[variant] = load("res://assets/frames/"+variant+".png")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12
	shape.shape = circle
	add_child(shape)
	overlay=Node2D.new()
	overlay.name="BoneDebugOverlay"
	overlay.z_index=100
	add_child(overlay)
	overlay.draw.connect(_draw_bones)
	apply_gear()
	apply_frame(0)
	queue_redraw()

func _bone_data(n: String) -> Dictionary:
	for b in data.bones:
		if b.name == n: return b
	return {}

func _physics_process(_delta: float) -> void:
	if not user_control or paused:
		velocity = Vector2.ZERO
		return
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):input.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):input.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):input.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):input.y += 1
	if input.length_squared()>0:
		has_destination = false
	elif has_destination:
		var d := destination-position
		if d.length()<5:has_destination = false
		else:input = d.normalized()
	velocity = input.normalized()*145.0 if not attacking else Vector2.ZERO
	if velocity.x!=0:facing = -1.0 if velocity.x>0 else 1.0
	move_and_slide()
	position.x = clampf(position.x,110,875)
	position.y = clampf(position.y,340,712)
	if not attacking:
		var next_motion := "walk" if velocity.length_squared()>1 else preview_motion
		if motion!=next_motion:motion=next_motion;elapsed=0

func _process(delta: float) -> void:
	if data.is_empty():return
	if not paused:elapsed += delta
	var indices: Array[int] = []
	for i in range(data.frames.size()):
		if data.frames[i].animation==motion:indices.append(i)
	if indices.is_empty():return
	var duration: float = data.frames[indices[0]].duration
	var step := int(elapsed/duration)
	if attacking:
		if step>=3 and not strike_emitted:
			strike_emitted=true
			strike.emit()
		if step>=indices.size():
			attacking=false;motion=preview_motion;elapsed=0;return
	apply_frame(indices[step%indices.size()])
	queue_redraw()

func apply_frame(index: int) -> void:
	frame_index = index
	var key: Dictionary = data.frames[index]
	for b in data.bones:
		var bone: Bone2D = bones[b.name]
		bone.apply_rest()
		bone.rotation = deg_to_rad(float(key.angles.get(b.name,0)))
		if b.parent=="":bone.position.y += float(key.bob)
	skeleton.scale.x=facing
	skeleton.position.x=-float(data.foot[0])*facing
	# Preserve the root anchor when mirroring the flat sprite around the feet.
	flat.scale.x=facing
	flat.position.x=(128-float(data.foot[0]))*facing
	flat.frame=index
	skeleton.visible=mode=="bones"
	flat.visible=mode=="frames"
	queue_redraw()
	if is_instance_valid(overlay):overlay.queue_redraw()

func apply_gear() -> void:
	if data.is_empty():return
	for p in data.parts:
		sprites[p.name].visible=p.gear=="base" or (p.gear=="armour" and outfit=="armour") or p.gear==weapon or (p.gear=="sheath" and weapon=="sword")
	flat.texture=frame_textures[outfit+"_"+weapon]

func attack() -> void:
	if attacking:return
	attacking=true;strike_emitted=false;motion="attack";elapsed=0;paused=false

func step_frame() -> void:
	paused=true
	var next: int = (frame_index+1)%data.frames.size()
	motion=data.frames[next].animation
	attacking=false
	elapsed=float(data.frames[next].index-1)*float(data.frames[next].duration)
	apply_frame(next)

func _draw_bones() -> void:
	if data.is_empty():return
	# The ground shadow is drawn by the scene behind all character parts.
	if show_bones:
		for b in data.bones:
			var bone: Bone2D=bones[b.name]
			var p:=to_local(bone.global_position)
			var tip:=to_local(bone.to_global(Vector2.from_angle(bone.get_bone_angle())*bone.get_length()))
			overlay.draw_line(p,tip,Color(1,.76,.30,.9),1.5)
			overlay.draw_circle(p,3,Color(.39,.95,.87))

func snapshot() -> Dictionary:
	return {"outfit":outfit,"weapon":weapon,"mode":mode,"frame":frame_index,"motion":motion,"bones":bones.size(),"position":[position.x,position.y],"bone_angles":data.frames[frame_index].angles}
