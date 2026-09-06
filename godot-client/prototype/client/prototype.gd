extends Node2D
## Input/presentation only. Formal character, squad, event and save state comes from bridge snapshots.
const MapScript = preload("res://prototype/map/camp_map.gd")
const PropScript = preload("res://prototype/map/map_prop.gd")
const TemporaryActor = preload("res://prototype/client/temporary_actor.gd")
const MockWorld = preload("res://prototype/client/mock_world.gd")
const MiniMap = preload("res://prototype/client/mini_map.gd")
const GOLD := Color("e1c47d")
const INK := Color("d9dfcf")
var map: Node2D
var stage := Node2D.new()
var canopy: Array[Node2D] = []
var camera := Camera2D.new()
var bridge: Node
var actors: Dictionary = {}
var snapshot: Dictionary = {}
var selected: Array[String] = []
var rendered_routes: Dictionary = {}
var pending_interaction: Dictionary = {} # character ID -> assigned event key
var camera_speed := 650.0
var running := false
var demo_mode := false
var request_number := 0
var dragging := false
var drag_start := Vector2.ZERO
var drag_end := Vector2.ZERO
var panning := false
var last_command := "選取隊員後，右鍵地面下令。"
var toast_time := 0.0
var ui := CanvasLayer.new()
var ui_root := Control.new()
var mode_label: Label
var selection_label: Label
var status_label: Label
var log_label: RichTextLabel
var detail_label: Label
var zoom_label: Label
var pace_button: Button
var mini: Control
var squad_options: OptionButton
var cards: Array[Button] = []
var save_button: Button
var load_button: Button
var event_buttons: Dictionary = {}
var event_history := ""
var squad_history := ""
var marker_font: Font

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color("253b32"))
	map = MapScript.new()
	map.z_index = -10
	add_child(map)
	stage.y_sort_enabled = true
	add_child(stage)
	for data in map.props:
		var prop := PropScript.new()
		stage.add_child(prop)
		prop.setup(data)
		if data.kind=="tree": canopy.append(prop)
	camera.position = Vector2(650, 800)
	camera.zoom = Vector2.ONE
	add_child(camera)
	camera.make_current()
	marker_font = load("res://assets/ui-font.otf")
	_build_ui()
	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui()
	var args := OS.get_cmdline_user_args()
	var force_demo := args.has("--demo")
	var bridge_path := "res://prototype/bridge/world_bridge.gd"
	if not force_demo and ResourceLoader.exists(bridge_path):
		bridge = load(bridge_path).new()
	elif force_demo:
		demo_mode = true
		bridge = MockWorld.new()
	else:
		mode_label.text = "本機世界尚未連線"
		_status("世界元件尚未安裝，請使用完整遊戲資料夾重新開啟。")
		save_button.disabled = true
		load_button.disabled = true
		return
	add_child(bridge)
	bridge.snapshot_received.connect(_receive_snapshot)
	bridge.command_failed.connect(_command_failed)
	mode_label.text = "開發演示 · 暫存資料" if demo_mode else "本機世界 · 連線中"
	save_button.disabled = demo_mode
	load_button.disabled = demo_mode
	bridge.connect_world("http://127.0.0.1:8793")
	bridge.request_snapshot()
	if not ResourceLoader.exists("res://prototype/actors/character_actor.gd"):
		_status("暫用已確認人體底稿；衣裝與動畫待接入。")

func _panel(color: String = "192d29") -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color)
	box.border_color = Color("43574a")
	box.set_border_width_all(1)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

