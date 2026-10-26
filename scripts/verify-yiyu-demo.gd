extends SceneTree
## Independent input-driven verifier; never included in the export package.
var output := ""
var menu: Control
var screen: Control
var checks: Array[Dictionary] = []
var failures := 0

func _initialize() -> void:
	output = OS.get_environment("YIYU_DEMO_VERIFY_DIR")
	if output.is_empty() or not OS.get_cmdline_user_args().has("--registration-demo"):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("_run")

func check(value: bool, description: String) -> void:
	checks.append({"check": description, "passed": value})
	if not value:
		failures += 1
		printerr("DEMO_CHECK_FAILED: " + description)

func click(control: Control) -> void:
	await process_frame
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

func type_text(control: LineEdit, text: String) -> void:
	await click(control)
	control.clear()
	for character in text:
		var event := InputEventKey.new()
		event.unicode = character.unicode_at(0)
		event.pressed = true
		root.push_input(event, true)
	await process_frame

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func settle() -> void:
	var deadline := Time.get_ticks_msec() + 12000
	await process_frame
	while screen.busy and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	check(not screen.busy, "HTTP action completed")
	await process_frame

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "captured " + name)

func enable_simulations() -> void:
	await click(screen.controls.identity_consent)
	await click(screen.controls.demo_identity)
	await settle()
	await click(screen.controls.next_ai)
	await click(screen.controls.fee_consent)
	await click(screen.controls.demo_ai)
	await settle()
	await click(screen.controls.next_character)

