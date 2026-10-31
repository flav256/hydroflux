extends Node2D
class_name ElasticTendril

## Elastic membrane. The curve is a solid surface: drops rest on it,
## follow it while it is pulled, and are thrown when it snaps back.

signal tendril_stretched(displacement: Vector2, ratio: float)
signal tendril_released(impulse_vector: Vector2)
signal droplet_launched(droplet: Node, velocity: Vector2)

@export_group("Anchors & Geometry")
@export var anchor_left: Vector2 = Vector2(-140.0, 0.0)
@export var anchor_right: Vector2 = Vector2(140.0, 0.0)
@export var rest_sag: float = 26.0
@export var grab_radius: float = 36.0
@export var max_stretch_distance: float = 135.0
@export var membrane_radius: float = 14.0

@export_group("Elastic Physics")
@export var spring_stiffness: float = 180.0
@export var damping: float = 14.0
@export var launch_force_multiplier: float = 8.5
@export var min_release_impulse: float = 120.0

@export_group("Visuals & Glow")
@export var tendril_color: Color = Color(0.75, 0.95, 1.0, 0.9)
@export var tension_glow_color: Color = Color(0.35, 0.9, 0.95, 1.0)
@export var curve_segments: int = 28

var rest_midpoint: Vector2 = Vector2.ZERO
var current_midpoint: Vector2 = Vector2.ZERO
var midpoint_velocity: Vector2 = Vector2.ZERO
var is_dragged: bool = false
var active_touch_index: int = -1
var grab_offset: Vector2 = Vector2.ZERO

var curve_points: PackedVector2Array = PackedVector2Array()
var prev_curve_points: PackedVector2Array = PackedVector2Array()
var seated_drops: Array[FluidDroplet] = []

@onready var line_2d: Line2D = get_node_or_null("Line2D")
@onready var snap_audio: AudioStreamPlayer2D = get_node_or_null("SnapAudio")


func _ready() -> void:
	# Run after rigid bodies so the membrane can catch them the same frame.
	get_tree().physics_frame.connect(_on_physics_frame)
	rest_midpoint = (anchor_left + anchor_right) * 0.5 + Vector2(0.0, rest_sag)
	current_midpoint = rest_midpoint
	_rebuild_curve()
	update_visual_curve()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var local_pos := InputManager.event_local_position(touch, self)
		if touch.pressed:
			if not is_dragged and _distance_to_curve(local_pos) <= grab_radius:
				_begin_drag(local_pos, touch.index)
		elif is_dragged and touch.index == active_touch_index:
			_release_tendril()
	elif event is InputEventScreenDrag and is_dragged:
		var drag := event as InputEventScreenDrag
		if drag.index == active_touch_index:
			_handle_drag(InputManager.event_local_position(drag, self) + grab_offset)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		var local_mouse := InputManager.event_local_position(mouse, self)
		if mouse.pressed:
			if _distance_to_curve(local_mouse) <= grab_radius:
				_begin_drag(local_mouse, 0)
		elif is_dragged:
			_release_tendril()
	elif event is InputEventMouseMotion and is_dragged:
		_handle_drag(InputManager.event_local_position(event, self) + grab_offset)


func _begin_drag(local_pos: Vector2, touch_index: int) -> void:
	is_dragged = true
	active_touch_index = touch_index
	grab_offset = current_midpoint - local_pos
	_handle_drag(local_pos + grab_offset)


func _handle_drag(target_pos: Vector2) -> void:
	var offset := target_pos - rest_midpoint
	if offset.length() > max_stretch_distance:
		offset = offset.normalized() * max_stretch_distance
	current_midpoint = rest_midpoint + offset
	midpoint_velocity = Vector2.ZERO
	var ratio := clampf(offset.length() / max_stretch_distance, 0.0, 1.0)
	tendril_stretched.emit(offset, ratio)
	_rebuild_curve()
	update_visual_curve()
	queue_redraw()


func _release_tendril() -> void:
	is_dragged = false
	active_touch_index = -1
	var displacement := current_midpoint - rest_midpoint
	var stretch_dist := displacement.length()
	if stretch_dist <= 6.0:
		return
	var impulse_direction := -displacement.normalized()
	var impulse_magnitude := maxf(stretch_dist * launch_force_multiplier, min_release_impulse)
	var impulse_vector := impulse_direction * impulse_magnitude
	midpoint_velocity = impulse_vector * 0.35
	if snap_audio:
		snap_audio.pitch_scale = randf_range(0.95, 1.08)
		snap_audio.play()
	AudioController.play_tendril_snap()
	tendril_released.emit(impulse_vector)
	for drop in _drops_on_membrane():
		drop.ignore_membrane(0.45)
		drop.apply_launch_impulse(impulse_vector)
		droplet_launched.emit(drop, impulse_vector)


