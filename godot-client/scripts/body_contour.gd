extends Node2D

const BodyRig=preload("res://scripts/body_rig.gd")
var rig: Node2D
var ui: CanvasLayer
var font: Font
var slider: HSlider
var angle_label: Label
var status: Label
var play_button: Button
var joint := "near_forearm"
var joint_label := "近肘"
var auto_play := false
var elapsed := 0.0
var wire_button: Button
var bones_button: Button
var master_button: Button
var silhouette_button: Button
var master: Sprite2D
var mask_mode := false
var overlay_edge: Node2D
var measured := false
var mask_result: Dictionary = {}
var character := "male"
var entry: Dictionary
var prefix: String

func asset(suffix: String) -> String:
	return "res://assets/"+prefix+suffix

func select_character(key: String) -> void:
	get_tree().set_meta("body_character",key)
	get_tree().reload_current_scene()

func make_rig() -> Node2D:
	var body=BodyRig.new()
	body.mesh_path=asset("-mesh.json")
	body.rig_path=asset("-rig.json")
	body.reference_path=asset("-preview.png")
	body.texture_prefix=asset("-")
	body.head_path="res://assets/"+entry.head
	body.textured=true
	body.wire_opacity=.42;body.wire_width=.18
	return body

func _ready() -> void:
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/body-catalog.json"))
	if get_tree().has_meta("body_character"):
		character=str(get_tree().get_meta("body_character"))
	elif OS.has_feature("web"):
		var requested=JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('character')")
		if requested is String and catalog.has(requested):character=requested
	else:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--character=") and catalog.has(arg.trim_prefix("--character=")):character=arg.trim_prefix("--character=")
	entry=catalog[character];prefix=entry.prefix
	font=load("res://assets/ui-font.otf")
	rig=make_rig();rig.position=Vector2(417,155);rig.scale=Vector2(2.35,2.35);add_child(rig)
	master=Sprite2D.new();master.texture=load(asset("-preview.png"));master.position=Vector2(-51,155)+Vector2(128,128)*2.35;master.scale=Vector2(2.35,2.35);master.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(master)
	ui=CanvasLayer.new();add_child(ui)
	label(entry.name+"  /  曲線・網格・骨架",Vector2(24,14),27)
	button("女性成品"+(" ✓" if character=="female" else ""),Rect2(960,19,142,42),func():select_character("female"))
	button("男性成品"+(" ✓" if character=="male" else ""),Rect2(1113,19,142,42),func():select_character("male"))
	label("先定身形，再驗證輪廓貼合與關節彎曲",Vector2(26,53),15,Color("a3b5bb"))
	label("人體曲線稿",Vector2(34,96),23,Color("e5c59a"))
	label("同一輪廓的網格＋骨架",Vector2(504,96),22,Color("69edc9"))
	label(("造型已確認" if entry.approved else "新樣品 · 待你確認造型")+"  /  v"+entry.version,Vector2(34,132),13,Color("bba996"))
	label("從曲線稿產生網格邊界，使用相同尺寸",Vector2(504,132),13,Color("9bbfb8"))
	label("檢查身形與動作",Vector2(993,98),21)
	button("還原站姿",Rect2(993,141,249,40),func():auto_play=false;slider.value=0;apply_pose())
	label("選擇關節",Vector2(993,194),14,Color("a3b5bb"))
	for i in range(6):
		var key: String=["near_upper_arm","near_forearm","near_thigh","near_shin","far_thigh","far_shin"][i]
		var title: String=["近肩","近肘","近髖","近膝","遠髖","遠膝"][i]
		button(title,Rect2(993+(i%2)*129,223+(i/2)*43,120,36),func():joint=key;joint_label=title;auto_play=false;slider.value=0;apply_pose())
	angle_label=label("",Vector2(995,357),16,Color("f6d993"))
	slider=HSlider.new();slider.position=Vector2(998,394);slider.size=Vector2(238,24);slider.min_value=-35;slider.max_value=35;slider.step=1;slider.focus_mode=Control.FOCUS_NONE
	slider.value_changed.connect(func(_v):apply_pose());ui.add_child(slider)
	play_button=button("來回彎曲",Rect2(993,437,249,36),func():auto_play=not auto_play)
	wire_button=button("網格：開",Rect2(993,489,120,36),func():rig.show_wire=not rig.show_wire;refresh())
	bones_button=button("骨架：開",Rect2(1122,489,120,36),func():rig.show_bones=not rig.show_bones;refresh())
	master_button=button("原稿疊合",Rect2(993,533,120,36),func():rig.show_reference=not rig.show_reference;refresh())
	silhouette_button=button("純輪廓",Rect2(1122,533,120,36),func():mask_mode=not mask_mode;refresh())
	status=label("正在驗證站姿輪廓…",Vector2(993,588),14,Color("8edbbc"))
	label(("已確認的"+entry.name+"基準。" if entry.approved else "骨長與關節依角色獨立配置。")+"\n原檔與版本已收錄素材庫。",Vector2(993,647),13,Color("a3b5bb"))
	button("練武場",Rect2(993,703,120,37),func():get_tree().change_scene_to_file("res://scenes/main.tscn"))
	button("素材庫",Rect2(1122,703,120,37),func():OS.shell_open("http://127.0.0.1:8780/library/"))
	label("左：身形基準　右：實際變形網格　金點：關節　綠線：骨段",Vector2(30,759),15,Color("c7d4d5"))
	apply_pose()
	call_deferred("verify_contour")

