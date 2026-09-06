extends Control
signal location_pressed(world_position: Vector2)
var snapshot: Dictionary = {}
var camera_position := Vector2.ZERO
var camera_extent := Vector2(1000, 700)
var obstacles: Array[Rect2] = []
var event_positions: Dictionary = {}

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		location_pressed.emit(event.position / size * Vector2(2048, 1536))
		accept_event()

func _draw() -> void:
	var ratio := size / Vector2(2048, 1536)
	draw_rect(Rect2(Vector2.ZERO, size), Color("354b3b"))
	for rect in obstacles: draw_rect(Rect2(rect.position * ratio, rect.size * ratio), Color("899078"))
	for p in event_positions.values(): draw_circle(p * ratio, 3, Color("d6b968"))
	for person in snapshot.get("characters",[]):
		var p := Vector2(person.position[0],person.position[1])
		draw_circle(p * ratio, 3, Color("eae9d2"))
	var view := Rect2((camera_position-camera_extent/2) * ratio,camera_extent * ratio)
	draw_rect(view, Color("d6b968"), false, 1)
	draw_rect(Rect2(Vector2.ZERO, size), Color("748373"), false, 1)