func _label(text: String, font_size: int = 15, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 35
	button.pressed.connect(callback)
	button.focus_mode = Control.FOCUS_NONE
	return button

func _build_ui() -> void:
	add_child(ui)
	ui.add_child(ui_root)
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = load("res://assets/ui-font.otf")
	theme.default_font_size = 14
	theme.set_stylebox("normal", "Button", _panel("283e34"))
	theme.set_stylebox("hover", "Button", _panel("3d5341"))
	theme.set_stylebox("pressed", "Button", _panel("53634a"))
	theme.set_stylebox("disabled", "Button", _panel("23352e"))
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", Color("6e8173"))
	ui_root.theme = theme
	var header := PanelContainer.new()
	header.name = "Header"
	header.add_theme_stylebox_override("panel", _panel())
	ui_root.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 20)
	header.add_child(header_row)
	header_row.add_child(_label("林間營地", 23, GOLD))
	header_row.add_child(_label("四人小隊  /  探路原型", 14))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)
	mode_label = _label("連線中", 13, Color("9eb7a2"))
	header_row.add_child(mode_label)
	var sidebar := PanelContainer.new()
	sidebar.name = "Sidebar"
	sidebar.add_theme_stylebox_override("panel", _panel())
	ui_root.add_child(sidebar)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	sidebar.add_child(column)
	column.add_child(_label("地區概覽", 16, GOLD))
	mini = MiniMap.new()
	mini.custom_minimum_size = Vector2(236, 130)
	mini.obstacles = map.obstacles
	mini.event_positions = map.points
	mini.location_pressed.connect(func(p): camera.position = p; _clamp_camera())
	column.add_child(mini)
	var zoom_row := HBoxContainer.new()
	column.add_child(zoom_row)
	zoom_row.add_child(_button("－",func(): _zoom(-0.15)))
	zoom_label = _label("100%", 13)
	zoom_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_row.add_child(zoom_label)
	zoom_row.add_child(_button("＋",func(): _zoom(0.15)))
	zoom_row.add_child(_button("營地",func(): camera.position=Vector2(650,800); _zoom_to(1.0)))
	column.add_child(HSeparator.new())
	column.add_child(_label("探路與返回", 16, GOLD))
	for pair in [["scout-north","① 北方路標"],["scout-east","② 東方溪岸"],["return-camp","⌂ 返回營地"]]:
		var key: String = pair[0]
		var button := _button(pair[1],func(): order_event(key))
		button.tooltip_text = "選取隊員後下令；所有選取成員走到 64 像素內才記錄觀察。"
		column.add_child(button)
		event_buttons[key] = button
	column.add_child(HSeparator.new())
	column.add_child(_label("已觀察紀錄", 16, GOLD))
	log_label = RichTextLabel.new()
	log_label.custom_minimum_size.y = 58
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.scroll_following = true
	column.add_child(log_label)
	var footer := PanelContainer.new()
	footer.name = "Footer"
	footer.add_theme_stylebox_override("panel", _panel())
	ui_root.add_child(footer)
	var foot := VBoxContainer.new()
	foot.add_theme_constant_override("separation", 7)
	footer.add_child(foot)
	var title_row := HBoxContainer.new()
	foot.add_child(title_row)
	selection_label = _label("小隊待命", 16, GOLD)
	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(selection_label)
	status_label = _label(last_command, 13, Color("adc6ad"))
	title_row.add_child(status_label)
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 8)
	foot.add_child(card_row)
	for i in range(4):
		var index := i
		var card := _button("%d  等待人物" % (i+1),func(): _select_index(index, Input.is_key_pressed(KEY_SHIFT)))
		card.custom_minimum_size = Vector2(165, 55)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_row.add_child(card)
		cards.append(card)
	var all_button := _button("全選 [Tab]",select_all)
	card_row.add_child(all_button)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	foot.add_child(controls)
	controls.add_child(_button("停止 [S]",stop_selected))
	controls.add_child(_button("集合 [G]",gather_selected))
	pace_button = _button("步行",func(): running=not running; pace_button.text="跑步" if running else "步行")
	controls.add_child(pace_button)
	controls.add_child(_button("分隊",split_selected))
	squad_options = OptionButton.new()
	squad_options.custom_minimum_size = Vector2(155,35)
	squad_options.tooltip_text = "合流目標隊伍；先用人物卡片選取要加入的成員。"
	controls.add_child(squad_options)
	controls.add_child(_button("選隊",func(): _select_squad(squad_options.selected)))
	controls.add_child(_button("合流",merge_selected))
	controls.add_child(_button("胸甲切換",func(): toggle_equipment("armor")))
	controls.add_child(_button("佩劍切換",func(): toggle_equipment("weapon")))
	var fill := Control.new()
	fill.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	controls.add_child(fill)
	save_button = _button("存檔",func(): _send({"type":"save","slot":"slot-1"}))
	load_button = _button("讀檔",func(): pending_interaction.clear(); rendered_routes.clear(); _send({"type":"load","slot":"slot-1"}))
	controls.add_child(save_button)
	controls.add_child(load_button)
	detail_label = _label("左鍵點選 / 拖曳框選 · Shift 增選 · 右鍵移動 · 1–4 單選 · 方向鍵 / 中鍵平移 · 空白鍵置中",12,Color("a1af99"))
	foot.add_child(detail_label)

