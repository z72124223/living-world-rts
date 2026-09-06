extends SceneTree
## Run against an isolated world: godot --headless --path godot-client --script res://prototype/bridge/bridge_smoke.gd -- --url=http://127.0.0.1:8793
const Bridge = preload("res://prototype/bridge/world_bridge.gd")
var bridge: Node
var stage := 0
var person_id := ""
var start_x := 0.0
var snapshots := 0
var stop_position := Vector2.ZERO
var ids: Array[String] = []

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	bridge = Bridge.new()
	root.add_child(bridge)
	bridge.snapshot_received.connect(_snapshot)
	bridge.command_failed.connect(_failed)
	var url := "http://127.0.0.1:8793"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--url="):
			url = argument.trim_prefix("--url=")
	bridge.connect_world(url)
	create_timer(15.0).timeout.connect(func() -> void: _abort("bridge smoke timeout"))

func _snapshot(snapshot: Dictionary) -> void:
	snapshots += 1
	var people: Array = snapshot["characters"]
	if people.size() != 4:
		_abort("expected four real characters")
		return
	var person: Dictionary = people[0]
	var position_value: Array = person["position"]
	match stage:
		0:
			for p in people:
				ids.append(str(p["id"]))
			person_id = str(person["id"])
			start_x = float(position_value[0])
			stage = 1
			bridge.send_command({"type": "set_equipment", "character_id": person_id, "loadout": {"clothing": "cloth", "armor": "chest", "weapon": "sword"}})
		1:
			if person["loadout"]["weapon"] == "sword":
				stage = 2
				bridge.send_command({"type": "move", "routes": [{"character_id": person_id, "points": [[start_x + 64.0, position_value[1]]]}], "pace": "run"})
		2:
			if float(position_value[0]) > start_x + 5.0:
				stage = 3
				bridge.send_command({"type": "stop", "character_ids": [person_id]})
		3:
			if Vector2(person["velocity"][0], person["velocity"][1]).is_zero_approx():
				stop_position = Vector2(position_value[0], position_value[1])
				stage = 4
				bridge.send_command({"type": "save", "slot": "slot-1"})
		4:
			stage = 5
			bridge.send_command({"type": "load", "slot": "slot-1"})
		5:
			if Vector2(position_value[0], position_value[1]) != stop_position:
				_abort("saved position changed")
				return
			for i in range(4):
				if str(people[i]["id"]) != ids[i]:
					_abort("identity changed")
					return
			stage = 6
			bridge.send_command({"type": "stop", "character_ids": ["missing-person"]})

func _failed(message: String) -> void:
	if stage == 6 and message.contains("unknown character"):
		print("BRIDGE_SMOKE_PASS snapshots=%d ids=%s equipment=chest/sword movement=verified stop=verified save_load=verified error_signal=verified" % [snapshots, str(ids)])
		quit(0)
	else:
		_abort(message)

func _abort(message: String) -> void:
	push_error("BRIDGE_SMOKE_FAIL " + message)
	quit(1)
