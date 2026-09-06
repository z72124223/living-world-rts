extends Node
## The Rust process owns world state. HTTPRequest runs on a worker thread; this
## node serializes command responses and polling so an old GET cannot roll back UI.

signal snapshot_received(snapshot: Dictionary)
signal command_failed(message: String)

const MAX_QUEUE := 128
var _base_url := ""
var _http: HTTPRequest
var _poll: Timer
var _queue: Array[Dictionary] = []
var _inflight: Dictionary = {}
var _snapshot_pending := false
var _session_id := ""
var _sequence := 0

func _ready() -> void:
	_ensure_client()
	_pump()

func _ensure_client() -> void:
	if is_instance_valid(_http):
		return
	_session_id = Crypto.new().generate_random_bytes(16).hex_encode()
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 4.0
	_http.max_redirects = 0
	_http.body_size_limit = 16 * 1024 * 1024
	add_child(_http)
	_http.request_completed.connect(_on_response)
	_poll = Timer.new()
	_poll.wait_time = 0.2
	add_child(_poll)
	_poll.timeout.connect(request_snapshot)

func connect_world(base_url: String) -> void:
	_ensure_client()
	var validator := RegEx.new()
	validator.compile("^http://127\\.0\\.0\\.1:([0-9]{1,5})/?$")
	var found := validator.search(base_url)
	if found == null or int(found.get_string(1)) < 1 or int(found.get_string(1)) > 65535:
		command_failed.emit("世界服務網址必須是 http://127.0.0.1:連接埠。")
		return
	if not _inflight.is_empty() or not _queue.is_empty():
		command_failed.emit("重新連線已取消等待中的請求；不確定結果的命令可用相同 request_id 重試。")
	_http.cancel_request()
	_queue.clear()
	_inflight.clear()
	_base_url = base_url.trim_suffix("/")
	_snapshot_pending = true
	if is_inside_tree():
		_poll.start()
	call_deferred("_pump")

func send_command(command: Dictionary) -> void:
	_ensure_client()
	if _base_url.is_empty():
		command_failed.emit("尚未連接世界服務。")
		return
	if _queue.size() >= MAX_QUEUE:
		command_failed.emit("等待中的命令過多，請稍後再試。")
		return
	var payload := command.duplicate(true)
	if not payload.has("request_id"):
		_sequence += 1
		payload["request_id"] = "%s-%d" % [_session_id, _sequence]
	_queue.append(payload)
	# HTTPRequest completes cleanup after signal handlers return.
	call_deferred("_pump")

func request_snapshot() -> void:
	if _base_url.is_empty():
		return
	_snapshot_pending = true
	call_deferred("_pump")

func _pump() -> void:
	if not is_inside_tree() or _base_url.is_empty() or not _inflight.is_empty():
		return
	var error: Error
	if not _queue.is_empty():
		var payload: Dictionary = _queue.pop_front()
		_inflight = {"kind": "command", "payload": payload}
		error = _http.request(_base_url + "/command", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(payload))
	elif _snapshot_pending:
		_snapshot_pending = false
		_inflight = {"kind": "snapshot"}
		error = _http.request(_base_url + "/snapshot")
	else:
		return
	if error != OK:
		var failed := _inflight.duplicate(true)
		_inflight.clear()
		_report_failure("無法送出世界請求（%d）。" % error, failed)
		call_deferred("_pump")

func _on_response(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var completed := _inflight.duplicate(true)
	_inflight.clear()
	if result != HTTPRequest.RESULT_SUCCESS:
		_report_failure("世界服務連線失敗（%d）。" % result, completed)
		call_deferred("_pump")
		return
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		_report_failure("世界服務回傳無效 JSON。", completed)
		call_deferred("_pump")
		return
	var response: Dictionary = parser.data
	if status != 200 or response.get("ok", true) == false:
		_report_failure(str(response.get("error", "世界服務錯誤（%d）。" % status)), completed)
	else:
		var snapshot: Variant = response.get("snapshot", {}) if completed.get("kind") == "command" else response
		if snapshot is Dictionary and snapshot.get("schema_version") == 1 and snapshot.get("characters") is Array and snapshot.get("squads") is Array and snapshot.get("events") is Array:
			snapshot_received.emit(snapshot)
		else:
			_report_failure("世界快照格式不相容。", completed)
	call_deferred("_pump")

func _report_failure(message: String, request: Dictionary) -> void:
	if request.get("kind") == "command":
		message += " [request_id=%s]" % str(request.get("payload", {}).get("request_id", ""))
	command_failed.emit(message)

func _exit_tree() -> void:
	if is_instance_valid(_http):
		_http.cancel_request()
