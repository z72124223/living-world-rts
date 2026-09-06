extends Node
## Owns only the world process created by this game instance. Saves belong to Rust.
var world_pid := -1
var game: Node2D
var shutdown_path := ""
var save_directory := ""
var stopping := false
var world_ready := false
var screen := CanvasLayer.new()
var message := Label.new()

func _ready() -> void:
	get_tree().auto_accept_quit=false
	get_tree().root.close_requested.connect(close_game)
	add_child(screen)
	message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	message.add_theme_font_override("font",preload("res://assets/ui-font.otf"))
	message.add_theme_font_size_override("font_size",22)
	screen.add_child(message)
	message.text="正在載入林間營地…"
	start_world()
	if OS.get_cmdline_user_args().has("--verify-bundle"):
		add_child(load("res://prototype/verify_launcher.gd").new())
	elif OS.get_cmdline_user_args().has("--verify-integration"):
		add_child(load("res://prototype/verify_integration.gd").new())

func start_world() -> void:
	var executable := OS.get_executable_path().get_base_dir().path_join("world-prototype.exe")
	if OS.has_feature("editor"):
		executable=ProjectSettings.globalize_path("res://../target/release/world-prototype.exe")
	if not FileAccess.file_exists(executable):
		message.text="缺少世界檔案，請使用完整的遊戲資料夾開啟。"
		return
	save_directory=OS.get_environment("RTS_SAVE_DIRECTORY")
	if save_directory.is_empty():
		save_directory=OS.get_environment("LOCALAPPDATA").path_join("FourPersonPrototype/saves")
	var runtime := save_directory.path_join("runtime")
	if DirAccess.make_dir_recursive_absolute(runtime)!=OK:
		message.text="無法開啟存檔資料夾，請確認資料夾可以寫入。"
		return
	shutdown_path=runtime.path_join("shutdown-%s.signal" % Crypto.new().generate_random_bytes(16).hex_encode())
	world_pid=OS.create_process(executable,PackedStringArray(["--port","8793","--save-dir",save_directory,"--shutdown-file",shutdown_path]),false)
	if world_pid<=0:
		message.text="世界啟動失敗，請重新開啟遊戲。"
		return
	var http := HTTPRequest.new()
	http.timeout=1.0
	http.use_threads=true
	add_child(http)
	for attempt in range(40):
		await get_tree().create_timer(0.15).timeout
		if stopping: return
		if not OS.is_process_running(world_pid):
			message.text="世界無法啟動。\n若遊戲已開啟，請返回原視窗；也請保留現有存檔。"
			http.queue_free()
			return
		if http.request("http://127.0.0.1:8793/snapshot")!=OK: continue
		var reply: Array=await http.request_completed
		if stopping: return
		if reply[0]!=HTTPRequest.RESULT_SUCCESS or reply[1]!=200: continue
		var parsed: Variant=JSON.parse_string(reply[3].get_string_from_utf8())
		if not parsed is Dictionary or parsed.get("schema_version")!=1: continue
		# A second instance exits on bind failure. Recheck before attaching to a world.
		if not OS.is_process_running(world_pid): continue
		http.queue_free()
		game=preload("res://prototype/client/prototype.tscn").instantiate()
		add_child(game)
		message.hide()
		world_ready=true
		return
	http.queue_free()
	message.text="世界尚未完成載入。請關閉遊戲後再試，存檔會保留。"

func close_game() -> void:
	if stopping: return
	stopping=true
	message.text="正在保存進度…"
	message.show()
	if is_instance_valid(game):
		game.hide()
		game.ui.hide()
		game.set_process_input(false)
		game.set_process_unhandled_input(false)
		if is_instance_valid(game.bridge):
			game.bridge._poll.stop()
			var limit := Time.get_ticks_msec()+10000
			while (not game.bridge._queue.is_empty() or not game.bridge._inflight.is_empty()) and Time.get_ticks_msec()<limit:
				await get_tree().create_timer(0.05).timeout
			if not game.bridge._queue.is_empty() or not game.bridge._inflight.is_empty():
				message.text="仍有操作等待完成，請稍候再關閉。"
				stopping=false
				return
	if world_pid>0 and OS.is_process_running(world_pid):
		var signal_file := FileAccess.open(shutdown_path,FileAccess.WRITE)
		if signal_file==null:
			message.text="保存關閉失敗，請保留此視窗與存檔資料夾後再試。"
			stopping=false
			return
		signal_file.store_string("stop")
		signal_file.close()
		var limit := Time.get_ticks_msec()+10000
		while OS.is_process_running(world_pid) and Time.get_ticks_msec()<limit:
			await get_tree().create_timer(0.05).timeout
		if OS.is_process_running(world_pid):
			message.text="世界仍在保存，請稍候再關閉。"
			stopping=false
			return
		if OS.get_process_exit_code(world_pid)!=0:
			message.text="世界保存時發生錯誤，請保留存檔後再試。"
			stopping=false
			world_pid=-1
			return
		DirAccess.remove_absolute(shutdown_path)
	get_tree().quit()