func _physics_process(delta: float) -> void:
	prev_curve_points = curve_points.duplicate()
	if not is_dragged:
		var displacement := current_midpoint - rest_midpoint
		var spring_force := -spring_stiffness * displacement
		var damping_force := -damping * midpoint_velocity
		midpoint_velocity += (spring_force + damping_force) * delta
		current_midpoint += midpoint_velocity * delta
		if displacement.length() < 0.35 and midpoint_velocity.length() < 8.0:
			current_midpoint = rest_midpoint
			midpoint_velocity = Vector2.ZERO
	_rebuild_curve()
	update_visual_curve()
	queue_redraw()


func _on_physics_frame() -> void:
	_support_droplets()


func _rebuild_curve() -> void:
	var points := PackedVector2Array()
	for i in range(curve_segments + 1):
		var t := float(i) / float(curve_segments)
		points.append(_sample_quadratic_bezier(anchor_left, current_midpoint, anchor_right, t))
	curve_points = points


func update_visual_curve() -> void:
	if line_2d == null or curve_points.is_empty():
		return
	line_2d.points = curve_points
	var stretch_ratio := (current_midpoint - rest_midpoint).length() / max_stretch_distance
	line_2d.width = lerpf(2.2, 1.4, stretch_ratio)
	line_2d.default_color = tendril_color.lerp(tension_glow_color, stretch_ratio * 0.85)


func _draw() -> void:
	if curve_points.size() < 2:
		return
	var stretch_ratio := (current_midpoint - rest_midpoint).length() / max_stretch_distance
	draw_polyline(curve_points, Color(0.02, 0.04, 0.05, 0.55), membrane_radius * 2.6, true)
	draw_polyline(curve_points, Color(0, 0, 0, 1), membrane_radius * 1.7, true)
	draw_circle(anchor_left, 7.0, Color(0, 0, 0, 1))
	draw_circle(anchor_right, 7.0, Color(0, 0, 0, 1))
	if is_dragged:
		var glow := Color(tension_glow_color, 0.35 + stretch_ratio * 0.4)
		draw_circle(current_midpoint, 10.0, glow)


func _sample_quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return (u * u * p0) + (2.0 * u * t * p1) + (t * t * p2)


func _distance_to_curve(local_point: Vector2) -> float:
	if curve_points.size() < 2:
		return INF
	return float(_closest_on_curve(local_point, curve_points).dist)


func _support_droplets() -> void:
	var next: Array[FluidDroplet] = []
	if curve_points.size() < 2:
		seated_drops = next
		return
	for node in get_tree().get_nodes_in_group("fluid_droplet"):
		var drop := node as FluidDroplet
		if drop == null or drop.is_absorbed or drop.is_forming or drop.freeze:
			continue
		if drop.membrane_cooldown > 0.0:
			continue
		var local := to_local(drop.global_position)
		var hit: Dictionary = _closest_on_curve(local, curve_points)
		var normal := _upward_normal(int(hit.index))
		var side := (local - (hit.point as Vector2)).dot(normal)
		var limit := membrane_radius + drop.base_radius
		var already := seated_drops.has(drop)
		var catching := side <= limit + 22.0 and side >= -10.0 and float(hit.dist) < limit + 30.0
		if not already and not catching:
			continue
		# Always sit on the upper side. A center that slips past the line used to get pushed downward.
		drop.global_position = to_global((hit.point as Vector2) + normal * limit)
		drop.linear_velocity = Vector2.ZERO
		next.append(drop)
	seated_drops = next


func _upward_normal(index: int) -> Vector2:
	var i := clampi(index, 0, curve_points.size() - 2)
	var tangent: Vector2 = curve_points[i + 1] - curve_points[i]
	if tangent.length() < 0.001:
		return Vector2.UP
	var normal := Vector2(-tangent.y, tangent.x).normalized()
	if normal.dot(Vector2.UP) < 0.0:
		normal = -normal
	return normal


func _drops_on_membrane() -> Array[FluidDroplet]:
	var found: Array[FluidDroplet] = []
	for node in get_tree().get_nodes_in_group("fluid_droplet"):
		var drop := node as FluidDroplet
		if drop == null or drop.is_absorbed or drop.is_forming:
			continue
		var local := to_local(drop.global_position)
		var hit: Dictionary = _closest_on_curve(local, curve_points)
		if float(hit.dist) <= membrane_radius + drop.base_radius + 8.0:
			found.append(drop)
	return found


func _closest_on_curve(local_point: Vector2, points: PackedVector2Array) -> Dictionary:
	var best_dist_sq := INF
	var best_point := points[0]
	var best_index := 0
	var best_t := 0.0
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var ab := b - a
		var denom := ab.length_squared()
		var t := 0.0
		if denom > 0.0001:
			t = clampf((local_point - a).dot(ab) / denom, 0.0, 1.0)
		var point := a.lerp(b, t)
		var dist_sq := local_point.distance_squared_to(point)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_point = point
			best_index = i
			best_t = t
	return {
		"point": best_point,
		"index": best_index,
		"t": best_t,
		"dist": sqrt(best_dist_sq),
	}


func _point_on_segment(points: PackedVector2Array, index: int, t: float) -> Vector2:
	var i := clampi(index, 0, points.size() - 2)
	return (points[i] as Vector2).lerp(points[i + 1], t)
