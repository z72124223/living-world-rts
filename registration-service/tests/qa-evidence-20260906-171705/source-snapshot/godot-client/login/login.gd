extends Control
## Native title menu and registration entry.

const REGISTRATION = preload("res://registration/registration.gd")
const PAPER := Color("e6d7b7")
const GOLD := Color("c99e58")
const QUIET := Color("a9aaa5")
const SERIF = preload("res://login/assets/NotoSerifTC.ttf")
const SANS = preload("res://assets/ui-font.otf")
const BACKGROUND = preload("res://login/assets/cavern-background.png")
const DEFAULTS := {"fullscreen": false, "fps": 60, "volume": 0.65}
const FPS_VALUES := [30, 60, 120]

var settings: Dictionary = DEFAULTS.duplicate()
var settings_path := "user://login-settings.cfg"
var start_button: Button
var settings_button: Button
var exit_button: Button
var menu_buttons: Array[Button] = []
var notice: Label
var settings_overlay: ColorRect
var display_choice: OptionButton
var fps_choice: OptionButton
var volume_slider: HSlider
var volume_value: Label
var apply_button: Button
var cancel_button: Button
var exit_dialog: ConfirmationDialog
var click_player: AudioStreamPlayer
var registration_screen: Control
var title_nodes: Array[CanvasItem] = []
var game_pid := -1
var game_path_override := ""
var launching := false
var process_poll := 0.0
var verification_mode := false
var last_launch_pid := -1

func _ready() -> void:
	verification_mode = OS.has_feature("editor") and "--verify-registration" in OS.get_cmdline_user_args()
	if verification_mode:
		var output := OS.get_environment("YIYU_VERIFY_DIR")
		if output.is_empty():
			push_error("Verification requires YIYU_VERIFY_DIR")
			get_tree().quit(2)
			return
		DirAccess.make_dir_recursive_absolute(output)
		settings_path = output.path_join("settings.cfg")
	get_tree().auto_accept_quit = false
	get_tree().root.gui_embed_subwindows = true
	get_window().close_requested.connect(_request_exit)
	get_window().content_scale_size = Vector2i(1600, 900)
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_window().min_size = Vector2i(960, 540)
	get_window().size = Vector2i(1280, 720)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_load_settings()
	_build_audio()
	_build_menu()
	_build_settings()
	for child in get_children():
		if child is CanvasItem: title_nodes.append(child)
	_apply_settings()
	start_button.grab_focus()
	if verification_mode:
		call_deferred("_start_verification")

func _start_verification() -> void:
	add_child(load("res://registration/verify_registration.gd").new())

func _label(text_value: String, rect: Rect2, font_size: int, serif := false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", SERIF if serif else SANS)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", PAPER)
	return label

func _style(background_color: Color, border: Color, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	style.content_margin_left = 20
	style.content_margin_right = 20
	return style

func _button(text_value: String, rect: Rect2, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var button_font := FontVariation.new()
	button_font.base_font = SERIF
	button_font.variation_opentype = {"wght": 500.0}
	button.add_theme_font_override("font", button_font)
	button.add_theme_font_size_override("font_size", 36 if primary else 29)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color("fff0cf"))
	button.add_theme_color_override("font_focus_color", Color("fff0cf"))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", QUIET)
	button.add_theme_stylebox_override("normal", _style(Color(0.045, 0.075, 0.10, 0.70) if primary else Color(0, 0, 0, 0.08), Color("ad9776") if primary else Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override("hover", _style(Color(0.14, 0.16, 0.17, 0.82), GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color(0.20, 0.17, 0.12, 0.92), PAPER))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), GOLD, 2))
	button.add_theme_stylebox_override("disabled", _style(Color(0.04, 0.06, 0.08, 0.65), Color("665e51")))
	button.pressed.connect(func():
		click_player.play()
		action.call())
	return button

