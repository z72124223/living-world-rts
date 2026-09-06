extends Node
## Deliberately separate, volatile demonstration. Never used as formal save storage.
signal snapshot_received(snapshot: Dictionary)
signal command_failed(message: String)
var state: Dictionary = {}
var routes: Dictionary = {}
var speeds: Dictionary = {}
var elapsed := 0.0
var next_squad := 2

func connect_world(_base_url: String) -> void:
	state = {"schema_version": 1, "revision": 1, "sim_time_ms": 0, "characters": [], "squads": [{"id":"squad-1","name":"營地小隊","member_ids":["1","2","3","4"],"commander_id":"1"}], "events": []}
	var names := ["沈青", "陸衡", "林霽", "周野"]
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://prototype/map/map_config.json"))
	var positions: Array = config.spawn_positions
	for i in range(4):
		state.characters.append({"id":str(i+1),"name":names[i],"gender":"female" if i%2==0 else "male","position":positions[i],"velocity":[0,0],"loadout":{"clothing":"cloth","armor":"none","weapon":"none"},"squad_id":"squad-1"})
	_event("獨立演示：四人在營地待命。資料只留在記憶體。")
	request_snapshot()

func request_snapshot() -> void:
	snapshot_received.emit(state.duplicate(true))

func _event(message: String) -> void:
	state.events.append({"id":"demo-%d" % (state.events.size()+1),"sim_time_ms":state.sim_time_ms,"text":message})

func _process(delta: float) -> void:
	if state.is_empty(): return
	state.sim_time_ms += int(delta * 1000)
	for person in state.characters:
		var id: String = person.id
		var velocity := Vector2.ZERO
		if routes.has(id) and not routes[id].is_empty():
			var p := Vector2(person.position[0], person.position[1])
			var budget: float = speeds[id] * delta
			while budget > 0 and not routes[id].is_empty():
				var point: Array = routes[id][0]
				var target := Vector2(point[0], point[1])
				var distance := p.distance_to(target)
				velocity = p.direction_to(target) * speeds[id]
				if distance <= budget:
					p = target
					budget -= distance
					routes[id].pop_front()
				else:
					p = p.move_toward(target, budget)
					budget = 0
			person.position = [p.x, p.y]
			if routes[id].is_empty(): velocity = Vector2.ZERO
		person.velocity = [velocity.x, velocity.y]
		elapsed += delta / 4.0
	if elapsed >= 0.05:
		elapsed = 0
		state.revision += 1
		request_snapshot()

func send_command(command: Dictionary) -> void:
	match str(command.type):
		"move":
			for route in command.routes:
				routes[str(route.character_id)] = route.points.duplicate(true)
				speeds[str(route.character_id)] = 56.0 if command.get("pace","walk") == "run" else 32.0
		"stop":
			for id in command.character_ids: routes.erase(str(id))
		"split":
			if command.character_ids.is_empty() or command.character_ids.size() == state.characters.size():
				command_failed.emit("請選取部分隊員再分隊。")
				return
			var id := "squad-%d" % next_squad
			next_squad += 1
			for squad in state.squads:
				for member in command.character_ids: squad.member_ids.erase(member)
				if not squad.member_ids.is_empty(): squad.commander_id = squad.member_ids[0]
			state.squads = state.squads.filter(func(s): return not s.member_ids.is_empty())
			state.squads.append({"id":id,"name":command.name,"member_ids":command.character_ids.duplicate(),"commander_id":command.character_ids[0]})
			for person in state.characters:
				if command.character_ids.has(person.id): person.squad_id = id
			_event("已分隊，人物身分保持不變。")
		"merge":
			var target: Dictionary = {}
			var source: Dictionary = {}
			for squad in state.squads:
				if squad.id == command.target_squad_id: target = squad
				if squad.id == command.source_squad_id: source = squad
			if target.is_empty() or source.is_empty() or target.id == source.id:
				command_failed.emit("無法合流：請選擇兩個不同隊伍。")
				return
			target.member_ids.append_array(source.member_ids)
			for person in state.characters:
				if person.squad_id == source.id: person.squad_id = target.id
			state.squads.erase(source)
			_event("隊伍已合流。")
		"set_equipment":
			for person in state.characters:
				if person.id == command.character_id: person.loadout = command.loadout.duplicate(true)
		"interact":
			var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://prototype/map/map_config.json"))
			var at: Array = config.event_positions.get(command.event_key,[-1000,-1000])
			var valid := false
			for person in state.characters:
				if person.id==command.character_id and Vector2(person.position[0],person.position[1]).distance_to(Vector2(at[0],at[1]))<=64: valid=true
			if not valid:
				command_failed.emit("需到達事件點 64 像素內才能觀察。")
				return
			for existing in state.events:
				if existing.get("event_key", "")==command.event_key and command.event_key!="return-camp":
					command_failed.emit("此處已完成觀察。")
					return
			var descriptions := {"scout-north":"北方探路：看見舊路標與倒木，尚未確認更遠處。","scout-east":"東方探路：溪岸留有足跡，沒有看見來者。","return-camp":"已返回營地，記錄本次觀察。"}
			_event(descriptions.get(command.event_key,"此處沒有可觀察事件。"))
			state.events[-1]["event_key"]=command.event_key
		"save", "load":
			command_failed.emit("演示模式不提供正式存讀檔；請接上 Rust 核心。")
			return
	state.revision += 1
	request_snapshot()
