extends SceneTree
## Component checks only: headless, no HTTP, no rendered-frame or real-login claim.
var results: Array[Dictionary] = []
var screen: Control

func record(value: bool, description: String) -> void:
	results.append({"check": description, "passed": value})

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	screen = load("res://registration/registration.gd").new()
	root.add_child(screen)
	# Explicit component fixtures, never authoritative account or provider data.
	for mode in [false, true]:
		screen.demo_mode = mode
		screen.state = {}
		screen.token = ""
		screen.step = 0
		screen._render()
		record(screen.controls.has("demo_start") == mode, "demo start appears only in demo: " + str(mode))
		record(screen.controls.has("password") != mode, "real password absent in demo: " + str(mode))
		record(not screen._mode_matches({"mode": "production" if mode else "demo"}), "reject opposite service mode: " + str(mode))
		screen.step = 2
		screen._render()
		record(screen.controls.has("api_key") != mode, "real key absent in demo: " + str(mode))
		if not mode:
			screen.state = {"identity": "verified", "aiConnected": false, "hasKey": true}
			screen._render()
			var truthful_hint := false
			for node in screen.form.get_children():
				if node is Label and node.text.contains("尚未連線或驗證已失效"): truthful_hint = true
			record(truthful_hint, "saved key does not display connected after failed verification")
		screen.state = {"identity": "verified", "sex": "F", "aiConnected": true, "hasKey": false, "availableChildren": 0}
		screen.token = "component-fixture-only"
		screen.step = 3
		screen._render()
		record(screen.controls.suggest_name.disabled != mode, "demo suggestion works without a key; production requires a key: " + str(mode))
		record(screen.controls.reincarnation.disabled, "empty child pool remains disabled: " + str(mode))
		record(screen.controls.create_character.disabled, "unreviewed name remains disabled: " + str(mode))
		record(not screen.controls.has("gender") and not screen.controls.has("appearance"), "no mutable gender or appearance: " + str(mode))
		screen.draft.surname = "歐陽"
		screen.draft.given = "映禾"
		screen.state.review = {"approved": true, "surname": "歐陽", "given": "映禾"}
		record(screen._can_create(), "exact compound-name review permits client action: " + str(mode))
		screen.draft.given = "若川"
		record(not screen._can_create(), "changed name invalidates client action: " + str(mode))
		screen.state.availableChildren = 1
		screen.draft.entry = "reincarnation"
		screen._render()
		record(not screen.controls.has("surname") and not screen.controls.has("given") and not screen.controls.has("name_fee"), "child cannot be renamed or incur unnecessary naming request: " + str(mode))
		record(screen._can_create(), "eligible child permits client action: " + str(mode))
		screen.state.identity = "unverified"
		record(not screen._can_create(), "identity revocation blocks client action: " + str(mode))
		screen.draft.entry = "arrival"
		screen.draft.surname = ""
		screen.draft.given = ""
	check_portrait_inheritance()
	var passed := results.all(func(item: Dictionary): return item.passed)
	var report := {"passed": passed, "checks": results, "type": "headless component fixtures", "http_executed": false, "visual_verified": false, "real_identity_or_ai": false}
	var destination := OS.get_environment("YIYU_UI_COMPONENT_REPORT")
	if not destination.is_empty():
		var file := FileAccess.open(destination, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if passed else 1)

func check_portrait_inheritance() -> void:
	var catalog = load("res://registration/appearance_catalog.gd")
	var child_texture: Texture2D = catalog.resolve("settlement-female-01", "F")
	record(child_texture != null and child_texture != catalog.resolve("arrival-female", "F"), "child has a distinct bundled portrait")
	for invalid in ["", "unknown-child", "res://registration/assets/arrival-female.png", "../login/login.gd", "https://example.invalid/portrait.png", null, 123, {"path": "arrival-female"}]:
		record(catalog.resolve(invalid, "F") == null, "unrecognized ID is never loaded as a resource: " + str(invalid))
	for mode in [false, true]:
		screen.demo_mode = mode
		screen.step = 3
		screen.state = {"identity": "verified", "sex": "F", "aiConnected": true, "availableChildren": 2}
		screen.draft.entry = "arrival"
		screen._render()
		record(screen.controls.portrait_image.texture == catalog.resolve("arrival-female", "F"), "arrival retains modern clothing: " + str(mode))
		screen.draft.entry = "reincarnation"
		screen._render()
		record(screen.controls.portrait_image.texture == null and screen.controls.portrait_caption.text.contains("配對後"), "no child preview before random pairing: " + str(mode))
		screen.state.character = {"id": "fixture-child", "surname": "林", "given": "知遠", "sex": "F", "appearance": "settlement-female-01", "entry": "reincarnation", "state": "active"}
		# A newly logged-in client has the arrival draft, but the server already owns this child.
		screen.draft.entry = "arrival"
		screen._render()
		record(screen.controls.portrait_image.texture == child_texture and screen.controls.portrait_caption.text.contains("沿用子女"), "saved child wins over a new arrival draft: " + str(mode))
		screen.state = JSON.parse_string(JSON.stringify(screen.state))
		screen.step = 1
		screen._render()
		record(screen.controls.portrait_image.texture == child_texture, "refreshed account and another tab retain child appearance: " + str(mode))
		screen.state.character.appearance = "res://registration/assets/arrival-female.png"
		screen._render()
		record(screen.controls.portrait_image.texture == null and screen.controls.portrait_caption.text.contains("暫無法顯示"), "missing child asset does not fall back to another person: " + str(mode))
		screen.state.character.appearance = "settlement-female-01"
		screen.state.character.sex = "M"
		screen._render()
		record(screen.controls.portrait_image.texture == null, "inconsistent registered sex and portrait are not displayed: " + str(mode))
		screen.state.sex = "M"
		screen.state.character.appearance = "arrival-male"
		screen._render()
		record(screen.controls.portrait_image.texture == catalog.resolve("arrival-male", "M") and screen.controls.portrait_caption.text.contains("沿用子女"), "male child also resolves its stored appearance: " + str(mode))
		screen.state.character.state = "deleted"
		screen._render()
		record(screen.controls.portrait_image.texture == null and screen.controls.portrait_caption.text == "角色已停用", "deleted child portrait is not shown as active: " + str(mode))
		record(not screen.controls.has("appearance") and not screen.controls.has("gender"), "inheritance never adds a customization selector: " + str(mode))