func _build_menu() -> void:
	var background := TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var title := _label("異域", Rect2(78, 97, 344, 183), 136, true)
	var title_font := FontVariation.new()
	title_font.base_font = SERIF
	title_font.variation_opentype = {"wght": 650.0}
	title.add_theme_font_override("font", title_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color("18120c"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.add_theme_constant_override("outline_size", 1)
	title.add_theme_color_override("font_outline_color", Color("6e5e44"))
	add_child(title)
	var line := ColorRect.new()
	line.position = Vector2(78, 303)
	line.size = Vector2(344, 1)
	line.color = Color(0.66, 0.54, 0.36, 0.70)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	var diamond := _label("◇", Rect2(231, 285, 38, 35), 26, true)
	diamond.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diamond.add_theme_color_override("font_color", GOLD)
	add_child(diamond)
	start_button = _button("登入遊戲", Rect2(78, 349, 344, 94), _launch_game, true)
	settings_button = _button("設定", Rect2(78, 470, 344, 72), _open_settings)
	exit_button = _button("離開遊戲", Rect2(78, 562, 344, 72), _request_exit)
	menu_buttons.assign([start_button, settings_button, exit_button])
	for button in menu_buttons:
		add_child(button)
	for index in range(menu_buttons.size()):
		var current := menu_buttons[index]
		var next := menu_buttons[(index + 1) % menu_buttons.size()]
		var previous := menu_buttons[(index + menu_buttons.size() - 1) % menu_buttons.size()]
		current.focus_neighbor_bottom = current.get_path_to(next)
		current.focus_next = current.get_path_to(next)
		current.focus_neighbor_top = current.get_path_to(previous)
		current.focus_previous = current.get_path_to(previous)
	notice = _label("", Rect2(79, 663, 350, 110), 17)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_color_override("font_color", Color("d6ba87"))
	add_child(notice)
	var hint := _label("↑ ↓ 選擇　Enter 確認　Esc 返回", Rect2(79, 841, 430, 26), 14)
	hint.add_theme_color_override("font_color", Color("959590"))
	add_child(hint)
	exit_dialog = ConfirmationDialog.new()
	exit_dialog.title = "離開異域"
	exit_dialog.dialog_text = "確定要離開遊戲嗎？"
	exit_dialog.ok_button_text = "離開遊戲"
	exit_dialog.cancel_button_text = "返回"
	exit_dialog.theme = _dialog_theme()
	exit_dialog.exclusive = true
	exit_dialog.confirmed.connect(func(): get_tree().quit())
	exit_dialog.canceled.connect(func(): exit_button.grab_focus())
	add_child(exit_dialog)

func _dialog_theme() -> Theme:
	var result := Theme.new()
	result.default_font = SANS
	result.default_font_size = 22
	result.set_stylebox("panel", "AcceptDialog", _style(Color("152027"), GOLD))
	return result

func _build_settings() -> void:
	settings_overlay = ColorRect.new()
	settings_overlay.color = Color(0.01, 0.015, 0.02, 0.78)
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(settings_overlay)
	var panel := Panel.new()
	panel.position = Vector2(500, 185)
	panel.size = Vector2(600, 530)
	panel.add_theme_stylebox_override("panel", _style(Color("121e25"), Color("968467")))
	settings_overlay.add_child(panel)
	panel.add_child(_label("設定", Rect2(38, 27, 450, 55), 36, true))
	panel.add_child(_label("顯示模式", Rect2(40, 119, 200, 40), 23))
	display_choice = OptionButton.new()
	display_choice.position = Vector2(282, 115)
	display_choice.size = Vector2(276, 48)
	display_choice.add_item("視窗")
	display_choice.add_item("全螢幕")
	display_choice.theme = _dialog_theme()
	panel.add_child(display_choice)
	panel.add_child(_label("幀率上限", Rect2(40, 199, 220, 40), 23))
	fps_choice = OptionButton.new()
	fps_choice.position = Vector2(282, 195)
	fps_choice.size = Vector2(276, 48)
	fps_choice.theme = _dialog_theme()
	for value in FPS_VALUES:
		fps_choice.add_item("每秒 %d 幀" % value)
	panel.add_child(fps_choice)
	panel.add_child(_label("介面音量", Rect2(40, 279, 220, 40), 23))
	volume_slider = HSlider.new()
	volume_slider.position = Vector2(282, 279)
	volume_slider.size = Vector2(205, 36)
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 1
	volume_slider.value_changed.connect(func(value: float): volume_value.text = "%d%%" % int(value))
	panel.add_child(volume_slider)
	volume_value = _label("65%", Rect2(499, 276, 80, 40), 21)
	panel.add_child(volume_value)
	var settings_note := _label("設定會保存在這台電腦。\n介面音量控制選單按鍵音效。", Rect2(40, 346, 520, 65), 17)
	settings_note.add_theme_color_override("font_color", QUIET)
	panel.add_child(settings_note)
	cancel_button = _button("返回", Rect2(40, 435, 220, 57), _close_settings)
	apply_button = _button("套用並返回", Rect2(287, 435, 271, 57), _save_settings, true)
	panel.add_child(cancel_button)
	panel.add_child(apply_button)
	settings_overlay.hide()

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var fullscreen: Variant = config.get_value("display", "fullscreen", false)
	var fps: Variant = config.get_value("display", "fps", 60)
	var volume: Variant = config.get_value("audio", "volume", 0.65)
	settings.fullscreen = fullscreen if fullscreen is bool else false
	settings.fps = fps if fps is int and fps in FPS_VALUES else 60
	settings.volume = clampf(float(volume), 0.0, 1.0) if (volume is float or volume is int) and is_finite(float(volume)) else 0.65

func _apply_settings() -> void:
	Engine.max_fps = settings.fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	get_window().mode = Window.MODE_FULLSCREEN if settings.fullscreen else Window.MODE_WINDOWED
	click_player.volume_db = linear_to_db(settings.volume) if settings.volume > 0.0 else -80.0

func _open_settings() -> void:
	if launching or game_pid > 0:
		return
	display_choice.select(1 if settings.fullscreen else 0)
	fps_choice.select(FPS_VALUES.find(settings.fps))
	volume_slider.value = settings.volume * 100.0
	volume_value.text = "%d%%" % int(volume_slider.value)
	for button in menu_buttons:
		button.disabled = true
	settings_overlay.show()
	display_choice.grab_focus()

func _close_settings() -> void:
	settings_overlay.hide()
	for button in menu_buttons:
		button.disabled = false
	settings_button.grab_focus()

func _save_settings() -> void:
	var draft := {"fullscreen": display_choice.selected == 1, "fps": FPS_VALUES[fps_choice.selected], "volume": volume_slider.value / 100.0}
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", draft.fullscreen)
	config.set_value("display", "fps", draft.fps)
	config.set_value("audio", "volume", draft.volume)
	var error := config.save(settings_path)
	if error != OK:
		notice.text = "設定儲存失敗，原設定仍保留。"
		_close_settings()
		return
	settings = draft
	_apply_settings()
	_close_settings()
	notice.text = "設定已儲存。"

func _launch_game() -> void:
	if not is_instance_valid(registration_screen):
		registration_screen = REGISTRATION.new()
		registration_screen.back_requested.connect(_return_from_registration)
		add_child(registration_screen)
	for item in title_nodes: item.hide()
	registration_screen.show()

func _return_from_registration() -> void:
	registration_screen.hide()
	for item in title_nodes: item.show()
	settings_overlay.hide()
	start_button.grab_focus()

func _request_exit() -> void:
	if launching or game_pid > 0:
		return
	if settings_overlay.visible:
		_close_settings()
		return
	exit_dialog.popup_centered(Vector2i(470, 200))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(registration_screen) and registration_screen.visible:
				registration_screen.handle_back()
			elif settings_overlay.visible:
				_close_settings()
			elif not exit_dialog.visible:
				_request_exit()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F11:
			get_window().mode = Window.MODE_WINDOWED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
			get_viewport().set_input_as_handled()

func _build_audio() -> void:
	click_player = AudioStreamPlayer.new()
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var samples := PackedByteArray()
	var length := 2646
	samples.resize(length * 2)
	for index in range(length):
		var t := float(index) / 22050.0
		var envelope := sin(PI * float(index) / float(length)) * exp(-t * 24.0)
		var value := int(4200.0 * envelope * (sin(TAU * 660.0 * t) + 0.3 * sin(TAU * 990.0 * t)))
		samples.encode_s16(index * 2, value)
	sound.data = samples
	click_player.stream = sound
	add_child(click_player)
