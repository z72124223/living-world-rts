extends Node
## Runs real Control input, rendered captures, persistence and the packaged game.
## Writes only inside an explicitly selected isolated verification directory.

var menu: Control
var checks: Array[Dictionary] = []
var failures := 0
var output := ""

func _ready() -> void:
	menu = get_parent()
	output = OS.get_environment("YIYU_VERIFY_DIR")
	call_deferred("_run")

func _check(condition: bool, name: String) -> void:
	checks.append({"check": name, "passed": condition})
	if not condition:
		failures += 1
		printerr("LOGIN_CHECK_FAILED: " + name)

func _wait_for(condition: Callable, seconds := 15.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await get_tree().create_timer(0.05).timeout
	return condition.call()

func _click(control: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var viewport := control.get_viewport()
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	viewport.push_input(motion, true)
	await get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event, true)
		await get_tree().process_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame

func _capture(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_check(image.save_png(output.path_join(name + ".png")) == OK, "rendered screenshot saved: " + name)

func _report() -> void:
	var report := {"passed": failures == 0, "failures": failures, "checks": checks, "engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "executable": OS.get_executable_path(), "settings_path": menu.settings_path, "game_pid": menu.last_launch_pid}
	var file := FileAccess.open(output.path_join("login-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("YIYU_LOGIN_VERIFIED " + JSON.stringify(report))

func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	_check(menu.start_button.has_focus(), "initial keyboard focus is login")
	_check(menu.start_button.is_visible_in_tree(), "real login control is visible")
	await _capture("01-login")
	await _key(KEY_DOWN)
	_check(menu.settings_button.has_focus(), "arrow key moves focus to settings")
	await _key(KEY_ENTER)
	_check(menu.settings_overlay.visible, "Enter opens settings through real keyboard input")
	_check(menu.start_button.disabled, "modal prevents activation of background login")
	await _capture("02-settings")
	menu.volume_slider.value = 12
	await _key(KEY_ESCAPE)
	_check(not menu.settings_overlay.visible and is_equal_approx(menu.settings.volume, 0.65), "Escape cancels unapplied settings")
	await _click(menu.settings_button)
	_check(menu.settings_overlay.visible, "mouse click opens settings")
	menu.volume_slider.grab_focus()
	await _key(KEY_HOME)
	_check(menu.volume_slider.value == 0, "slider accepts keyboard input")
	menu.fps_choice.select(0)
	await _click(menu.apply_button)
	var saved := ConfigFile.new()
	var load_error := saved.load(menu.settings_path)
	_check(load_error == OK and saved.get_value("audio", "volume", -1) == 0.0 and saved.get_value("display", "fps", -1) == 30, "Apply writes actual user settings")
	_check(Engine.max_fps == 30 and menu.click_player.volume_db == -80.0, "saved settings affect runtime frame cap and menu audio")
	menu.settings = menu.DEFAULTS.duplicate()
	menu._load_settings()
	_check(menu.settings.fps == 30 and menu.settings.volume == 0.0, "settings are restored from disk")
	await _click(menu.settings_button)
	menu.display_choice.select(1)
	await _click(menu.apply_button)
	await get_tree().create_timer(0.3).timeout
	_check(get_window().mode == Window.MODE_FULLSCREEN, "fullscreen applies to the actual window")
	await _click(menu.settings_button)
	menu.display_choice.select(0)
	menu.fps_choice.select(1)
	menu.volume_slider.value = 65
	await _click(menu.apply_button)
	await get_tree().create_timer(0.3).timeout
	_check(get_window().mode == Window.MODE_WINDOWED, "window mode can be restored")
	get_window().size = Vector2i(960, 540)
	await get_tree().create_timer(0.2).timeout
	await _capture("03-small-window")
	_check(menu.exit_button.get_global_rect().end.y < 900, "menu remains in view at minimum window size")
	get_window().size = Vector2i(1280, 720)
	await get_tree().create_timer(0.2).timeout
	menu.game_path_override = output.path_join("missing-game.exe")
	await _click(menu.start_button)
	_check(menu.game_pid == -1 and not menu.start_button.disabled and "找不到" in menu.notice.text, "missing bundle gives visible error and remains retryable")
	await _capture("04-missing-game")
	menu.game_path_override = ""
	# An occupied port must not dispatch another child or attach to another world.
	var occupied := TCPServer.new()
	if occupied.listen(8793, "127.0.0.1") == OK:
		await _click(menu.start_button)
		await _wait_for(func(): return not menu.launching)
		_check(menu.game_pid == -1 and "已有遊戲" in menu.notice.text, "existing world prevents duplicate launch")
		occupied.stop()
	else:
		_check(false, "verification requires unused world port 8793")
		_report()
		get_tree().quit(1)
		return
	# This child is the real bundled game, using its existing diagnostic flow.
	# Its world/save/report paths are explicitly isolated from the player's saves.
	OS.set_environment("RTS_SAVE_DIRECTORY", output.path_join("isolated-game-saves"))
	OS.set_environment("RTS_VERIFY_OUTPUT", output.path_join("game"))
	OS.set_environment("RTS_LAUNCH_VERIFY_PHASE", "create")
	await _click(menu.start_button)
	_check(await _wait_for(func(): return menu.last_launch_pid > 0), "login click starts actual native game process")
	_check(menu.start_button.disabled, "login is disabled while game is running")
	var launched: int = menu.last_launch_pid
	await _click(menu.start_button)
	_check(menu.last_launch_pid == launched, "repeated login cannot launch a duplicate game")
	var returned := await _wait_for(func(): return menu.last_launch_pid > 0 and menu.game_pid == -1, 40.0)
	_check(returned and not menu.start_button.disabled and "已返回" in menu.notice.text, "game closes cleanly and returns to usable login menu")
	var game_report_path := output.path_join("game/launcher-create.json")
	var game_report: Variant = JSON.parse_string(FileAccess.get_file_as_string(game_report_path)) if FileAccess.file_exists(game_report_path) else null
	_check(game_report is Dictionary and game_report.get("failed", -1) == 0, "actual four-person game connects Rust and passes bundled checks")
	await _capture("05-return-from-game")
	await _click(menu.exit_button)
	_check(menu.exit_dialog.visible, "exit button opens confirmation")
	await _capture("06-exit-confirmation")
	await _click(menu.exit_dialog.get_cancel_button())
	_check(not menu.exit_dialog.visible, "cancel exit keeps application open")
	await _click(menu.exit_button)
	_check(menu.exit_dialog.visible, "exit can be requested again")
	_report()
	if failures > 0:
		get_tree().quit(1)
	else:
		# Clicking the real confirmation ends the native application; the caller checks exit code.
		await _click(menu.exit_dialog.get_ok_button())
