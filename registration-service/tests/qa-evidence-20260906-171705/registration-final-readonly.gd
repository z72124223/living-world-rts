extends Control
## Native account / identity / OpenAI / creation flow. All authority is server-owned.
signal back_requested

const BG = preload("res://registration/assets/creation-background.png")
const MALE = preload("res://registration/assets/arrival-male.png")
const FEMALE = preload("res://registration/assets/arrival-female.png")
const SERIF = preload("res://login/assets/NotoSerifTC.ttf")
const SANS = preload("res://assets/ui-font.otf")
const INK := Color("302f29")
const QUIET := Color("777160")
const GOLD := Color("a68750")
const MODEL := "gpt-5.6-luna"
const BASE := "http://127.0.0.1:8787"
const DEMO_BASE := "http://127.0.0.1:8788"
const POLICY := "yiyu-names-2026-09-v1"

var step := 0
var token := ""
var state: Dictionary = {}
var busy := false
var draft := {"username": "", "surname": "", "given": "", "entry": "arrival"}
var status_text := "登入帳號後，依序完成查核與創角。"
var status_error := false
var http: HTTPRequest
var canvas: Control
var form: Control
var status_label: Label
var modal: Control
var controls: Dictionary = {}
var identity_url := ""
var demo_mode := false
var service_base := BASE

func _ready() -> void:
	demo_mode = OS.get_cmdline_user_args().has("--registration-demo")
	service_base = DEMO_BASE if demo_mode else BASE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	http = HTTPRequest.new()
	http.timeout = 40.0
	add_child(http)
	_render()

func _style(color: Color, border := Color("aa9877")) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 16
	box.content_margin_right = 16
	return box

func _label(parent: Node, value: String, rect: Rect2, font_size := 22, color := INK, serif := false) -> Label:
	var node := Label.new()
	node.text = value
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override("font", SERIF if serif else SANS)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _button(parent: Node, id: String, value: String, rect: Rect2, action: Callable, primary := false, disabled_value := false) -> Button:
	var node := Button.new()
	node.name = id
	node.text = value
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override("font", SERIF)
	node.add_theme_font_size_override("font_size", 23)
	node.add_theme_color_override("font_color", Color("f1e6ce") if primary else INK)
	node.add_theme_color_override("font_hover_color", Color("fff6dc") if primary else INK)
	node.add_theme_color_override("font_focus_color", Color("fff6dc") if primary else INK)
	node.add_theme_color_override("font_disabled_color", Color("8b8576"))
	node.add_theme_stylebox_override("normal", _style(Color("39463f") if primary else Color("e4d7bb")))
	node.add_theme_stylebox_override("hover", _style(Color("526256") if primary else Color("f3e7cc"), GOLD))
	node.add_theme_stylebox_override("pressed", _style(Color("697462") if primary else Color("cabc9d")))
	node.add_theme_stylebox_override("disabled", _style(Color("c4bca8"), Color("aaa18e")))
	node.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color("ad7932")))
	node.disabled = disabled_value
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(func():
		if not busy: action.call())
	parent.add_child(node)
	controls[id] = node
	return node

func _field(id: String, placeholder: String, rect: Rect2, value := "", secret := false) -> LineEdit:
	var node := LineEdit.new()
	node.name = id
	node.position = rect.position
	node.size = rect.size
	node.placeholder_text = placeholder
	node.text = value
	node.secret = secret
	node.max_length = 128 if secret else 32
	node.add_theme_font_override("font", SANS)
	node.add_theme_font_size_override("font_size", 25)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_placeholder_color", QUIET)
	node.add_theme_color_override("caret_color", INK)
	node.add_theme_stylebox_override("normal", _style(Color("eee3ca")))
	node.add_theme_stylebox_override("focus", _style(Color("faf0d9"), GOLD))
	form.add_child(node)
	controls[id] = node
	return node

