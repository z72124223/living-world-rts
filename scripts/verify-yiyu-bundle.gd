extends SceneTree
## Loads the actual exported resources; this verifier lives outside the game package.
var output := ""
var scene: Control
var checks: Array[Dictionary] = []

func _initialize() -> void:
	output = OS.get_environment("YIYU_BUNDLE_VERIFY_DIR")
	if output.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("_run")

func _click(control: Control) -> void:
	await process_frame
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	checks.append({"check": "native exported capture " + name, "passed": result == OK})

func _run() -> void:
	scene = load("res://login/login.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.5).timeout
	await _capture("01-login")
	await _click(scene.start_button)
	checks.append({"check": "packaged login enters registration", "passed": is_instance_valid(scene.registration_screen)})
	var screen: Control = scene.registration_screen
	await _capture("02-account")
	await _click(screen.controls.step_3)
	checks.append({"check": "packaged unverified creation remains disabled", "passed": screen.controls.create_character.disabled})
	checks.append({"check": "packaged child pool remains empty", "passed": screen.controls.reincarnation.disabled})
	await _capture("03-creation")
	root.size = Vector2i(960, 540)
	await create_timer(0.2).timeout
	await _capture("04-small-window")
	await _click(screen.controls.back)
	checks.append({"check": "packaged return restores title", "passed": scene.start_button.is_visible_in_tree() and not screen.visible})
	var passed := checks.all(func(c: Dictionary): return c.passed)
	var report := {"passed": passed, "checks": checks, "source": "exported executable resources", "executable": OS.get_executable_path(), "external_services_called": false}
	var file := FileAccess.open(output.path_join("bundle-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("YIYU_BUNDLE_UI_VERIFIED " + JSON.stringify(report))
	quit(0 if passed else 1)
