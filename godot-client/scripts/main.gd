extends Node2D

const Warrior = preload("res://scripts/warrior.gd")
const MAP_RECT := Rect2(20,94,918,640)
const INK := Color("e9e4d6")
const MUTED := Color("9aaaa9")
const ACCENT := Color("cfaa67")
var actor: CharacterBody2D
var background: Texture2D
var target_texture: Texture2D
var slash_texture: Texture2D
var target_pos := Vector2(755,485)
var hit_count := 0
var target_flash := 0.0
var effect_time := -1.0
var click_mark := Vector2(-100,-100)
var click_time := 0.0
var ui: CanvasLayer
var status_label: Label
var frame_label: Label
var hit_label: Label
var outfit_buttons: Array[Button] = []
var weapon_buttons: Array[Button] = []
var mode_buttons: Array[Button] = []
var pause_button: Button
var bone_button: Button
var font: Font
var capture_mode := false

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	background=load("res://assets/courtyard.png")
	target_texture=load("res://assets/training-target.png")
	slash_texture=load("res://assets/slash.png")
	font=load("res://assets/ui-font.otf")
	actor=Warrior.new()
	actor.name="FemaleWarrior"
	actor.position=Vector2(456,601)
	add_child(actor)
	actor.strike.connect(_on_strike)
	var obstacle := StaticBody2D.new()
	obstacle.position=target_pos
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius=21
	cs.shape=circle
	obstacle.add_child(cs)
	add_child(obstacle)
	_build_ui()
	capture_mode="--capture-tests" in OS.get_cmdline_user_args()
	if capture_mode:call_deferred("_capture_tests")

func _panel(rect: Rect2, color: Color) -> Panel:
	var p:=Panel.new()
	p.position=rect.position;p.size=rect.size
	var s:=StyleBoxFlat.new();s.bg_color=color;s.corner_radius_top_left=12;s.corner_radius_top_right=12;s.corner_radius_bottom_left=12;s.corner_radius_bottom_right=12
	s.border_width_left=1;s.border_width_right=1;s.border_width_top=1;s.border_width_bottom=1;s.border_color=Color("334349")
	p.add_theme_stylebox_override("panel",s);ui.add_child(p);return p

func _label(text: String, pos: Vector2, size: int=17, color: Color=INK) -> Label:
	var l:=Label.new();l.text=text;l.position=pos;l.add_theme_font_override("font",font);l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);ui.add_child(l);return l

func _button(text: String, rect: Rect2, cb: Callable) -> Button:
	var b:=Button.new();b.text=text;b.position=rect.position;b.size=rect.size;b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_override("font",font);b.add_theme_font_size_override("font_size",15)
	for state in ["normal","hover","pressed"]:
		var s:=StyleBoxFlat.new();s.bg_color=Color("26393c") if state=="normal" else Color("415b57")
		s.corner_radius_top_left=6;s.corner_radius_top_right=6;s.corner_radius_bottom_left=6;s.corner_radius_bottom_right=6
		s.border_width_bottom=2;s.border_color=Color("698378")
		b.add_theme_stylebox_override(state,s)
	b.pressed.connect(cb);ui.add_child(b);return b

