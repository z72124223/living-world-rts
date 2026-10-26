extends Node2D

var legacy := false
var data: Dictionary
var mesh_data: Dictionary
var skeleton: Skeleton2D
var bones: Dictionary = {}
var polygons: Array[Polygon2D] = []
var show_wire := true
var show_bones := true
var show_reference := false
var show_face := true
var line_color := Color("69edc9")
var overlay: Node2D
var reference: Sprite2D
var face: Sprite2D
var font: Font
var mesh_path := "res://assets/body-mesh.json"
var rig_path := ""
var reference_path := "res://assets/female-preview.png"
var texture_prefix := "res://assets/body-v03-"
var head_path := "res://assets/body-head.png"
var textured := false
var bone_lookup: Dictionary = {}
var wire_opacity := .62
var wire_width := .30

func _ready() -> void:
	var source_path:=rig_path if rig_path!="" else ("res://assets/character-before.json" if legacy else "res://assets/character.json")
	data=JSON.parse_string(FileAccess.get_file_as_string(source_path))
	mesh_data=JSON.parse_string(FileAccess.get_file_as_string(mesh_path))
	for b in data.bones:bone_lookup[b.name]=b
	font=load("res://assets/ui-font.otf")
	line_color=Color("fa967f") if legacy else Color("69edc9")
	skeleton=Skeleton2D.new();skeleton.name="BodySkeleton";add_child(skeleton)
	for b in data.bones:
		var bone:=Bone2D.new();bone.name=b.name
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(float(b.length))
		bone.set_bone_angle(-PI/2 if legacy else float(b.angle))
		var at:=Vector2(b.at[0],b.at[1])
		if b.parent=="":skeleton.add_child(bone)
		else:
			bones[b.parent].add_child(bone)
			var parent: Dictionary=bone_data(b.parent)
			at-=Vector2(parent.at[0],parent.at[1])
		bone.position=at;bone.rest=Transform2D(0,at)
		bones[b.name]=bone
	for m in mesh_data.meshes:
		var seen_edges: Dictionary={}
		var unique_edges: Array=[]
		for tri in m.triangles:
			for j in range(3):
				var a:=int(tri[j]);var b:=int(tri[(j+1)%3])
				var key:=str(mini(a,b))+":"+str(maxi(a,b))
				if not seen_edges.has(key):seen_edges[key]=true;unique_edges.append([a,b])
		m["_edges"]=unique_edges
		var poly:=Polygon2D.new();poly.name=m.name
		var vertices:=PackedVector2Array()
		var colors:=PackedColorArray()
		for i in range(m.vertices.size()):
			vertices.append(Vector2(m.vertices[i][0],m.vertices[i][1]))
			var shade: float=[.78,.93,1.0,.93,.76][i%5]
			colors.append(Color(.64,.70,.72)*Color(shade,shade,shade))
		poly.polygon=vertices;poly.vertex_colors=colors
		if textured:
			poly.texture=load(texture_prefix+m.name+".png")
			poly.uv=vertices;poly.vertex_colors=PackedColorArray()
			poly.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var triangles: Array=[]
		for tri in m.triangles:triangles.append(PackedInt32Array(tri))
		poly.polygons=triangles;add_child(poly)
		poly.skeleton=poly.get_path_to(skeleton)
		var weights: Dictionary={}
		for i in range(m.weights.size()):
			for key in m.weights[i]:
				var bone_name:=resolve_bone(key)
				if not weights.has(bone_name):
					var values:=PackedFloat32Array();values.resize(m.vertices.size());weights[bone_name]=values
				weights[bone_name][i]+=float(m.weights[i][key])
		for n in weights:poly.add_bone(skeleton.get_path_to(bones[n]),weights[n])
		polygons.append(poly)
	face=Sprite2D.new();face.texture=load(head_path)
	face.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	face.position=Vector2(128,128)-Vector2(bone_data("head").at[0],bone_data("head").at[1])
	face.z_index=4;bones.head.add_child(face)
	reference=Sprite2D.new();reference.texture=load(reference_path)
	reference.position=Vector2(128,128);reference.modulate.a=.34;reference.z_index=8
	reference.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(reference)
	overlay=Node2D.new();overlay.z_index=20;add_child(overlay);overlay.draw.connect(_draw_overlay)
	set_pose({})

