extends Node
## Explicit full-game diagnostic mode: -- --verify-integration, with isolated save/output directories.
var root: Window
var client: Node
var checks: Array[Dictionary] = []
var failures := 0
var positions_checked := 0
var collision_found := false
var output := ""
var started := 0
var errors: Array[String] = []

func _ready() -> void:
	root=get_tree().root
	call_deferred("run")

func check(value: bool, name: String) -> void:
	checks.append({"check":name,"passed":value})
	if not value:
		failures += 1
		printerr("INTEGRATION_FAIL ",name)
	else: print("INTEGRATION_CHECK ",name)

func until(predicate: Callable, seconds: float = 5.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await get_tree().create_timer(0.05).timeout
	return predicate.call()

func changed(revision: int) -> bool:
	return await until(func(): return int(client.snapshot.get("revision",0)) > revision)

func take(filename: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(filename))==OK,"capture " + filename)

func observe(value: Dictionary) -> void:
	for person in value.get("characters",[]):
		positions_checked += 1
		if not client.map.walkable(Vector2(person.position[0],person.position[1])):
			collision_found=true

func ids() -> Array:
	return client.snapshot.characters.map(func(p): return str(p.id))

func person(id: String) -> Dictionary:
	for p in client.snapshot.characters:
		if str(p.id)==id: return p
	return {}

func stopped() -> bool:
	for p in client.snapshot.characters:
		if Vector2(p.velocity[0],p.velocity[1]).length()>0.01: return false
	return true

func event_seen(key: String) -> bool:
	for e in client.snapshot.events:
		if e.get("event_key")==key: return true
	return false

func observation_count(key: String) -> int:
	return client.snapshot.events.filter(func(e): return e.get("event_key")==key).size()

