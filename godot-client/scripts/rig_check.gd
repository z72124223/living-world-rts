extends Node2D

const BodyRig=preload("res://scripts/body_rig.gd")
var old_rig: Node2D
var new_rig: Node2D
var font: Font
var ui: CanvasLayer
var slider: HSlider
var angle_label: Label
var info: Label
var joint := "near_forearm"
var selected := "近肘"
var auto_play := false
var clock := 0.0
var wire_button: Button
var bones_button: Button
var reference_button: Button
var face_button: Button
var play_button: Button

func _ready() -> void:
	font=load("res://assets/ui-font.otf")
	old_rig=BodyRig.new();old_rig.legacy=true;old_rig.position=Vector2(-71,113);old_rig.scale=Vector2(2.5,2.5);add_child(old_rig)
	new_rig=BodyRig.new();new_rig.position=Vector2(397,113);new_rig.scale=Vector2(2.5,2.5);add_child(new_rig)
	ui=CanvasLayer.new();add_child(ui)
	label("人體網格 × 骨架校準",Vector2(24,14),27)
	label("無衣物的人形結構 · 同一網格比較關節位置、骨段長度與彎曲",Vector2(26,52),15,Color("a3b5bb"))
	label("舊骨架",Vector2(34,96),23,Color("fa967f"))
	label("修正骨架",Vector2(504,96),23,Color("69edc9"))
	label("髖點落在大腿中段 · 骨段方向固定朝上",Vector2(34,128),12,Color("ba9690"))
	label("肩 → 肘 → 腕 ／ 髖 → 膝 → 踝",Vector2(504,128),12,Color("9ecac0"))
	label("檢查動作",Vector2(993,98),22)
	button("還原站姿",Rect2(993,139,249,40),func():auto_play=false;slider.value=0;apply_pose())
	label("選一個關節，再拖曳角度",Vector2(995,194),14,Color("a3b5bb"))
	for i in range(4):
		var key: String=["near_upper_arm","near_forearm","near_thigh","near_shin"][i]
		var title: String=["近肩","近肘","近髖","近膝"][i]
		button(title,Rect2(993+(i%2)*129,225+(i/2)*45,120,38),func():joint=key;selected=title;auto_play=false;slider.value=0;apply_pose())
	angle_label=label("",Vector2(995,327),17,Color("f6d993"))
	slider=HSlider.new();slider.position=Vector2(998,367);slider.size=Vector2(238,24);slider.min_value=-45;slider.max_value=45;slider.step=1;slider.focus_mode=Control.FOCUS_NONE
	slider.value_changed.connect(func(_v):apply_pose());ui.add_child(slider)
	play_button=button("來回彎曲",Rect2(993,408,249,38),func():auto_play=not auto_play)
	wire_button=button("網格：開",Rect2(993,464,120,38),func():new_rig.show_wire=not new_rig.show_wire;old_rig.show_wire=new_rig.show_wire;refresh())
	bones_button=button("骨架：開",Rect2(1122,464,120,38),func():new_rig.show_bones=not new_rig.show_bones;old_rig.show_bones=new_rig.show_bones;refresh())
	face_button=button("頭像：開",Rect2(993,512,120,38),func():new_rig.show_face=not new_rig.show_face;old_rig.show_face=new_rig.show_face;refresh())
	reference_button=button("原圖疊合",Rect2(1122,512,120,38),func():new_rig.show_reference=not new_rig.show_reference;old_rig.show_reference=new_rig.show_reference;refresh())
	info=label("",Vector2(994,570),14,Color("a3b5bb"))
	button("回到練武場",Rect2(993,701,249,41),func():get_tree().change_scene_to_file("res://scenes/main.tscn"))
	label("灰色：無衣物、無性徵細節的人體網格　　金點：旋轉關節　　線末端：骨段真正端點",Vector2(30,759),15,Color("c7d4d5"))
	label("身形為依原圖重建的校準網格。\n骨架位置仍可繼續調整。",Vector2(993,638),13,Color("a3b5bb"))
	apply_pose()
	if "--capture-rig-tests" in OS.get_cmdline_user_args():call_deferred("capture_tests")

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
	var angles: Dictionary={joint:slider.value}
	old_rig.set_pose(angles);new_rig.set_pose(angles)
	refresh()

func refresh() -> void:
	old_rig.refresh();new_rig.refresh()
	if not is_instance_valid(slider):return
	angle_label.text=selected+"  "+str(int(slider.value))+"°"
	wire_button.text="網格："+("開" if new_rig.show_wire else "關")
	bones_button.text="骨架："+("開" if new_rig.show_bones else "關")
	face_button.text="頭像："+("開" if new_rig.show_face else "關")
	reference_button.text="原圖："+("開" if new_rig.show_reference else "關")
	var old: Dictionary=old_rig.bone_data(joint);var current: Dictionary=new_rig.bone_data(joint)
	var shift:=Vector2(current.at[0]-old.at[0],current.at[1]-old.at[1])
	info.text="關節位移："+str(snappedf(shift.length(),.1))+" px\n骨段長："+str(old.length)+" → "+str(snappedf(current.length,.1))+" px"

func _process(delta: float) -> void:
	if auto_play:
		clock+=delta;slider.value=sin(clock*1.6)*35
	if is_instance_valid(play_button):play_button.text="停止彎曲" if auto_play else "來回彎曲"

func _draw() -> void:
	draw_rect(Rect2(18,85,455,659),Color("17262d"))
	draw_rect(Rect2(486,85,475,659),Color("172b2d"))
	draw_rect(Rect2(976,85,286,659),Color("17252d"))
	for offset in [-71,397]:
		for x in range(75,181,10):draw_line(Vector2(offset+x*2.5,162),Vector2(offset+x*2.5,720),Color(.3,.4,.43,.14),1)
		for y in range(20,241,10):draw_line(Vector2(offset+75*2.5,113+y*2.5),Vector2(offset+180*2.5,113+y*2.5),Color(.3,.4,.43,.14),1)
		draw_line(Vector2(offset+75*2.5,711),Vector2(offset+180*2.5,711),Color(.45,.6,.62,.6),1)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://verification/"+name+".png")

func capture_tests() -> void:
	await get_tree().create_timer(.4).timeout
	slider.value=0;apply_pose()
	await capture("rig-v02-rest")
	var report: Dictionary=new_rig.geometry_report()
	var arm: Dictionary=new_rig.mesh_data.meshes[4]
	var before: PackedVector2Array=new_rig.skinned_vertices(arm)
	joint="near_forearm";selected="近肘";slider.value=35;apply_pose()
	await capture("rig-v02-elbow")
	var after: PackedVector2Array=new_rig.skinned_vertices(arm)
	report.elbow_changes_hand=before[before.size()-3].distance_to(after[after.size()-3])>5
	report.posed_endpoint_error_px=new_rig.geometry_report().max_endpoint_error_px
	joint="near_shin";selected="近膝";slider.value=35;apply_pose()
	await capture("rig-v02-knee")
	report.knee_endpoint_error_px=new_rig.geometry_report().max_endpoint_error_px
	report.has_garment_mesh=new_rig.mesh_data.garments
	report.pass=report.mesh_parts==6 and report.max_weight_error<.0001 and report.max_endpoint_error_px<.001 and report.posed_endpoint_error_px<.001 and report.knee_endpoint_error_px<.001 and report.elbow_changes_hand and not report.has_garment_mesh
	var f:=FileAccess.open("res://verification/rig-v02-report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("BODY_RIG_VERIFIED "+JSON.stringify(report))
	get_tree().quit(0 if report.pass else 1)