func label(text: String, pos: Vector2, size: int=16, color: Color=Color("e9e9e1")) -> Label:
	var l:=Label.new();l.text=text;l.position=pos;l.add_theme_font_override("font",font);l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);ui.add_child(l);return l

func button(text: String, rect: Rect2, action: Callable) -> Button:
	var b:=Button.new();b.text=text;b.position=rect.position;b.size=rect.size;b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_override("font",font);b.add_theme_font_size_override("font_size",15)
	for state in ["normal","hover","pressed"]:
		var style:=StyleBoxFlat.new();style.bg_color=Color("24383e") if state=="normal" else Color("395952")
		style.corner_radius_top_left=6;style.corner_radius_top_right=6;style.corner_radius_bottom_left=6;style.corner_radius_bottom_right=6
		b.add_theme_stylebox_override(state,style)
	b.pressed.connect(action);ui.add_child(b);return b

func apply_pose() -> void:
	if not is_instance_valid(slider):return
	rig.set_pose({joint:slider.value});refresh()

func refresh() -> void:
	rig.refresh()
	if not is_instance_valid(slider):return
	angle_label.text=joint_label+"  "+str(int(slider.value))+"°"
	wire_button.text="網格："+("開" if rig.show_wire else "關")
	bones_button.text="骨架："+("開" if rig.show_bones else "關")
	master_button.text="疊合："+("開" if rig.show_reference else "關")
	silhouette_button.text="顯示造型" if mask_mode else "純輪廓"
	for poly in rig.polygons:poly.modulate=Color(.48,.58,.63) if mask_mode else Color.WHITE
	master.modulate=Color(.48,.58,.63) if mask_mode else Color.WHITE
	if measured:
		if absf(slider.value)>.01:status.text="彎曲預覽\n還原站姿後檢查輪廓貼合"
		else:status.text="站姿輪廓差異："+str(mask_result.missing+mask_result.extra)+" 像素\n人體與網格共用同一輪廓"

func _process(delta: float) -> void:
	if auto_play:elapsed+=delta;slider.value=sin(elapsed*1.5)*25
	if is_instance_valid(play_button):play_button.text="停止彎曲" if auto_play else "來回彎曲"

func _draw() -> void:
	draw_rect(Rect2(18,85,455,659),Color("17262d"));draw_rect(Rect2(486,85,475,659),Color("172b2d"));draw_rect(Rect2(976,85,286,659),Color("17252d"))
	for offset in [-51,417]:
		for x in range(75,181,10):draw_line(Vector2(offset+x*2.35,165),Vector2(offset+x*2.35,729),Color(.3,.4,.43,.12),1)
		for y in range(10,241,10):draw_line(Vector2(offset+75*2.35,155+y*2.35),Vector2(offset+180*2.35,155+y*2.35),Color(.3,.4,.43,.12),1)