func _run() -> void:
	menu = load("res://login/login.tscn").instantiate()
	# Preserve the user's actual display/audio preferences while verifying defaults.
	menu.settings_path = output.path_join("test-settings.cfg")
	root.add_child(menu)
	await create_timer(0.4).timeout
	check(menu.start_button.has_focus(), "login keyboard focus")
	await capture("01-login")
	await click(menu.exit_button)
	check(menu.exit_dialog.visible, "exit confirmation opens")
	await click(menu.exit_dialog.get_cancel_button())
	check(not menu.exit_dialog.visible, "exit can be cancelled without quitting")
	await click(menu.settings_button)
	check(menu.settings_overlay.visible, "login settings still open")
	await key(KEY_ESCAPE)
	check(not menu.settings_overlay.visible, "Escape closes settings")
	await click(menu.start_button)
	screen = menu.registration_screen
	check(is_instance_valid(screen) and screen.demo_mode, "login enters demo registration")
	check(screen.service_base == "http://127.0.0.1:8788", "demo uses separate port")
	check(not screen.controls.has("password") and not screen.controls.has("username"), "demo never asks for real account credentials")
	await capture("02-demo-start")
	await click(screen.controls.step_3)
	check(screen.controls.reincarnation.disabled and screen.controls.create_character.disabled, "unverified child and creation gates")
	await click(screen.controls.step_0)
	await click(screen.controls.demo_start)
	await settle()
	check(screen.step == 1 and screen.state.get("mode") == "demo", "explicit start obtains demo session")
	await click(screen.controls.demo_identity)
	await settle()
	check(screen.state.identity != "verified", "simulation requires consent")
	await click(screen.controls.identity_consent)
	await click(screen.controls.demo_identity)
	await settle()
	check(screen.state.sex == "F" and screen.state.identity == "verified", "fixed fictional female verification")
	check(not screen.state.identityServiceConfigured, "Persona remains unconfigured")
	await capture("03-demo-identity")
	await click(screen.controls.next_ai)
	check(not screen.controls.has("api_key"), "demo has no real key input")
	await click(screen.controls.demo_ai)
	await settle()
	check(not screen.state.aiConnected, "AI simulation requires consent")
	await click(screen.controls.fee_consent)
	await click(screen.controls.demo_ai)
	await settle()
	check(screen.state.aiConnected and not screen.state.hasKey, "simulated AI without a stored key")
	await capture("04-demo-ai")
	await click(screen.controls.next_character)
	check(not screen.controls.has("gender") and not screen.controls.has("appearance"), "no gender or appearance selector")
	check(not screen.controls.suggest_name.disabled, "simulated name service available without key")
	await click(screen.controls.name_fee)
	await click(screen.controls.suggest_name)
	await settle()
	check(screen.draft.given == "知遠", "simulated Chinese suggestion applied")
	check(screen.controls.create_character.disabled, "suggestion is not approval")
	await type_text(screen.controls.surname, "王")
	await type_text(screen.controls.given, "廣告")
	await click(screen.controls.name_fee)
	await click(screen.controls.review_name)
	await settle()
	check(screen.controls.create_character.disabled and not screen.state.review.approved, "malicious fixture name rejected without automatic ban")
	await type_text(screen.controls.surname, "歐陽")
	await type_text(screen.controls.given, "映禾")
	await click(screen.controls.name_fee)
	await click(screen.controls.review_name)
	await settle()
	check(not screen.controls.create_character.disabled, "reviewed compound surname permits arrival")
	await type_text(screen.controls.given, "若川")
	check(screen.controls.create_character.disabled, "edited name invalidates approval")
	await type_text(screen.controls.given, "映禾")
	await capture("05-demo-reviewed")
	await click(screen.controls.create_character)
	check(is_instance_valid(screen.modal), "naming policy popup opens")
	await key(KEY_TAB)
	check(screen.controls.policy_accept.has_focus(), "policy focus stays in modal")
	await key(KEY_TAB)
	check(screen.controls.policy_cancel.has_focus(), "policy focus cycles")
	await capture("06-demo-policy")
	await click(screen.controls.policy_cancel)
	check(not is_instance_valid(screen.modal) and screen.state.character == null, "policy cancellation makes no character")
	await click(screen.controls.create_character)
	await click(screen.controls.policy_accept)
	await settle()
	check(screen.state.character is Dictionary, "arrival reaches completed screen")
	check(screen.state.character.surname == "歐陽" and screen.state.character.sex == "F", "arrival retains reviewed name and locked sex")
	check(screen.state.character.appearance == "arrival-female" and not screen.state.character.has("items"), "arrival only fixed modern appearance without items")
	await capture("07-demo-arrival")
	var old_token: String = screen.token
	await click(screen.controls.demo_reset)
	await settle()
	check(screen.token != old_token and screen.state.character == null and screen.state.identity != "verified", "restart replaces session and resets gates")
	await enable_simulations()
	check(screen.state.availableChildren == 2 and not screen.controls.reincarnation.disabled, "only eligible public girls are available")
	await click(screen.controls.reincarnation)
	check(not screen.controls.has("surname") and not screen.controls.has("given"), "reincarnation cannot rename parents' child")
	check(screen.controls.portrait_image.texture == null, "no specific child shown before random pairing")
	await capture("08-demo-reincarnation")
	await click(screen.controls.create_character)
	await click(screen.controls.policy_accept)
	await settle()
	check(screen.state.character.entry == "reincarnation" and screen.state.character.sex == "F", "random reincarnation completes with same sex")
	var fullname: String = screen.state.character.surname + screen.state.character.given
	check(fullname in ["林知遠", "歐陽映禾"], "reincarnation retains one eligible parent's name")
	check(screen.state.character.appearance == "settlement-female-01", "server preserves assigned settlement appearance")
	check(screen.controls.portrait_image.texture.resource_path == "res://registration/assets/settlement-female-01.png", "paired child's actual portrait is rendered")
	check(screen.controls.portrait_caption.text.contains("沿用子女"), "child appearance caption is accurate")
	await capture("09-demo-child-created")
	root.size = Vector2i(960, 540)
	await create_timer(0.2).timeout
	await capture("10-demo-small-window")
	await click(screen.controls.back)
	check(menu.start_button.is_visible_in_tree() and not screen.visible, "return restores accepted login")
	await click(menu.start_button)
	check(screen.visible, "registration reopens existing screen")
	check(screen.controls.portrait_image.texture.resource_path == "res://registration/assets/settlement-female-01.png", "returning to creation retains child appearance")
	await key(KEY_ESCAPE)
	check(not screen.visible, "Escape returns to title")
	var report := {"passed": failures == 0, "failures": failures, "checks": checks, "engine": Engine.get_version_info().string, "mode": "demo", "external_services_called": false, "source": OS.get_environment("YIYU_DEMO_VERIFY_SOURCE")}
	var file := FileAccess.open(output.path_join("demo-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("YIYU_DEMO_UI_VERIFIED " + JSON.stringify(report))
	quit(0 if failures == 0 else 1)