func resolve_bone(n: String) -> String:
	if bones.has(n):return n
	return {"far_foot":"far_shin","near_foot":"near_shin","far_hand":"far_forearm"}.get(n,n)

func bone_data(n: String) -> Dictionary:
	return bone_lookup.get(n,{})

func set_pose(angles: Dictionary) -> void:
	for n in bones:
		bones[n].apply_rest()
		bones[n].rotation=deg_to_rad(float(angles.get(n,0)))
	refresh()

func refresh() -> void:
	if is_instance_valid(reference):reference.visible=show_reference
	if is_instance_valid(face):face.visible=show_face
	if is_instance_valid(overlay):overlay.queue_redraw()

func skinned_vertices(m: Dictionary) -> PackedVector2Array:
	var transformed:=PackedVector2Array()
	for i in range(m.vertices.size()):
		var p:=Vector2(m.vertices[i][0],m.vertices[i][1]);var v:=Vector2.ZERO
		for n in m.weights[i]:
			var resolved:=resolve_bone(n)
			var b: Dictionary=bone_data(resolved)
			v+=to_local(bones[resolved].to_global(p-Vector2(b.at[0],b.at[1])))*float(m.weights[i][n])
		transformed.append(v)
	return transformed

func _draw_overlay() -> void:
	if show_wire:
		for m in mesh_data.meshes:
			if m.name=="head" and show_face:continue
			var vertices:=skinned_vertices(m)
			for edge in m._edges:overlay.draw_line(vertices[edge[0]],vertices[edge[1]],Color(.14,.26,.29,wire_opacity),wire_width,true)
	if show_bones:
		for b in data.bones:
			if b.name in ["weapon","sash"]:continue
			var bone: Bone2D=bones[b.name]
			var p:=to_local(bone.global_position)
			var q:=to_local(bone.to_global(Vector2.from_angle(bone.get_bone_angle())*bone.get_length()))
			# Bone segments show their real length/angle, rather than substituting
			# the parent-child links (which concealed the old length bug).
			overlay.draw_line(p,q,Color(.04,.07,.09,.9),1.5,true)
			overlay.draw_line(p,q,line_color,.85,true)
			overlay.draw_circle(p,1.6,Color("f6d993"))
			overlay.draw_circle(q,.8,line_color)
			if not legacy and b.name in ["far_upper_arm","far_forearm","far_hand","far_thigh","far_shin","far_foot","near_upper_arm","near_forearm","hand","near_thigh","near_shin","near_foot"]:
				var far: bool=b.name.begins_with("far_")
				var dx: float=-22 if far else 7
				var label_pos:=p+Vector2(dx,-2)
				overlay.draw_line(p+Vector2(-3 if far else 3,0),p+Vector2(-7 if far else 6,-2),Color(line_color,.6),.35,true)
				overlay.draw_set_transform(label_pos,0,Vector2.ONE/scale)
				overlay.draw_string(font,Vector2.ZERO,b.label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff4d8"))
				overlay.draw_set_transform(Vector2.ZERO)

func geometry_report() -> Dictionary:
	var max_weight_error:=0.0;var vertex_count:=0;var triangle_count:=0
	for m in mesh_data.meshes:
		vertex_count+=m.vertices.size();triangle_count+=m.triangles.size()
		for weights in m.weights:
			var total:=0.0
			for n in weights:total+=float(weights[n])
			max_weight_error=maxf(max_weight_error,absf(total-1))
	var max_endpoint_error:=0.0
	if not legacy:
		for pair in [["far_upper_arm","far_forearm"],["far_forearm","far_hand"],["near_upper_arm","near_forearm"],["near_forearm","hand"],["far_thigh","far_shin"],["far_shin","far_foot"],["near_thigh","near_shin"],["near_shin","near_foot"]]:
			var bone: Bone2D=bones[pair[0]]
			var end:=bone.to_global(Vector2.from_angle(bone.get_bone_angle())*bone.get_length())
			max_endpoint_error=maxf(max_endpoint_error,end.distance_to(bones[pair[1]].global_position)/scale.x)
	return {"vertices":vertex_count,"triangles":triangle_count,"mesh_parts":polygons.size(),"bones":bones.size(),"max_weight_error":max_weight_error,"max_endpoint_error_px":max_endpoint_error}