func verify_contour() -> void:
	# Compare the actual untextured Godot mesh silhouette to the Aseprite
	# master alpha. Textures cannot conceal an oversized mesh in this check.
	var viewport:=SubViewport.new();viewport.size=Vector2i(256,256);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var probe=make_rig();probe.show_face=false;probe.show_wire=false;probe.show_bones=false;viewport.add_child(probe)
	for poly in probe.polygons:poly.texture=null;poly.vertex_colors=PackedColorArray();poly.color=Color.WHITE
	probe.refresh()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var rendered:=viewport.get_texture().get_image()
	var reference: Image=load(asset("-master.png")).get_image()
	var missing:=0;var extra:=0;var union_count:=0;var intersection:=0
	var difference:=Image.create(256,256,false,Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var a:=reference.get_pixel(x,y).a>.5;var b:=rendered.get_pixel(x,y).a>.5
			if a or b:union_count+=1
			if a and b:intersection+=1
			if a and not b:missing+=1;difference.set_pixel(x,y,Color("6bdcfa"))
			if b and not a:extra+=1;difference.set_pixel(x,y,Color("fb74af"))
	mask_result={"missing":missing,"extra":extra,"reference_pixels":rig.mesh_data.master_pixels,"iou":float(intersection)/maxi(1,union_count),"method":"Actual untextured Polygon2D GPU alpha vs Aseprite body master"}
	measured=true;refresh()
	if "--capture-contour-tests" in OS.get_cmdline_user_args():
		rendered.save_png("res://verification/"+prefix+"-gpu-mask.png");difference.save_png("res://verification/"+prefix+"-mask-difference.png")
	viewport.queue_free()
	if "--capture-contour-tests" in OS.get_cmdline_user_args():await capture_tests()

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://verification/"+name+".png")

func capture_tests() -> void:
	await capture(prefix+"-rest")
	var report: Dictionary=rig.geometry_report()
	report.contour=mask_result
	var arm: Dictionary=rig.mesh_data.meshes[4]
	var before: PackedVector2Array=rig.skinned_vertices(arm)
	joint="near_forearm";joint_label="近肘";slider.value=25;apply_pose()
	await capture(prefix+"-elbow")
	var after: PackedVector2Array=rig.skinned_vertices(arm)
	var max_movement:=0.0
	for i in range(before.size()):max_movement=maxf(max_movement,before[i].distance_to(after[i]))
	report.elbow_vertex_movement_px=max_movement
	report.posed_endpoint_error_px=rig.geometry_report().max_endpoint_error_px
	joint="near_shin";joint_label="近膝";slider.value=25;apply_pose()
	await capture(prefix+"-knee")
	report.knee_endpoint_error_px=rig.geometry_report().max_endpoint_error_px
	report.art_approved=entry.approved
	report.character_id=entry.id
	report.version=entry.version
	report.input_sha256={}
	for suffix in ["-mesh.json","-rig.json","-master.png","-preview.png","-far_leg.png","-near_leg.png","-far_arm.png","-torso_pelvis.png","-near_arm.png"]:
		report.input_sha256[asset(suffix).get_file()]=FileAccess.get_sha256(asset(suffix))
	report.input_sha256[entry.head]=FileAccess.get_sha256("res://assets/"+entry.head)
	report.nude_reference_available=false
	report.pass=mask_result.missing==0 and mask_result.extra==0 and report.max_weight_error<.0001 and report.posed_endpoint_error_px<.001 and report.knee_endpoint_error_px<.001 and max_movement>4
	var f:=FileAccess.open("res://verification/"+prefix+"-report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("BODY_CONTOUR_VERIFIED "+JSON.stringify(report))
	get_tree().quit(0 if report.pass else 1)