func _check(id: String, value: String, y: float) -> CheckBox:
	var node := CheckBox.new()
	node.name = id
	node.position = Vector2(0, y)
	node.size = Vector2(610, 40)
	node.text = value
	node.add_theme_font_override("font", SANS)
	node.add_theme_font_size_override("font_size", 19)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", INK)
	node.add_theme_color_override("font_pressed_color", INK)
	node.add_theme_color_override("font_hover_pressed_color", INK)
	form.add_child(node)
	controls[id] = node
	return node

func _render() -> void:
	if is_instance_valid(canvas):
		remove_child(canvas)
		canvas.queue_free()
	controls.clear()
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(canvas)
	var background := TextureRect.new()
	background.texture = BG
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.07, 0.055, 0.17)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(shade)
	_label(canvas, "異域", Rect2(62, 28, 170, 62), 48, Color("eddfc2"), true)
	_label(canvas, "此身入異域　此名記人間", Rect2(244, 43, 420, 36), 21, Color("cbbd9d"), true)
	if demo_mode:
		_label(canvas, "創角測試　｜　虛構資料・不驗證身分・不產生 AI 費用", Rect2(765, 43, 775, 40), 21, Color("ffe1a6"))
	var panel := Panel.new()
	panel.position = Vector2(60, 117)
	panel.size = Vector2(748, 675)
	panel.add_theme_stylebox_override("panel", _style(Color("d9c9a5")))
	canvas.add_child(panel)
	var tabs := ["一　帳號", "二　實名查核", "三　智慧服務", "四　創建角色"]
	for i in range(4):
		var index := i
		_button(panel, "step_%d" % i, tabs[i], Rect2(12 + i * 183, 12, 178, 49), func():
			step = index
			status_text = ""
			_render(), i == step)
	form = Control.new()
	form.position = Vector2(43, 90)
	form.size = Vector2(662, 557)
	panel.add_child(form)
	match step:
		0: _account_form()
		1: _identity_form()
		2: _ai_form()
		3: _character_form()
	_portrait()
	_button(canvas, "back", "返回登入", Rect2(60, 817, 180, 54), _back)
	if demo_mode:
		_button(canvas, "demo_reset", "重新測試", Rect2(260, 817, 180, 54), _start_demo, false, token.is_empty())
	status_label = _label(canvas, status_text, Rect2(470 if demo_mode else 270, 815, 1040 if demo_mode else 1230, 66), 21, Color("ffd4b4") if status_error else Color("eddfc2"))

func _title(value: String, subtitle: String) -> void:
	_label(form, value, Rect2(0, 0, 650, 58), 37, INK, true)
	_label(form, subtitle, Rect2(0, 65, 655, 70), 20, QUIET)

func _account_form() -> void:
	if demo_mode:
		_title("試走你的入世旅程", "這是獨立的創角測試。全部使用虛構資料，關閉遊戲後即清除。")
		_label(form, "不需證件、密碼或 API 金鑰。\n\n測試身分固定為女性，無法自選性別或外貌。\n可試首次傳送，或接手父母已命名的公開子女。", Rect2(0, 158, 650, 185), 24)
		_label(form, "正式入世仍須完成實名、OpenAI 連線與姓名審核。", Rect2(0, 362, 650, 60), 20, QUIET)
		_button(form, "demo_start", "開始創角測試" if token.is_empty() else "重開一輪測試", Rect2(0, 435, 310, 58), _start_demo, true)
		if not token.is_empty():
			_button(form, "next_identity", "繼續查核步驟", Rect2(335, 435, 315, 58), func(): step = 1; _render())
		return
	_title("建立你的帳號", "帳號綁定真實所有權。遊戲中的姓名與身分資料分開保存。")
	if not token.is_empty():
		_label(form, "已登入　" + str(state.get("account", "")), Rect2(0, 158, 630, 54), 28)
		_label(form, "你可以隨時查看後續步驟。\n所有必要查核通過後，才能正式入世。", Rect2(0, 240, 640, 95), 24)
		_button(form, "logout", "登出帳號", Rect2(0, 427, 255, 58), _logout)
		_button(form, "next_identity", "前往實名查核", Rect2(285, 427, 365, 58), func(): step = 1; _render(), true)
		return
	_label(form, "帳號", Rect2(0, 143, 100, 40), 23)
	var username := _field("username", "4–32 個英數字或底線", Rect2(115, 138, 535, 54), draft.username)
	username.text_changed.connect(func(value: String): draft.username = value)
	_label(form, "密碼", Rect2(0, 219, 100, 40), 23)
	_field("password", "12–128 個字元", Rect2(115, 214, 535, 54), "", true)
	_check("account_consent", "我了解一人一帳號，且不得冒用他人身分。", 298)
	_label(form, "實名資料不公開；違規處置可申覆。\n證件與本人查核將在 Persona 的安全頁面完成。", Rect2(0, 347, 650, 63), 20, QUIET)
	_button(form, "login", "登入既有帳號", Rect2(0, 435, 300, 58), func(): _authenticate(false))
	_button(form, "register", "註冊帳號", Rect2(330, 435, 320, 58), func(): _authenticate(true), true)