func _layout_ui() -> void:
	var size := get_viewport_rect().size
	ui_root.get_node("Header").position = Vector2.ZERO
	ui_root.get_node("Header").size = Vector2(size.x,58)
	ui_root.get_node("Sidebar").position = Vector2(size.x-272,58)
	ui_root.get_node("Sidebar").size = Vector2(272,size.y-258)
	ui_root.get_node("Footer").position = Vector2(0,size.y-200)
	ui_root.get_node("Footer").size = Vector2(size.x,200)

func _map_screen_contains(p: Vector2) -> bool:
	var size := get_viewport_rect().size
	return Rect2(0,58,size.x-272,size.y-258).has_point(p)

func screen_to_world(p: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * p

func world_to_screen(p: Vector2) -> Vector2:
	return get_canvas_transform() * p

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB: select_all(); get_viewport().set_input_as_handled()
			KEY_1,KEY_2,KEY_3,KEY_4: _select_index(event.keycode - KEY_1,event.shift_pressed)
			KEY_S: stop_selected()
			KEY_G: gather_selected()
			KEY_SPACE: focus_selected()
			KEY_ESCAPE: selected.clear(); _update_selection()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = event.pressed and _map_screen_contains(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging:
			drag_end = screen_to_world(event.position)
			_finish_selection(event.shift_pressed)
			dragging = false
		if not _map_screen_contains(event.position): return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: _zoom(0.1,event.position)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: _zoom(-0.1,event.position)
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			dragging = true
			drag_start = screen_to_world(event.position)
			drag_end = drag_start
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var world := screen_to_world(event.position)
			for key in map.points:
				if world.distance_to(map.points[key]) < 38:
					order_event(key)
					return
			order_move(world)
	if event is InputEventMouseMotion:
		if panning:
			camera.position -= event.relative / camera.zoom.x
			_clamp_camera()
		if dragging: drag_end = screen_to_world(event.position)

func _finish_selection(additive: bool) -> void:
	if not additive: selected.clear()
	if drag_start.distance_to(drag_end) < 8 / camera.zoom.x:
		var best_id := ""
		var best := 42.0
		for id in actors:
			var distance: float = (actors[id].position - Vector2(0,30)).distance_to(drag_end)
			if distance < best:
				best_id=id
				best=distance
		if not best_id.is_empty():
			if additive and selected.has(best_id): selected.erase(best_id)
			else: selected.append(best_id)
	else:
		var rectangle := Rect2(drag_start,drag_end-drag_start).abs()
		for id in actors:
			if rectangle.has_point(actors[id].position) and not selected.has(id): selected.append(id)
	_update_selection()

func select_all() -> void:
	selected.clear()
	for person in snapshot.get("characters",[]): selected.append(str(person.id))
	_update_selection()

func _select_index(index: int, additive: bool = false) -> void:
	var people: Array = snapshot.get("characters",[])
	if index >= people.size(): return
	var id: String = str(people[index].id)
	if not additive: selected.clear()
	if additive and selected.has(id): selected.erase(id)
	elif not selected.has(id): selected.append(id)
	_update_selection()

func _select_squad(index: int) -> void:
	if index < 0 or index >= snapshot.get("squads",[]).size(): return
	selected.assign(snapshot.squads[index].member_ids)
	_update_selection()

func _update_selection() -> void:
	for id in actors: actors[id].set_selected(selected.has(id))
	selection_label.text = "已選 %d / %d 人" % [selected.size(),actors.size()]
	_refresh_cards()

func _refresh_cards() -> void:
	var people: Array = snapshot.get("characters",[])
	for i in range(cards.size()):
		if i >= people.size(): continue
		var person: Dictionary = people[i]
		var gear: Dictionary = person.get("loadout",{})
		var squad_name := "未編隊"
		for squad in snapshot.get("squads",[]):
			if squad.id==person.squad_id: squad_name=squad.name
		cards[i].text = "%d  %s%s\n%s · %s%s" % [i+1,"● " if selected.has(str(person.id)) else "",person.name,squad_name,"胸甲" if gear.get("armor","none")=="chest" else "布衣"," / 劍" if gear.get("weapon","none")=="sword" else ""]
		cards[i].add_theme_color_override("font_color",GOLD if selected.has(str(person.id)) else INK)

func _receive_snapshot(value: Dictionary) -> void:
	if not value.has("characters") or not value.has("squads"):
		_command_failed("世界資料格式不完整。")
		return
	snapshot = value.duplicate(true)
	mode_label.text = "開發演示 · 暫存資料" if demo_mode else "本機世界 · 已連線"
	var ids: Array[String] = []
	for person in snapshot.characters:
		var id: String = str(person.id)
		ids.append(id)
		if not actors.has(id):
			var actor_path := "res://prototype/actors/character_actor.gd"
			var actor = load(actor_path).new() if ResourceLoader.exists(actor_path) else TemporaryActor.new()
			stage.add_child(actor)
			actor.configure(person)
			actors[id] = actor
		var position_data: Array = person.position
		# Exact authority positions; no client integration, tween through walls or private physics state.
		actors[id].position=Vector2(position_data[0],position_data[1])
		var velocity: Array = person.get("velocity",[0,0])
		actors[id].set_motion(Vector2(velocity[0],velocity[1]))
		actors[id].set_equipment(person.loadout)
		if Vector2(velocity[0],velocity[1]).is_zero_approx() and rendered_routes.has(id):
			var points: PackedVector2Array = rendered_routes[id]
			if actors[id].position.distance_to(points[-1]) < 3: rendered_routes.erase(id)
	for id in actors.keys():
		if not ids.has(id):
			actors[id].queue_free()
			actors.erase(id)
	selected = selected.filter(func(id): return ids.has(id))
	var squad_key := JSON.stringify(snapshot.squads)
	if squad_key != squad_history:
		squad_history=squad_key
		squad_options.clear()
		for squad in snapshot.squads:
			var commander := "未指定"
			for person in snapshot.characters:
				if squad.get("commander_id")!=null and str(person.id)==str(squad.commander_id): commander=person.name
			squad_options.add_item("%s · 隊長%s" % [squad.name,commander])
	var events: Array = snapshot.get("events",[])
	var event_key := JSON.stringify(events)
	if event_key!=event_history:
		event_history=event_key
		log_label.text=""
		for i in range(maxi(0,events.size()-6),events.size()):
			var author := ""
			for person in snapshot.characters:
				if str(person.id)==str(events[i].get("character_id","")): author=str(person.name)+"："
			log_label.append_text("· %s%s\n" % [author,events[i].text])
	mini.snapshot=snapshot
	_update_selection()
	_check_interaction()

func _send(command: Dictionary) -> void:
	if bridge == null:
		_status("本機世界尚未連線。")
		return
	request_number += 1
	command["request_id"] = "client-%d-%d-%d" % [Time.get_unix_time_from_system(),Time.get_ticks_usec(),request_number]
	bridge.send_command(command)

func _command_failed(message: String) -> void:
	_status("指令未完成：" + message)
	pending_interaction.clear()

func _status(message: String) -> void:
	last_command=message
	toast_time=7
	if status_label: status_label.text=message

func order_move(target: Vector2) -> bool:
	if selected.is_empty():
		_status("請先選取隊員。")
		return false
	var reserved: Array[Vector2] = []
	for id in actors:
		if not selected.has(id): reserved.append(actors[id].position)
	var commands: Array[Dictionary] = []
	var planned: Dictionary = {}
	var offsets := [Vector2(-24,-24),Vector2(24,-24),Vector2(-24,24),Vector2(24,24)]
	for i in range(selected.size()):
		var id := selected[i]
		var desired: Vector2 = target + offsets[i%4] if selected.size()>1 else target
		var goal: Vector2 = map.nearest_free(desired,reserved)
		if goal.x<0:
			_status("目的地沒有足夠站位。")
			return false
		var path: PackedVector2Array = map.route(actors[id].position,goal)
		if path.is_empty():
			_status("目前無法通過，請選擇相通的空地。")
			return false
		reserved.append(goal)
		var points: Array = []
		for p in path: points.append([p.x,p.y])
		commands.append({"character_id":id,"points":points})
		planned[id]=path
	for id in planned: rendered_routes[id]=planned[id]
	_cancel_selected_interactions()
	_send({"type":"move","routes":commands,"pace":"run" if running else "walk"})
	_status("%d 人%s前往目的地。" % [selected.size(),"跑步" if running else "步行"])
	return true

func stop_selected() -> void:
	if selected.is_empty(): return
	_cancel_selected_interactions()
	for id in selected: rendered_routes.erase(id)
	_send({"type":"stop","character_ids":selected.duplicate()})
	_status("已下令停止。")

func gather_selected() -> void:
	if selected.is_empty(): return
	var centre: Vector2 = actors[selected[0]].position
	order_move(centre)

func split_selected() -> void:
	if selected.is_empty():
		_status("請先選取要分出的隊員。")
		return
	_send({"type":"split","character_ids":selected.duplicate(),"name":"探路分隊"})

func merge_selected() -> void:
	var squads: Array = snapshot.get("squads",[])
	if squads.size()<2:
		_status("目前只有一支隊伍。")
		return
	var target_index := maxi(0,squad_options.selected)
	var target: String = squads[target_index].id
	var sources: Array[String] = []
	for person in snapshot.characters:
		if selected.has(str(person.id)) and person.squad_id!=target and not sources.has(str(person.squad_id)): sources.append(str(person.squad_id))
	if sources.is_empty():
		_status("請選取另一隊成員，再選合流目標隊伍。")
		return
	for source in sources: _send({"type":"merge","source_squad_id":source,"target_squad_id":target})

func toggle_equipment(field: String) -> void:
	for person in snapshot.get("characters",[]).duplicate(true):
		if not selected.has(str(person.id)): continue
		var loadout: Dictionary = person.loadout.duplicate(true)
		loadout[field] = ("chest" if field=="armor" else "sword") if loadout.get(field,"none")=="none" else "none"
		_send({"type":"set_equipment","character_id":str(person.id),"loadout":loadout})

func order_event(key: String) -> void:
	if selected.is_empty():
		_status("請先選取要探路或返回的隊員。")
		return
	if order_move(map.points[key]):
		for id in selected: pending_interaction[id]=key
		_check_interaction()

func _cancel_selected_interactions() -> void:
	for id in selected: pending_interaction.erase(id)

func _check_interaction() -> void:
	if pending_interaction.is_empty(): return
	var groups: Dictionary={}
	for id in pending_interaction.keys():
		if not actors.has(id):
			pending_interaction.erase(id)
			continue
		var key: String=pending_interaction[id]
		if not groups.has(key): groups[key]=[]
		groups[key].append(id)
	for key in groups:
		var target: Vector2=map.points[key]
		var arrived := true
		# Different destinations progress independently; all members assigned here must arrive.
		for id in groups[key]:
			if actors[id].position.distance_to(target)>64: arrived=false
		if not arrived: continue
		for id in groups[key]: pending_interaction.erase(id)
		for id in groups[key]:
			_send({"type":"interact","character_id":str(id),"event_key":key})
		_status("已到達，正在記錄隊員觀察。")

func focus_selected() -> void:
	if selected.is_empty(): return
	var centre := Vector2.ZERO
	for id in selected: centre += actors[id].position
	camera.position=centre/selected.size()+Vector2(136,70)/camera.zoom.x
	_clamp_camera()

func _zoom(amount: float, anchor: Vector2 = Vector2(-1,-1)) -> void:
	var before := screen_to_world(anchor)
	_zoom_to(camera.zoom.x + amount)
	if anchor.x>=0:
		camera.force_update_scroll()
		camera.position += before-screen_to_world(anchor)
		_clamp_camera()

func _zoom_to(value: float) -> void:
	camera.zoom=Vector2.ONE*clampf(value,0.5,2.0)
	zoom_label.text="%d%%" % roundi(camera.zoom.x*100)
	_clamp_camera()

func _clamp_camera() -> void:
	camera.position=camera.position.clamp(Vector2(200,220),Vector2(1936,1436))

func _process(delta: float) -> void:
	for tree in canopy:
		var hides_selection := false
		for id in selected:
			if not actors.has(id): continue
			var relative: Vector2 = actors[id].position-tree.position
			if absf(relative.x)<62 and relative.y<0 and relative.y>-140: hides_selection=true
		tree.modulate.a=0.42 if hides_selection else 1.0
	var direction := Vector2(float(Input.is_key_pressed(KEY_RIGHT))-float(Input.is_key_pressed(KEY_LEFT)),float(Input.is_key_pressed(KEY_DOWN))-float(Input.is_key_pressed(KEY_UP)))
	if not direction.is_zero_approx():
		camera.position += direction.normalized()*camera_speed*delta/camera.zoom.x
		_clamp_camera()
	if mini:
		mini.camera_position=camera.position
		mini.camera_extent=get_viewport_rect().size/camera.zoom.x
		mini.queue_redraw()
	if toast_time>0:
		toast_time-=delta
		if toast_time<=0: status_label.text="右鍵地面下令 · 地圖上的金色環為事件點"
	queue_redraw()

func _draw() -> void:
	for id in rendered_routes:
		if not actors.has(id) or not selected.has(id): continue
		var points: PackedVector2Array=rendered_routes[id]
		if points.size()>1:
			draw_polyline(points,Color(0.88,0.77,0.48,0.35),2)
			draw_arc(points[-1],13,0,TAU,24,GOLD,2)
	if marker_font:
		var labels := {"return-camp":"營地", "scout-north":"① 北方路標", "scout-east":"② 東方溪岸"}
		for key in map.points:
			var p: Vector2=map.points[key]
			draw_arc(p,32,0,TAU,32,Color(0.87,0.76,0.48,0.7),2)
			draw_line(p+Vector2(0,-44),p+Vector2(0,-78),GOLD,3)
			draw_colored_polygon(PackedVector2Array([p+Vector2(1,-78),p+Vector2(22,-72),p+Vector2(1,-64)]),GOLD)
			draw_string(marker_font,p+Vector2(-42,-112),labels[key],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("efe3b8"))
	if dragging:
		var rect := Rect2(drag_start,drag_end-drag_start).abs()
		draw_rect(rect,Color(0.86,0.76,0.46,0.12))
		draw_rect(rect,GOLD,false,1.5/camera.zoom.x)