func _build_ui() -> void:
	ui=CanvasLayer.new();add_child(ui)
	_label("女性武將  /  像素練武場",Vector2(28,18),28)
	_label("可操作樣品 · 人物分件、動作與換裝",Vector2(30,58),14,MUTED)
	_label("ASEPRITE  ×  GODOT",Vector2(983,39),15,ACCENT)
	_button("人體網格校準",Rect2(730,27,200,40),func():get_tree().change_scene_to_file("res://scenes/body_contour.tscn"))
	_panel(Rect2(958,94,302,640),Color("19292e"))
	_label("人物裝備",Vector2(979,113),22)
	_label("服裝",Vector2(980,157),14,MUTED)
	for i in range(2):
		var value: String=["cloth","armour"][i]
		outfit_buttons.append(_button(["青衣","輕甲"][i],Rect2(980+i*128,183,117,40),func():actor.outfit=value;actor.apply_gear();_refresh()))
	_label("武器",Vector2(980,240),14,MUTED)
	for i in range(3):
		var value: String=["none","sword","spear"][i]
		weapon_buttons.append(_button(["空手","佩劍","長槍"][i],Rect2(980+i*86,266,78,39),func():actor.weapon=value;actor.apply_gear();_refresh()))
	_label("動作",Vector2(980,324),14,MUTED)
	_button("待機",Rect2(980,351,78,39),func():actor.preview_motion="idle";actor.motion="idle";actor.elapsed=0;actor.attacking=false;actor.paused=false)
	_button("走路",Rect2(1066,351,78,39),func():actor.preview_motion="walk";actor.motion="walk";actor.elapsed=0;actor.paused=false)
	_button("攻擊",Rect2(1152,351,78,39),func():actor.attack())
	_label("動畫方式",Vector2(980,412),14,MUTED)
	for i in range(2):
		var value: String=["bones","frames"][i]
		mode_buttons.append(_button(["骨架連動","逐格播放"][i],Rect2(980+i*128,439,117,39),func():actor.mode=value;_refresh()))
	pause_button=_button("暫停",Rect2(980,490,117,38),func():actor.paused=not actor.paused;_refresh())
	_button("下一格",Rect2(1108,490,117,38),func():actor.step_frame();_refresh())
	bone_button=_button("顯示骨架",Rect2(980,541,245,38),func():actor.show_bones=not actor.show_bones;_refresh())
	frame_label=_label("",Vector2(982,599),14,ACCENT)
	hit_label=_label("",Vector2(982,630),16)
	_label("靠近木樁後攻擊，觀察命中特效。",Vector2(982,671),13,MUTED)
	status_label=_label("",Vector2(30,752),15,ACCENT)
	_label("WASD／方向鍵移動 · 點地面前往 · 空白鍵攻擊 · B 骨架",Vector2(31,715),15,INK)
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(frame_label):return
	for i in range(2):outfit_buttons[i].modulate=Color("efd49b") if actor.outfit==["cloth","armour"][i] else Color.WHITE
	for i in range(3):weapon_buttons[i].modulate=Color("efd49b") if actor.weapon==["none","sword","spear"][i] else Color.WHITE
	for i in range(2):mode_buttons[i].modulate=Color("efd49b") if actor.mode==["bones","frames"][i] else Color.WHITE
	pause_button.text="繼續" if actor.paused else "暫停"
	bone_button.text="隱藏骨架" if actor.show_bones else "顯示骨架"
	status_label.text=("輕甲" if actor.outfit=="armour" else "青衣")+"  ·  "+{"none":"空手","sword":"佩劍","spear":"長槍"}[actor.weapon]+"  ·  "+("骨架連動" if actor.mode=="bones" else "Aseprite 逐格動畫")

func _process(delta: float) -> void:
	target_flash=maxf(0,target_flash-delta)
	click_time=maxf(0,click_time-delta)
	if effect_time>=0:
		effect_time+=delta
		if effect_time>.27:effect_time=-1
	if is_instance_valid(frame_label):
		frame_label.text={"idle":"待機","walk":"走路","attack":"攻擊"}.get(actor.motion,actor.motion)+"  ·  第 "+str(actor.frame_index+1)+" / 18 格"
		hit_label.text="木樁命中  "+str(hit_count)+" 次"
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE:actor.attack()
			KEY_B:actor.show_bones=not actor.show_bones;_refresh()
			KEY_1:actor.outfit="cloth" if actor.outfit=="armour" else "armour";actor.apply_gear();_refresh()
			KEY_2:actor.weapon="spear" if actor.weapon=="sword" else "sword";actor.apply_gear();_refresh()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and MAP_RECT.has_point(event.position):
		actor.destination=Vector2(clampf(event.position.x,110,875),clampf(event.position.y,340,712))
		actor.has_destination=true;click_mark=actor.destination;click_time=.7

func _on_strike() -> void:
	effect_time=0
	var reach: float={"none":104.0,"sword":164.0,"spear":214.0}[actor.weapon]
	var dx: float=target_pos.x-actor.position.x
	var looking_at_target: bool=absf(dx)<30 or signf(dx)==-actor.facing
	if actor.position.distance_to(target_pos)<reach and looking_at_target:
		hit_count+=1;target_flash=.35