func _identity_form() -> void:
	if demo_mode:
		_title("體驗實名查核步驟", "此處只模擬操作，不會開啟 Persona，也不收取任何證件資料。")
		var verified: bool = state.get("identity", "") == "verified"
		_label(form, "模擬查核已通過" if verified else "尚未進行模擬查核", Rect2(0, 151, 650, 50), 28)
		_label(form, "虛構登記性別　" + _sex_text() + "\n\n正式模式會以本人有效證件與活體查核結果鎖定。\n這裡的通過結果無法帶入正式帳號。", Rect2(0, 229, 650, 151), 23)
		_check("identity_consent", "我了解這是虛構身分的測試結果。", 390)
		_button(form, "demo_identity", "模擬完成查核", Rect2(0, 467, 310, 58), func(): _perform("/v1/demo/identity", {"consent": controls.identity_consent.button_pressed}), true, token.is_empty() or verified)
		_button(form, "next_ai", "前往智慧服務", Rect2(335, 467, 315, 58), func(): step = 2; _render(), false, not verified)
		return
	_title("實名查核", "確認證件與本人，建立帳號所有權。證件姓名不會成為角色姓名。")
	var status := str(state.get("identity", "unverified"))
	var names := {"unverified": "尚未驗證", "pending": "查核處理中", "verified": "實名查核已通過", "needs_review": "資料需要人工複查", "declined": "查核未通過", "failed": "查核未通過", "expired": "查核已逾期", "blocked": "此身分已受限制"}
	_label(form, str(names.get(status, "等待查核")), Rect2(0, 139, 650, 43), 27)
	_label(form, "登記性別　" + _sex_text() + "　｜　依查核結果鎖定", Rect2(0, 200, 650, 36), 22)
	_label(form, "在驗證頁提交證件並完成本人查核。\n遊戲保存查核參照與必要結果，不保存證件照片。", Rect2(0, 253, 650, 75), 21)
	_check("identity_consent", "我同意以本人有效證件進行身分查核。", 343)
	_button(form, "identity_start", "開始／繼續查核", Rect2(0, 407, 310, 56), _identity_start, true, token.is_empty() or status == "verified")
	_button(form, "identity_check", "查詢查核結果", Rect2(335, 407, 315, 56), func(): _perform("/v1/identity/check", {}), false, token.is_empty())
	var message := "驗證頁完成後，回到遊戲查詢結果。"
	if not state.get("identityServiceConfigured", false):
		message = "營運方尚未設定實名服務，正式查核暫未開放。"
	if token.is_empty(): message = "請先登入帳號。可查看後續畫面，尚不能完成創角。"
	_label(form, message, Rect2(0, 485, 650, 53), 19, QUIET)

