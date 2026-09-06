extends SceneTree
## Executes the playable scene and dispatches actual Godot input events.
var client: Node
var checks: Array[Dictionary] = []
var failures := 0
var captured: Array[String] = []
var sampled_positions := 0
var output := ""

func _initialize() -> void:
	root.size=Vector2i(1280,800)
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks.append({"check":label,"passed":ok})
	if not ok:
		failures += 1
		printerr("CHECK FAILED: " + label)

func frames(count: int = 2) -> void:
	for i in range(count): await process_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await frames()
	event=InputEventKey.new()
	event.keycode=code
	Input.parse_input_event(event)
	await frames()

func mouse(point: Vector2, button: MouseButton, pressed: bool, shift: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position=point
	event.global_position=point
	event.button_index=button
	event.pressed=pressed
	event.shift_pressed=shift
	Input.parse_input_event(event)
	await frames()

func click(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	await mouse(point,button,true)
	await mouse(point,button,false)

func advance(seconds: float) -> void:
	for i in range(ceili(seconds / 0.05)):
		client.bridge._process(0.05)
		for actor in client.actors.values():
			sampled_positions += 1
			if not client.map.walkable(actor.position):
				printerr("COLLISION ",actor.position," routes ",client.rendered_routes)
				check(false,"continuous movement entered physical obstacle")
				return

func screenshot(filename: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await frames(4)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png(output.path_join(filename))
	check(result==OK,"capture " + filename)
	captured.append(filename)

func run() -> void:
	root.size=Vector2i(1280,800)
	root.content_scale_size=Vector2i(1280,800)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	output=ProjectSettings.globalize_path("res://../prototype/reports/client")
	DirAccess.make_dir_recursive_absolute(output)
	client=load("res://prototype/client/prototype.tscn").instantiate()
	root.add_child(client)
	await frames(5)
	if not client.demo_mode:
		check(false,"verification requires --demo")
		quit(1)
		return
	client.bridge.set_process(false)
	check(client.actors.size()==4,"four authority-snapshot characters instantiated")
	check(client.map.SIZE==Vector2(2048,1536),"2048 by 1536 map and 32 pixel grid")
	await click(client.world_to_screen(client.actors["1"].position-Vector2(0,28)))
	check(client.selected==["1"],"mouse click selects one person")
	await mouse(client.world_to_screen(Vector2(265,748)),MOUSE_BUTTON_LEFT,true)
	await mouse(client.world_to_screen(Vector2(399,898)),MOUSE_BUTTON_LEFT,false)
	check(client.selected.size()==4,"drag rectangle selects all four")
	await screenshot("01-camp-selected.png")
	await key(KEY_2)
	check(client.selected==["2"],"number key selects person")
	await mouse(client.world_to_screen(client.actors["1"].position-Vector2(0,28)),MOUSE_BUTTON_LEFT,true,true)
	await mouse(client.world_to_screen(client.actors["1"].position-Vector2(0,28)),MOUSE_BUTTON_LEFT,false,true)
	check(client.selected.size()==2,"shift click adds member")
	await key(KEY_TAB)
	check(client.selected.size()==4,"Tab selects whole party")
	var zoom_before: float=client.camera.zoom.x
	await mouse(Vector2(600,300),MOUSE_BUTTON_WHEEL_UP,true)
	check(client.camera.zoom.x>zoom_before,"wheel zoom uses input event")
	var before: Vector2=client.camera.position
	await mouse(Vector2(600,300),MOUSE_BUTTON_MIDDLE,true)
	var motion := InputEventMouseMotion.new()
	motion.position=Vector2(650,320)
	motion.relative=Vector2(50,20)
	Input.parse_input_event(motion)
	await frames()
	await mouse(Vector2(650,320),MOUSE_BUTTON_MIDDLE,false)
	check(client.camera.position.distance_to(before)>20,"middle mouse pans fixed camera")
	client.camera.position=Vector2(880,800)
	client._zoom_to(0.8)
	await frames()
	var wall_target := Vector2(1104,592)
	check(not client.map.segment_clear(client.actors["1"].position,wall_target),"test move crosses real wall if direct")
	await click(client.world_to_screen(wall_target),MOUSE_BUTTON_RIGHT)
	check(client.rendered_routes.size()==4,"right click issues four routes")
	var goals: Array[Vector2] = []
	var routes_valid := true
	var detour := false
	for path in client.rendered_routes.values():
		goals.append(path[-1])
		if path.size()>2: detour=true
		for i in range(path.size()-1):
			if not client.map.segment_clear(path[i],path[i+1]): routes_valid=false
	check(routes_valid and detour,"A star detours have continuous 12 pixel obstacle clearance")
	var separated := true
	for i in range(goals.size()):
		for j in range(i+1,goals.size()):
			if goals[i].distance_to(goals[j])<31: separated=false
	check(separated,"four formation endpoints do not overlap")
	advance(8)
	await screenshot("02-wall-detour.png")
	await key(KEY_S)
	var stopped: Vector2=client.actors["1"].position
	advance(2)
	check(client.actors["1"].position.distance_to(stopped)<0.01,"stop freezes authoritative mock movement")
	client.running=true
	client.order_move(wall_target)
	advance(35)
	var arrived := true
	for actor in client.actors.values():
		if actor.position.distance_to(wall_target)>75: arrived=false
	check(arrived,"four people arrive around wall without permanent deadlock")
	await key(KEY_1)
	var untouched: Vector2=client.actors["2"].position
	client.order_move(Vector2(1184,624))
	advance(6)
	check(client.actors["2"].position==untouched,"individual order preserves other positions")
	client.toggle_equipment("armor")
	client.toggle_equipment("weapon")
	check(client.snapshot.characters[0].loadout.armor=="chest" and client.snapshot.characters[0].loadout.weapon=="sword","equipment updates are received from world snapshot")
	var original_ids: Array = client.actors.keys()
	client.split_selected()
	check(client.snapshot.squads.size()==2,"split creates second squad")
	client._select_squad(0)
	check(client.selected.size()==3,"select squad uses authoritative member IDs")
	await key(KEY_1)
	client.squad_options.select(0)
	client.merge_selected()
	check(client.snapshot.squads.size()==1 and client.actors.keys()==original_ids,"merge preserves four original IDs")
	await key(KEY_TAB)
	client.gather_selected()
	advance(10)
	var spread := 0.0
	for actor in client.actors.values(): spread=maxf(spread,actor.position.distance_to(client.actors["1"].position))
	check(spread<100,"gather forms a compact group")
	var event_count: int=client.snapshot.events.size()
	client.order_event("scout-north")
	check(client.snapshot.events.size()==event_count,"distant event reveals nothing before arrival")
	advance(35)
	check(client.snapshot.events.size()==event_count+1 and client.pending_interaction.is_empty(),"north event triggers after every selected member reaches radius")
	client._send({"type":"interact","character_id":"1","event_key":"scout-north"})
	check(client.snapshot.events.size()==event_count+1,"repeat scouting does not duplicate observed event")
	client._send({"type":"interact","character_id":"1","event_key":"scout-east"})
	check(client.snapshot.events.size()==event_count+1,"remote direct interaction is rejected by mock")
	client.camera.position=Vector2(1180,500)
	client._zoom_to(1.05)
	client._status("北方路標已觀察，準備前往東方溪岸。")
	await screenshot("03-north-observed.png")
	client.order_event("scout-east")
	advance(50)
	check(client.snapshot.events.size()==event_count+2,"east scouting event reached around rocks")
	client.order_event("return-camp")
	advance(60)
	var at_camp := true
	for actor in client.actors.values():
		if actor.position.distance_to(Vector2(336,848))>64: at_camp=false
	check(at_camp and client.snapshot.events.size()==event_count+3,"return camp completes only when full selected party arrives")
	client.camera.position=Vector2(650,800)
	client._zoom_to(1.0)
	client._status("實測：四人已探路並返回營地。")
	await screenshot("04-return-camp.png")
	check(client.save_button.disabled and client.load_button.disabled,"mock never provides formal saves")
	var no_commander: Dictionary=client.snapshot.duplicate(true)
	no_commander.squads[0].commander_id=null
	client._receive_snapshot(no_commander)
	check(client.squad_options.get_item_text(0).contains("未指定"),"null commander is displayed without inventing replacement")
	var random := RandomNumberGenerator.new()
	random.seed=6002
	var random_valid := true
	var restart_valid := true
	var random_count := 0
	for i in range(120):
		var start: Vector2=client.map.nearest_free(Vector2(random.randf_range(48,2000),random.randf_range(48,1488)))
		var finish: Vector2=client.map.nearest_free(Vector2(random.randf_range(48,2000),random.randf_range(48,1488)))
		var path: PackedVector2Array=client.map.route(start,finish)
		if path.is_empty(): continue
		random_count+=1
		for j in range(path.size()-1):
			if not client.map.segment_clear(path[j],path[j+1]): random_valid=false
			var midpoint: Vector2=path[j].lerp(path[j+1],0.43)
			var resumed: PackedVector2Array=client.map.route(midpoint,finish)
			if resumed.is_empty(): restart_valid=false
	check(random_valid and random_count>=110,"seeded 120 map-spanning routes preserve exact obstacle clearance")
	check(restart_valid,"stop-and-replan from intermediate route positions stays navigable")
	var ui_bounds := true
	for name in ["Header","Sidebar","Footer"]:
		var control: Control=client.ui_root.get_node(name)
		if control.position.x+control.size.x>root.size.x+2 or control.position.y+control.size.y>root.size.y+2: ui_bounds=false
	check(ui_bounds,"all UI panels fit actual 1280 by 800 viewport")
	# A material-dependent visibility regression: walk a selected actor behind a canopy.
	await key(KEY_1)
	var canopy_found := false
	for tree in client.canopy:
		var point: Vector2=client.map.nearest_free(tree.position-Vector2(0,80))
		var relative: Vector2=point-tree.position
		if absf(relative.x)>=60 or relative.y>=0 or relative.y<=-140: continue
		if not client.order_move(point): continue
		advance(70)
		await frames()
		if tree.modulate.a<0.5:
			canopy_found=true
			client.focus_selected()
			client._zoom_to(1.3)
			client._status("選取隊員位於樹後，樹冠淡化以保持可見。")
			await screenshot("05-canopy-visibility.png")
			break
	check(canopy_found,"new tree sprite fades over a selected actor reached by a valid route")
	var result := {"godot":Engine.get_version_info().string,"backend":"explicit_mock_only","formal_rust_integration":"NOT_RUN_missing_owned_bridge","checks":checks,"failed":failures,"sampled_authoritative_positions":sampled_positions,"random_routes_found":random_count,"screenshots":captured,"viewport":[root.size.x,root.size.y]}
	var suffix := "headless" if DisplayServer.get_name()=="headless" else "rendered"
	var file := FileAccess.open(output.path_join("verification-"+suffix+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	print("PROTOTYPE_CLIENT_VERIFIED " + JSON.stringify(result))
	quit(1 if failures>0 else 0)
