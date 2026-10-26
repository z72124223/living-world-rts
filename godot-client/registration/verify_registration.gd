extends Node
## Editor-only real native input + rendered evidence, using an isolated HTTP fixture.
var menu: Control
var screen: Control
var output := ""
var checks: Array[Dictionary] = []
var failures := 0

func _ready() -> void:
	menu = get_parent()
	output = OS.get_environment("YIYU_VERIFY_DIR")
	call_deferred("_run")

func _check(value: bool, description: String) -> void:
	checks.append({"check": description, "passed": value})
	if not value:
		failures += 1
		printerr("REGISTRATION_CHECK_FAILED: " + description)

func _click(node: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var point := node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame

func _type(node: LineEdit, value: String) -> void:
	await _click(node)
	node.clear()
	for character in value:
		var event := InputEventKey.new()
		event.unicode = character.unicode_at(0)
		event.pressed = true
		get_viewport().push_input(event, true)
	await get_tree().process_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame

func _settle() -> void:
	var end := Time.get_ticks_msec() + 10000
	await get_tree().process_frame
	while screen.busy and Time.get_ticks_msec() < end:
		await get_tree().create_timer(0.05).timeout
	_check(not screen.busy, "HTTP request finished")
	await get_tree().process_frame

func _capture(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "render captured: " + name)

func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	_check(menu.start_button.has_focus(), "login initially has keyboard focus")
	await _capture("01-login")
	await _click(menu.settings_button)
	_check(menu.settings_overlay.visible, "accepted login settings still open")
	await _key(KEY_ESCAPE)
	_check(not menu.settings_overlay.visible, "Escape closes settings")
	await _click(menu.start_button)
	_check(is_instance_valid(menu.registration_screen), "login enters native registration")
	screen = menu.registration_screen
	_check(not menu.start_button.is_visible_in_tree(), "title buttons hidden behind registration")
	# Native layout bounds are checked in addition to visually inspecting the capture.
	for candidate in screen.canvas.get_children():
		if candidate is Panel and candidate.position.x > 900:
			for art in candidate.get_children():
				if art is TextureRect:
					_check(art.size.x <= candidate.size.x and art.size.y <= candidate.size.y, "character illustration fits its frame")
	var banner_layer := CanvasLayer.new()
	add_child(banner_layer)
	var banner := Label.new()
	banner.text = "實機測試資料　｜　非真實身分／非付費 AI 查核"
	banner.position = Vector2(835, 46)
	banner.add_theme_font_override("font", preload("res://assets/ui-font.otf"))
	banner.add_theme_font_size_override("font_size", 22)
	banner_layer.add_child(banner)
	await _capture("02-account")
	await _click(screen.controls.step_3)
	_check(screen.controls.reincarnation.disabled, "empty child pool is disabled")
	_check(screen.controls.create_character.disabled, "unverified creation is disabled")
	_check(not screen.controls.has("gender") and not screen.controls.has("appearance"), "no sex or appearance selection")
	await _capture("03-creation-pending")
	await _click(screen.controls.step_0)
	await _type(screen.controls.username, "ui_preview")
	await _type(screen.controls.password, "test-only-password-456")
	_check(screen.controls.password.secret, "password input is masked")
	await _click(screen.controls.account_consent)
	await _click(screen.controls.register)
	await _settle()
	_check(screen.step == 1 and not screen.token.is_empty(), "registration creates authenticated session over HTTP")
	await _capture("04-identity")
	await _click(screen.controls.identity_consent)
	await _click(screen.controls.identity_start)
	await _settle()
	if OS.get_environment("YIYU_UI_FIXTURE") != "success":
		_check(screen.status_text.contains("尚未設定"), "unconfigured identity provider shown honestly")
		_check(screen.state.identity == "unverified", "unconfigured provider never grants verified state")
		await _capture("05-service-not-configured")
	else:
		await _click(screen.controls.identity_check)
		await _settle()
		_check(screen.state.identity == "verified" and screen.state.sex == "F", "fixture government sex locks female character")
		await _click(screen.controls.step_2)
		await _capture("05-ai")
		await _type(screen.controls.api_key, "sk-test-only-not-a-real-api-key")
		await _click(screen.controls.fee_consent)
		await _click(screen.controls.ai_connect)
		await _settle()
		_check(screen.state.aiConnected, "API connection stored through backend fixture")
		_check(screen.controls.api_key.text.is_empty(), "API input cleared after request")
		await _click(screen.controls.step_3)
		await _type(screen.controls.surname, "林")
		await _type(screen.controls.given, "知遠")
		await _click(screen.controls.name_fee)
		await _click(screen.controls.review_name)
		await _settle()
		_check(not screen.controls.create_character.disabled, "exact reviewed name enables creation")
		await _capture("06-creation-reviewed")
		await _type(screen.controls.given, "若川")
		_check(screen.controls.create_character.disabled, "editing reviewed name blocks creation")
		await _type(screen.controls.given, "知遠")
		await _click(screen.controls.create_character)
		_check(is_instance_valid(screen.modal), "naming policy popup opens")
		await _key(KEY_TAB)
		_check(screen.controls.policy_accept.has_focus(), "Tab remains inside naming policy popup")
		await _key(KEY_TAB)
		_check(screen.controls.policy_cancel.has_focus(), "policy focus cycles inside modal")
		await _capture("07-policy")
		await _click(screen.controls.policy_cancel)
		_check(not is_instance_valid(screen.modal), "popup can cancel without creating")
		await _click(screen.controls.create_character)
		await _click(screen.controls.policy_accept)
		await _settle()
		_check(screen.state.character is Dictionary, "fixture creates persisted character through HTTP")
		await _capture("08-created")
	get_window().size = Vector2i(960, 540)
	await get_tree().create_timer(0.25).timeout
	await _capture("09-small-window")
	await _click(screen.controls.back)
	_check(not screen.visible and menu.start_button.is_visible_in_tree(), "return restores accepted login")
	await _click(menu.start_button)
	_check(screen.visible, "re-enter registration without duplicate screen")
	await _key(KEY_ESCAPE)
	_check(not screen.visible, "Escape returns from registration")
	var report := {"passed": failures == 0, "failures": failures, "checks": checks, "fixture": OS.get_environment("YIYU_UI_FIXTURE"), "engine": Engine.get_version_info().string, "external_services_called": false}
	var file := FileAccess.open(output.path_join("registration-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("YIYU_REGISTRATION_VERIFIED " + JSON.stringify(report))
	get_tree().quit(0 if failures == 0 else 1)