func _ai_form() -> void:
	if demo_mode:
		_title("體驗智慧服務步驟", "測試使用固定模擬回覆，不呼叫 OpenAI，也不產生費用。")
		_label(form, "模擬智慧服務已連線" if state.get("aiConnected", false) else "尚未啟用模擬智慧服務", Rect2(0, 151, 650, 50), 27)
		_label(form, "不需要貼上金鑰。\n\n正式模式使用自己的 OpenAI 金鑰及 Luna 模型；\n遊戲中的 AI 請求由玩家付費。", Rect2(0, 229, 650, 155), 23)
		_check("fee_consent", "我了解本輪智慧取名與審核都是模擬結果。", 390)
		_button(form, "demo_ai", "啟用模擬智慧服務", Rect2(0, 467, 310, 58), func(): _perform("/v1/demo/ai", {"consent": controls.fee_consent.button_pressed, "dailyMax": 20}), true, state.get("identity", "") != "verified")
		_button(form, "next_character", "前往創建角色", Rect2(335, 467, 315, 58), func(): step = 3; _render(), false, not state.get("aiConnected", false))
		return
	_title("連結你的智慧服務", "遊戲只使用 OpenAI。每次 AI 請求由你的 OpenAI 帳戶付費。")
	_label(form, "使用模型　" + MODEL, Rect2(0, 140, 650, 35), 23)
	var key := _field("api_key", "貼上自己的 OpenAI API 金鑰", Rect2(0, 194, 650, 54), "", true)
	key.max_length = 520
	_label(form, "金鑰加密保存；畫面在送出後立即清空金鑰。", Rect2(0, 259, 650, 35), 19, QUIET)
	_label(form, "每日遊戲 AI 請求上限", Rect2(0, 305, 420, 35), 22)
	var limit := SpinBox.new()
	limit.position = Vector2(490, 300)
	limit.size = Vector2(160, 45)
	limit.min_value = 1
	limit.max_value = 100
	limit.value = state.get("dailyMax", 20)
	limit.add_theme_font_override("font", SANS)
	limit.add_theme_font_size_override("font_size", 23)
	form.add_child(limit)
	controls["daily_max"] = limit
	_check("fee_consent", "我同意連線測試與之後點選的 AI 請求由我付費。", 363)
	_button(form, "ai_connect", "儲存並測試連線", Rect2(0, 422, 310, 55), _connect_ai, true, state.get("identity", "") != "verified")
	_button(form, "ai_remove", "移除已存金鑰", Rect2(335, 422, 315, 55), func(): _perform("/v1/ai/remove", {}), false, not state.get("hasKey", false))
	var hint := "請先完成實名查核。"
	if state.get("identity", "") == "verified":
		if state.get("aiConnected", false): hint = "已連線；金鑰可留白重新測試。"
		elif state.get("hasKey", false): hint = "尚未連線或驗證已失效；金鑰可留白重新測試。"
		else: hint = "請到 OpenAI 平台建立 API 金鑰。"
	_label(form, hint + "今日已請求 %d 次。\n次數上限不是金額上限；實際費用依 OpenAI 帳單。" % int(state.get("callsToday", 0)), Rect2(0, 493, 650, 60), 18, QUIET)

