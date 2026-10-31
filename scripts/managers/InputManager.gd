extends Node

## Converts viewport touch/mouse into world-space points for physics objects.

var world_pointer: Vector2 = Vector2.ZERO
var has_pointer: bool = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_track_pointer(event)
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		_track_pointer(event)


func _track_pointer(event: InputEvent) -> void:
	var scene := get_tree().current_scene as CanvasItem
	if scene == null:
		return
	world_pointer = event_world_position(event, scene)
	has_pointer = true

func event_world_position(event: InputEvent, from: CanvasItem) -> Vector2:
	var viewport_pos := Vector2.ZERO
	if event is InputEventMouse:
		viewport_pos = (event as InputEventMouse).position
	elif event is InputEventScreenTouch:
		viewport_pos = (event as InputEventScreenTouch).position
	elif event is InputEventScreenDrag:
		viewport_pos = (event as InputEventScreenDrag).position
	else:
		viewport_pos = from.get_viewport().get_mouse_position()
	return from.get_canvas_transform().affine_inverse() * viewport_pos


func event_local_position(event: InputEvent, from: Node2D) -> Vector2:
	return from.to_local(event_world_position(event, from))