func _draw() -> void:
	if background==null:return
	draw_texture_rect(background,MAP_RECT,false)
	draw_rect(MAP_RECT,Color("596250"),false,2)
	var shadow:=actor.position+Vector2(0,2)
	draw_set_transform(shadow,0,Vector2(1,.28));draw_circle(Vector2.ZERO,40,Color(0.10,.12,.10,.35));draw_set_transform(Vector2.ZERO)
	draw_set_transform(target_pos+Vector2(0,2),0,Vector2(1,.3));draw_circle(Vector2.ZERO,40,Color(0.1,.1,.08,.4));draw_set_transform(Vector2.ZERO)
	var wobble:=sin(target_flash*70)*target_flash*10
	draw_texture_rect(target_texture,Rect2(target_pos+Vector2(-40+wobble,-112),Vector2(80,120)),false,Color(1.4,1.2,.8) if target_flash>0 else Color.WHITE)
	if click_time>0:draw_arc(click_mark,10+(1-click_time/.7)*10,0,TAU,24,Color(.78,.82,.5,click_time/.7),2)
	if effect_time>=0:
		var frame:=mini(5,int(effect_time/.045))
		var centre:=actor.position+Vector2(-actor.facing*63,-103)
		draw_texture_rect_region(slash_texture,Rect2(centre-Vector2(64,64),Vector2(128,128)),Rect2(frame*128,0,128,128))

func _set_test_frame(index: int) -> void:
	var f: Dictionary=actor.data.frames[index]
	actor.paused=true;actor.motion=f.animation;actor.elapsed=(float(f.index)-.99)*float(f.duration);actor.apply_frame(index)

func _save_capture(name: String) -> void:
	_refresh()
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	image.save_png("res://verification/"+name+".png")

func _capture_tests() -> void:
	await get_tree().create_timer(.5).timeout
	actor.user_control=false
	_set_test_frame(0)
	await _save_capture("01-armour-bones")
	var checks: Dictionary={"bone_count":actor.skeleton.get_bone_count(),"part_count":actor.sprites.size(),"animation_frames":actor.data.frames.size()}
	actor.outfit="cloth";actor.weapon="spear";actor.apply_gear();_set_test_frame(6)
	checks.cloth_hides_armour=not actor.sprites.armour_torso.visible
	checks.spear_visible=actor.sprites.long_spear.visible and not actor.sprites.drawn_sword.visible
	actor.show_bones=true
	await _save_capture("02-cloth-spear-bones")
	actor.mode="frames";actor.show_bones=false;_set_test_frame(8)
	await _save_capture("03-aseprite-frames")
	checks.frame_mode_visible=actor.flat.visible and not actor.skeleton.visible
	actor.mode="bones";actor.outfit="armour";actor.weapon="sword";actor.apply_gear();actor.position=target_pos+Vector2(-95,70);actor.facing=-1
	actor.attack()
	await get_tree().create_timer(.34).timeout
	await _save_capture("04-attack-hit")
	await get_tree().create_timer(.45).timeout
	checks.attack_hit=hit_count>0
	var old_position: Vector2=actor.position
	actor.paused=false;actor.user_control=true;actor.has_destination=true;actor.destination=actor.position+Vector2(-60,0)
	await get_tree().create_timer(.22).timeout
	checks.movement=actor.position.distance_to(old_position)>12
	checks.snapshot=actor.snapshot()
	checks.pass=checks.bone_count==17 and checks.part_count>=20 and checks.animation_frames==18 and checks.cloth_hides_armour and checks.spear_visible and checks.frame_mode_visible and checks.attack_hit and checks.movement
	var file:=FileAccess.open("res://verification/runtime-report.json",FileAccess.WRITE);file.store_string(JSON.stringify(checks,"\t"));file.close()
	print("PIXEL_RUNTIME_VERIFIED "+JSON.stringify(checks))
	get_tree().quit(0 if checks.pass else 1)