func _character_form() -> void:
	if state.get("character") is Dictionary:
		var character: Dictionary = state.character
		if character.get("state", "active") != "active":
			_title("角色已受處置", "此角色目前無法使用。請聯絡營運方提出申覆。")
			_label(form, "處置狀態依官方人工審查紀錄。\n帳號與實名查核資料仍由營運方保護。", Rect2(0, 180, 650, 100), 24)
			return
		_title("測試入世完成" if demo_mode else "已登記入世", "虛構角色只存在本輪測試中。" if demo_mode else "此帳號的角色已保存。")
		_label(form, str(character.surname) + str(character.given), Rect2(0, 153, 650, 85), 56, INK, true)
		_label(form, "登記性別　" + _sex_text() + "\n入世方式　" + ("首次傳送" if character.entry == "arrival" else "隨機投胎"), Rect2(0, 266, 650, 105), 25)
		_label(form, "人物外貌不可調整。\n目前版本完成至創角登記。", Rect2(0, 426, 650, 80), 23, QUIET)
		return
	var identity_note := "已通過" if state.get("identity", "") == "verified" else "待查核"
	var ai_note := "已連線" if state.get("aiConnected", false) else "待連線"
	_title("創建角色", "實名　" + identity_note + "　／　智慧服務　" + ai_note + "\n姓名通過審核，並同意命名規範後才能入世。")
	var count := int(state.get("availableChildren", 0))
	if count == 0: draft.entry = "arrival"
	_button(form, "arrival", "首次傳送", Rect2(0, 136, 310, 57), func(): draft.entry = "arrival"; _render(), draft.entry == "arrival")
	_button(form, "reincarnation", "隨機投胎　%d" % count, Rect2(335, 136, 315, 57), func(): draft.entry = "reincarnation"; _render(), draft.entry == "reincarnation", count == 0)
	_label(form, "穿著現代日常服裝，沒有初始物品。" if draft.entry == "arrival" else "隨機接手同登記性別的開放子女，沿用父母所取姓名。", Rect2(0, 204, 650, 35), 19, QUIET)
	if draft.entry == "arrival":
		_label(form, "姓", Rect2(0, 260, 42, 42), 24)
		var surname := _field("surname", "姓氏", Rect2(47, 253, 151, 56), draft.surname)
		surname.max_length = 2
		_label(form, "名", Rect2(226, 260, 42, 42), 24)
		var given := _field("given", "名字", Rect2(271, 253, 216, 56), draft.given)
		given.max_length = 2
		surname.text_changed.connect(func(value: String): draft.surname = value; _invalidate_name())
		given.text_changed.connect(func(value: String): draft.given = value; _invalidate_name())
		_button(form, "suggest_name", "智慧取名", Rect2(503, 253, 147, 56), _suggest_name, false, not _name_service_ready())
		_label(form, "姓與名各一到兩個漢字，亦可使用複姓。", Rect2(0, 319, 650, 30), 18, QUIET)
	else:
		_label(form, "完成入世時配對，姓名由父母於出生時取定。\n可用子女可能被其他玩家先行接手。", Rect2(0, 257, 650, 85), 23)
	_label(form, "登記性別　" + _sex_text() + "　｜　外貌不可調整", Rect2(0, 365, 650, 40), 23)
	if draft.entry == "arrival":
		_check("name_fee", "我了解此次取名／審核為模擬回覆，不會扣費。" if demo_mode else "我同意此次智慧取名／姓名審核的 AI 費用。", 416)
	_button(form, "review_name", "審核姓名", Rect2(0, 477, 245, 60), _review_name, false, draft.entry != "arrival" or not _name_service_ready())
	_button(form, "create_character", "確認入世", Rect2(273, 477, 377, 60), _show_policy, true, not _can_create())

func _sex_text() -> String:
	match state.get("sex", ""):
		"M": return "男"
		"F": return "女"
	return "待實名確認"

func _name_service_ready() -> bool:
	return state.get("aiConnected", false) if demo_mode else state.get("hasKey", false)

