extends Node
## Explicit diagnostic mode on the actual exported main scene: -- --verify-bundle.
var launcher: Node
var checks: Array[Dictionary] = []
var failures := 0
var output := ""
var phase := ""

func _ready() -> void:
	launcher=get_parent()
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks.append({"check":label,"passed":value})
	if not value: failures+=1

func wait_for(test: Callable, seconds: float = 10.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if test.call(): return true
		await get_tree().create_timer(0.05).timeout
	return test.call()

func run() -> void:
	output=OS.get_environment("RTS_VERIFY_OUTPUT")
	phase=OS.get_environment("RTS_LAUNCH_VERIFY_PHASE")
	if output.is_empty() or OS.get_environment("RTS_SAVE_DIRECTORY").is_empty() or phase not in ["create","restore"]:
		printerr("Launcher verification requires isolated output/save directories and create/restore phase")
		get_tree().root.close_requested.emit()
		return
	DirAccess.make_dir_recursive_absolute(output)
	var connected := await wait_for(func(): return launcher.world_ready and launcher.game.actors.size()==4)
	check(connected,"bundled game automatically starts and connects its world")
	if connected:
		check(not launcher.game.demo_mode,"bundle uses persistent world")
		check(launcher.game.map.points.size()==3,"export contains map JSON and dynamic resources")
		var visible_frames := true
		for actor in launcher.game.actors.values():
			if actor._sprite.texture==null or not actor._sprite.texture.get_image().get_used_rect().has_area(): visible_frames=false
		check(visible_frames,"all four runtime actors render nonempty frames from exported layers")
		var expected_path := OS.get_environment("RTS_EXPECTED_SNAPSHOT")
		if not expected_path.is_empty():
			var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(expected_path))
			var actual: Dictionary=launcher.game.snapshot
			check(actual.characters==expected.characters and actual.squads==expected.squads and actual.events==expected.events,"native restart restores all character squad position equipment and observation records")
		if phase=="create":
			launcher.game.selected.assign(["4"])
			launcher.game.toggle_equipment("armor")
		if expected_path.is_empty():
			check(await wait_for(func(): return launcher.game.snapshot.characters[3].loadout.armor=="chest"),"equipment is persisted across process restart" if phase=="restore" else "real player equipment command succeeds")
		if phase=="create":
			var actor: Node2D=launcher.game.actors["4"]
			var start: Vector2=actor.position
			launcher.game.running=true
			check(launcher.game.order_move(start+Vector2(96,0)),"new actor receives a real movement route")
			check(await wait_for(func(): return actor.get_visual_state().motion=="run"),"exported modular actor switches to run animation")
			await get_tree().create_timer(0.7).timeout
			check(actor.position.distance_to(start)>8,"new actor follows authoritative world motion")
			launcher.game.stop_selected()
			check(await wait_for(func(): return actor.get_visual_state().motion=="idle"),"new actor returns to idle on real stop")
			launcher.game.toggle_equipment("weapon")
			check(await wait_for(func(): return launcher.game.snapshot.characters[3].loadout.weapon=="sword" and actor.get_visual_state().loadout.weapon=="sword"),"equipment and cached actor frame update together")
		launcher.game.select_all()
		launcher.game._send({"type":"save","slot":"slot-1"})
		check(await wait_for(func(): return launcher.game.bridge._queue.is_empty() and launcher.game.bridge._inflight.is_empty()),"queued save completes before close")
		if DisplayServer.get_name()!="headless":
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			check(get_tree().root.get_texture().get_image().save_png(output.path_join("bundle-"+phase+".png"))==OK,"native bundle screenshot saved")
	var report := {"phase":phase,"checks":checks,"failed":failures,"world_pid":launcher.world_pid,"executable":OS.get_executable_path(),"save_directory":launcher.save_directory}
	var file := FileAccess.open(output.path_join("launcher-"+phase+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("LAUNCHER_VERIFY failed=",failures," phase=",phase)
	# Same close-request signal as a player closing the Windows game window.
	get_tree().root.close_requested.emit()