func press(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode=code
	e.pressed=true
	Input.parse_input_event(e)
	await get_tree().process_frame
	e=InputEventKey.new()
	e.keycode=code
	Input.parse_input_event(e)
	await get_tree().process_frame

func run() -> void:
	started=Time.get_ticks_msec()
	output=OS.get_environment("RTS_VERIFY_OUTPUT")
	if output.is_empty() or OS.get_environment("RTS_SAVE_DIRECTORY").is_empty():
		printerr("RTS_VERIFY_OUTPUT and RTS_SAVE_DIRECTORY must use isolated test directories")
		root.close_requested.emit()
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800)
	if not await until(func(): return get_parent().world_ready,10.0):
		check(false,"game launcher starts its world")
		finish()
		return
	client=get_parent().game
	if not await until(func(): return client.actors.size()==4):
		check(false,"actual Rust world connects with four actors")
		finish()
		return
	client.bridge.snapshot_received.connect(observe)
	client.bridge.command_failed.connect(func(message): errors.append(message))
	check(not client.demo_mode,"formal client uses real bridge")
	check(client.actors["1"].get_script().resource_path=="res://prototype/actors/character_actor.gd","real pixel actor replaces stand-in")
	check(ids()==["1","2","3","4"],"stable four identity records")
	check(not client.save_button.disabled and not client.load_button.disabled,"formal save/load controls enabled")
	await press(KEY_TAB)
	check(client.selected.size()==4,"actual Tab input selects four")
	await take("01-integrated-camp.png")
	var revision: int=client.snapshot.revision
	client.selected.assign(["1"])
	client.toggle_equipment("armor")
	check(await until(func(): return person("1").loadout.armor=="chest"),"UI equipment reaches Rust and actor")
	client.toggle_equipment("weapon")
	check(await until(func(): return person("1").loadout.weapon=="sword"),"weapon command persists in world")
	client.selected.assign(["1","2"])
	client.split_selected()
	check(await until(func(): return client.snapshot.squads.size()==2),"client splits real squad")
	check(ids()==["1","2","3","4"],"split preserves identity")
	client.running=true
	check(client.order_move(Vector2(1104,592)),"map finds route through wall opening")
	check(await until(func(): return not stopped()),"Rust advances real-time movement")
	await get_tree().create_timer(1.5).timeout
	await press(KEY_S)
	check(await until(stopped),"keyboard stop halts world")
	var stopped_position: Array=person("1").position.duplicate()
	await get_tree().create_timer(0.6).timeout
	check(person("1").position==stopped_position,"position stays fixed after stop")
	client.order_event("scout-north")
	client.selected.assign(["3","4"])
	client.order_event("scout-east")
	check(client.pending_interaction.size()==4,"two scout destinations retain independent arrival tracking")
	check(not event_seen("scout-north"),"distant destination does not reveal observation")
	check(await until(func(): return event_seen("scout-north"),35.0),"real route reaches north and records observation")
	check(await until(func(): return observation_count("scout-north")==2),"each scouting member records their own observation")
	check(await until(func(): return observation_count("scout-east")==2,20.0),"other squad independently reaches east and records both observers")
	client.selected.assign(["1","2"])
	client.focus_selected()
	await take("02-integrated-scout.png")
	client.select_all()
	client.order_event("return-camp")
	check(await until(func(): return event_seen("return-camp"),35.0),"real route returns with observation history")
	check(await until(func(): return observation_count("return-camp")==4),"each returning observer reports their own information")
	check(await until(stopped,3.0),"returned members finish their routes")
	client.squad_options.select(0)
	# Choose the squad containing person 3 as the merge target.
	for i in range(client.snapshot.squads.size()):
		if client.snapshot.squads[i].member_ids.has("3"): client.squad_options.select(i)
	client.select_all()
	check(client.selected==["1","2","3","4"],"merge input explicitly selects source members")
	print("MERGE_INPUT ",JSON.stringify({"selected":client.selected,"target_index":client.squad_options.selected,"people":client.snapshot.characters}))
	client.merge_selected()
	check(await until(func(): return client.snapshot.squads.size()==1),"real squads merge from player control")
	client.select_all()
	revision=client.snapshot.revision
	client.gather_selected()
	check(await changed(revision),"gather acknowledged by real world")
	check(await until(stopped,5.0),"gather finishes with separate standing positions")
	var before_save: Dictionary=client.snapshot.duplicate(true)
	revision=client.snapshot.revision
	client._send({"type":"save","slot":"slot-1"})
	# Saving a slot does not alter the simulated world or its revision.
	check(await until(func(): return client.bridge._queue.is_empty() and client.bridge._inflight.is_empty()) and errors.is_empty(),"formal slot save response succeeds")
	client.selected.assign(["1"])
	client.toggle_equipment("armor")
	check(await until(func(): return person("1").loadout.armor=="none"),"world changes after save")
	revision=client.snapshot.revision
	client._send({"type":"load","slot":"slot-1"})
	check(await changed(revision),"formal slot load acknowledged")
	check(person("1").loadout.armor=="chest","load restores saved equipment")
	check(client.snapshot.characters==before_save.characters and client.snapshot.squads==before_save.squads and client.snapshot.events==before_save.events,"load restores positions identities squads and history")
	check(not collision_found,"all sampled real-world positions avoid map obstacles")
	check(errors.is_empty(),"no unexpected bridge command failures")
	client.select_all()
	client.camera.position=Vector2(650,800)
	await take("03-integrated-return.png")
	var saved := FileAccess.open(output.path_join("expected-restart.json"),FileAccess.WRITE)
	saved.store_string(JSON.stringify(client.snapshot,"\t"))
	saved.close()
	finish()

func finish() -> void:
	var file := FileAccess.open(output.path_join("integration.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failed":failures,"position_samples":positions_checked,"elapsed_ms":Time.get_ticks_msec()-started,"errors":errors,"mock":false},"\t"))
	file.close()
	print("INTEGRATION_RESULT failed=",failures," position_samples=",positions_checked)
	root.close_requested.emit()