func _portrait() -> void:
	var portrait_panel := Panel.new()
	portrait_panel.position = Vector2(947, 117)
	portrait_panel.size = Vector2(498, 675)
	portrait_panel.add_theme_stylebox_override("panel", _style(Color("d9c9a5"), Color("917c57")))
	canvas.add_child(portrait_panel)
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.texture = FEMALE if state.get("sex", "") == "F" else MALE
	portrait.position = Vector2(39, 26)
	portrait.size = Vector2(420, 572)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_panel.add_child(portrait)
	var note := "角色示意　・　等待實名查核" if state.get("identity", "") != "verified" else "固定人物　・　外貌不可調整"
	if draft.entry == "reincarnation": note = "傳送者示意　・　投胎後沿用子女外貌"
	var caption := _label(portrait_panel, note, Rect2(15, 612, 468, 34), 21, INK, true)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _can_create() -> bool:
	if token.is_empty() or state.get("identity", "") != "verified" or not state.get("aiConnected", false): return false
	if draft.entry == "reincarnation": return int(state.get("availableChildren", 0)) > 0
	var review: Variant = state.get("review")
	return review is Dictionary and review.get("approved", false) and review.get("surname", "") == draft.surname and review.get("given", "") == draft.given

func _invalidate_name() -> void:
	if controls.has("create_character"): controls.create_character.disabled = not _can_create()
	status_text = "修改後的姓名須重新審核。"
	status_label.text = status_text

func _authenticate(create: bool) -> void:
	var body := {"username": controls.username.text, "password": controls.password.text, "acceptAccount": controls.account_consent.button_pressed}
	controls.password.clear()
	await _perform("/v1/register" if create else "/v1/login", body)

func _identity_start() -> void:
	await _perform("/v1/identity/start", {"consent": controls.identity_consent.button_pressed})
	if not identity_url.is_empty():
		OS.shell_open(identity_url)
		identity_url = ""

func _connect_ai() -> void:
	var body := {"key": controls.api_key.text.strip_edges(), "consent": controls.fee_consent.button_pressed, "dailyMax": int(controls.daily_max.value), "model": MODEL}
	controls.api_key.clear()
	await _perform("/v1/ai/connect", body)

func _suggest_name() -> void:
	await _perform("/v1/names/suggest", {"surname": draft.surname, "consent": controls.name_fee.button_pressed})

func _review_name() -> void:
	await _perform("/v1/names/review", {"surname": draft.surname, "given": draft.given, "consent": controls.name_fee.button_pressed})

func _start_demo() -> void:
	await _perform("/v1/demo/start", {})
	if not status_error:
		draft.surname = ""
		draft.given = ""
		draft.entry = "arrival"
		_render()

func _mode_matches(data: Dictionary) -> bool:
	return data.get("mode", "") == "demo" if demo_mode else data.get("mode", "") != "demo"

func _perform(path: String, body: Dictionary) -> void:
	if busy: return
	busy = true
	status_label.text = "正在處理，請稍候…"
	var headers := PackedStringArray(["Content-Type: application/json", "X-Yiyu-Client: native-v1"])
	if not token.is_empty(): headers.append("Authorization: Bearer " + token)
	var error := http.request(service_base + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	body.clear()
	if error != OK:
		busy = false
		status_text = "無法開始連線。請使用「啟動異域」啟動遊戲與帳號服務。"
		status_error = true
		_render()
		return
	var response: Array = await http.request_completed
	busy = false
	var data: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if response[0] != HTTPRequest.RESULT_SUCCESS or not data is Dictionary:
		status_text = "帳號服務無法連線或請求逾時。請確認已使用「啟動異域」；可重試查詢確認狀態。"
		status_error = true
	elif not _mode_matches(data):
		token = ""
		state = {}
		step = 0
		status_text = "服務模式不符，已停止本次操作。請關閉遊戲，使用正確啟動入口。"
		status_error = true
	elif response[1] >= 400:
		status_text = str(data.get("error", {}).get("message", "操作未完成，請稍後再試。"))
		status_error = true
		if response[1] == 401:
			token = ""
			state = {}
			step = 0
		elif not token.is_empty():
			# A provider rejection may have revoked an earlier status on the server.
			busy = true
			if http.request(service_base + "/v1/me", headers, HTTPClient.METHOD_GET) == OK:
				var refreshed: Array = await http.request_completed
				var latest: Variant = JSON.parse_string((refreshed[3] as PackedByteArray).get_string_from_utf8())
				if refreshed[1] == 200 and latest is Dictionary and _mode_matches(latest) and latest.has("state"): state = latest.state
			busy = false
	else:
		status_error = false
		status_text = "已更新。"
		if data.has("token"):
			token = data.token
			step = 1
		if data.has("state"): state = data.state
		if data.has("suggestion"):
			draft.surname = data.suggestion.surname
			draft.given = data.suggestion.given
			status_text = "已產生建議姓名，請點選審核姓名。"
		if data.has("reason"): status_text = ("姓名通過：" if data.get("approved", false) else "姓名未通過：") + str(data.reason)
		if data.has("url"):
			var url := str(data.url)
			if url.begins_with("https://inquiry.withpersona.com/verify?"): identity_url = url
		if path == "/v1/ai/connect": status_text = "智慧服務已連線，現在可以進行取名與審核。"
		if path == "/v1/characters": status_text = "角色已保存。歡迎來到異域。"
		if demo_mode:
			status_text = "測試結果：" + status_text
			if path == "/v1/demo/start": status_text = "已開始新一輪測試。請繼續模擬實名查核。"
			if path == "/v1/demo/identity": status_text = "模擬查核已完成，可前往智慧服務。"
			if path == "/v1/demo/ai": status_text = "模擬智慧服務已啟用，可前往創建角色。"
			if path == "/v1/characters": status_text = "本輪創角測試完成。可按「重新測試」體驗另一種入世方式。"
	_render()

func _show_policy() -> void:
	if not _can_create(): return
	modal = ColorRect.new()
	modal.color = Color(0, 0, 0, 0.72)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(modal)
	var panel := Panel.new()
	panel.position = Vector2(405, 175)
	panel.size = Vector2(790, 530)
	panel.add_theme_stylebox_override("panel", _style(Color("e3d6b8")))
	modal.add_child(panel)
	_label(panel, "入世之前　・　命名規範", Rect2(40, 29, 700, 59), 33, INK, true)
	_label(panel, "角色須使用自然的華語人名，避免惡意網名、\n廣告、辱罵或破壞遊戲沉浸感的稱呼。\n\n若取名破壞沉浸感，官方有權刪除角色；\n惡意再犯可凍結帳號，並將實名身分列入黑名單。\n\n處分由官方依證據人工確認；玩家可提出申覆。\nAI 姓名審核不會自行刪角或封鎖身分。", Rect2(40, 111, 710, 295), 24)
	_button(panel, "policy_cancel", "返回修改", Rect2(40, 438, 280, 57), _close_policy)
	_button(panel, "policy_accept", "我已了解，確認入世", Rect2(349, 438, 400, 57), func():
		_close_policy()
		_perform("/v1/characters", {"entry": draft.entry, "surname": draft.surname, "given": draft.given, "policy": POLICY, "acceptPolicy": true}), true)
	controls.policy_cancel.grab_focus()
	for button in [controls.policy_cancel, controls.policy_accept]:
		var other: Control = controls.policy_accept if button == controls.policy_cancel else controls.policy_cancel
		button.focus_next = button.get_path_to(other)
		button.focus_previous = button.get_path_to(other)
		button.focus_neighbor_left = button.get_path_to(other)
		button.focus_neighbor_right = button.get_path_to(other)
		button.focus_neighbor_top = button.get_path_to(other)
		button.focus_neighbor_bottom = button.get_path_to(other)

func _close_policy() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
		modal = null

func _logout() -> void:
	await _perform("/v1/logout", {})
	token = ""
	state = {}
	draft.surname = ""
	draft.given = ""
	step = 0
	status_text = "已登出。"
	_render()

func _back() -> void:
	if busy: return
	# Secret fields are transient and discarded even when simply returning to title.
	_render()
	back_requested.emit()

func handle_back() -> void:
	if busy: return
	if is_instance_valid(modal): _close_policy()
	else: _back()
