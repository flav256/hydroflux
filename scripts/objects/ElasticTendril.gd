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
@export var grab_radius: float = 52.0
@export var max_stretch_distance: float = 135.0
@export var membrane_radius: float = 14.0
@export var show_flight_path: bool = false

@export_group("Elastic Physics")
@export var spring_stiffness: float = 180.0
@export var damping: float = 14.0
@export var launch_force_multiplier: float = 4.3
@export var min_release_impulse: float = 120.0

@export_group("Soft Catch")
## Midpoint speed gained per unit of the landing drop's speed (momentum handed to the vine).
@export var catch_give: float = 1.0
## Cap on the speed (px/s) handed over, so a long fall cannot bottom the vine out.
@export var catch_max_speed: float = 700.0
## Damping used instead of `damping` while a drop is seated: lighter, so the catch
## gives one or two soft bounces, but still settles in under a second.
@export var seated_damping: float = 12.0
## Seated load (px of extra sag) for a drop of radius 12; scales with sqrt(base_radius / 12).
@export var seat_load: float = 46.0

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
var seated_drops: Array[Gloop] = []
var seat_u: Dictionary = {}
var seat_speed: Dictionary = {}
var drop_is_seated: bool = false
var drop_radius: float = 12.0  # last seen drop base_radius; used where no drop is at hand

@onready var line_2d: Line2D = get_node_or_null("Line2D")
@onready var snap_audio: AudioStreamPlayer2D = get_node_or_null("SnapAudio")


func _ready() -> void:
	# Run after rigid bodies so the membrane can catch them the same frame.
	add_to_group("membrane")
	get_tree().physics_frame.connect(_on_physics_frame)
	z_index = 5
	rest_midpoint = (anchor_left + anchor_right) * 0.5 + Vector2(0.0, rest_sag)
	current_midpoint = rest_midpoint
	if line_2d:
		line_2d.visible = false
	_rebuild_curve()
	update_visual_curve()


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null and tree.physics_frame.is_connected(_on_physics_frame):
		tree.physics_frame.disconnect(_on_physics_frame)


func _input(event: InputEvent) -> void:
	# Listen before GUI controls. The cavern ColorRect used to swallow the click.
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		var local_mouse := InputManager.event_local_position(mouse, self)
		if mouse.pressed:
			if _distance_to_curve(local_mouse) <= grab_radius:
				_begin_drag(local_mouse, -1)
				get_viewport().set_input_as_handled()
		elif is_dragged and active_touch_index == -1:
			_release_tendril()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_dragged and active_touch_index == -1:
		_handle_drag(InputManager.event_local_position(event, self))
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var local_pos := InputManager.event_local_position(touch, self)
		if touch.pressed:
			if not is_dragged and _distance_to_curve(local_pos) <= grab_radius:
				_begin_drag(local_pos, touch.index)
				get_viewport().set_input_as_handled()
		elif is_dragged and touch.index == active_touch_index:
			_release_tendril()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and is_dragged:
		var drag := event as InputEventScreenDrag
		if drag.index == active_touch_index:
			_handle_drag(InputManager.event_local_position(drag, self))
			get_viewport().set_input_as_handled()


func _begin_drag(local_pos: Vector2, touch_index: int) -> void:
	is_dragged = true
	active_touch_index = touch_index
	grab_offset = Vector2.ZERO
	_handle_drag(local_pos)


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
	_support_droplets(1.0 / 60.0)
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
	var launched: Array[Gloop] = []
	for drop in seated_drops:
		if is_instance_valid(drop) and not drop.is_absorbed:
			launched.append(drop)
	for drop in _drops_on_membrane():
		if not launched.has(drop):
			launched.append(drop)
	seated_drops.clear()
	seat_u.clear()
	seat_speed.clear()
	drop_is_seated = false
	for drop in launched:
		drop.ignore_membrane(0.45)
		drop.apply_launch_impulse(impulse_vector)
		droplet_launched.emit(drop, impulse_vector)


func _physics_process(delta: float) -> void:
	prev_curve_points = curve_points.duplicate()
	if not is_dragged:
		var load := Vector2(0.0, seat_load * sqrt(drop_radius / 12.0)) if drop_is_seated else Vector2.ZERO
		var target := rest_midpoint + load
		var displacement := current_midpoint - target
		var spring_force := -spring_stiffness * displacement
		var c := seated_damping if drop_is_seated else damping
		var damping_force := -c * midpoint_velocity
		midpoint_velocity += (spring_force + damping_force) * delta
		current_midpoint += midpoint_velocity * delta
		var dip := current_midpoint - rest_midpoint
		if dip.length() > max_stretch_distance:
			current_midpoint = rest_midpoint + dip.normalized() * max_stretch_distance
			midpoint_velocity = Vector2.ZERO
		if displacement.length() < 0.35 and midpoint_velocity.length() < 8.0:
			current_midpoint = target
			midpoint_velocity = Vector2.ZERO
	_rebuild_curve()
	update_visual_curve()
	queue_redraw()


func _on_physics_frame() -> void:
	_support_droplets(get_physics_process_delta_time())


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
	draw_polyline(curve_points, Color(0, 0, 0, 1), membrane_radius * 1.7, true)
	if is_dragged:
		var pulse := (sin(Time.get_ticks_msec() * 0.004) + 1.0) * 0.5
		var tension_alpha := 0.16 + stretch_ratio * 0.24 + pulse * 0.04
		draw_polyline(
			curve_points,
			Color(tension_glow_color, tension_alpha),
			lerpf(4.0, 7.0, stretch_ratio),
			true
		)
	_draw_dashed(curve_points, Color(0.75, 0.96, 1, 0.95), 2.4, 3)
	draw_circle(anchor_left, 7.0, Color(0, 0, 0, 1))
	draw_circle(anchor_right, 7.0, Color(0, 0, 0, 1))
	if is_dragged:
		var glow := Color(tension_glow_color, 0.45 + stretch_ratio * 0.4)
		draw_circle(current_midpoint, 8.0, glow)
		draw_circle(current_midpoint, 16.0, Color(glow, 0.28))
		if show_flight_path:
			_draw_flight_dots()


func _sample_quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return (u * u * p0) + (2.0 * u * t * p1) + (t * t * p2)


func _bezier(u: float) -> Vector2:
	return _sample_quadratic_bezier(anchor_left, current_midpoint, anchor_right, clampf(u, 0.0, 1.0))


func _bezier_up(u: float) -> Vector2:
	var a := _bezier(u - 0.012)
	var b := _bezier(u + 0.012)
	var tangent := b - a
	if tangent.length() < 0.001:
		return Vector2.UP
	var normal := Vector2(-tangent.y, tangent.x).normalized()
	if normal.dot(Vector2.UP) < 0.0:
		normal = -normal
	return normal


func _closest_bezier_u(local_point: Vector2) -> float:
	var best_u := 0.5
	var best_dist := INF
	for i in range(25):
		var u := float(i) / 24.0
		var dist := local_point.distance_squared_to(_bezier(u))
		if dist < best_dist:
			best_dist = dist
			best_u = u
	return best_u


func _slide_downhill(u: float, dt: float) -> float:
	var step := 0.04
	var y0 := _bezier(u).y
	var y_right := _bezier(clampf(u + step, 0.0, 1.0)).y
	var y_left := _bezier(clampf(u - step, 0.0, 1.0)).y
	var dir := 0.0
	if y_right > y_left and y_right > y0:
		dir = 1.0
	elif y_left > y0:
		dir = -1.0
	if dir == 0.0:
		return u
	var slope := maxf(y_right, y_left) - y0
	var speed := clampf(0.7 + slope * 0.09, 0.7, 2.4)
	return clampf(u + dir * speed * dt, 0.04, 0.96)


func _draw_dashed(points: PackedVector2Array, color: Color, width: float, stride: int) -> void:
	var step := maxi(stride, 2)
	for i in range(0, points.size() - 1, step):
		var end := mini(i + 1, points.size() - 1)
		draw_line(points[i], points[end], color, width, true)
		draw_circle(points[i], width * 0.65, color)


func _draw_flight_dots() -> void:
	var displacement := current_midpoint - rest_midpoint
	if displacement.length() <= 6.0:
		return
	var start := to_global(current_midpoint)
	var mass := 0.65
	var fall_scale := 1.45
	if not seated_drops.is_empty() and is_instance_valid(seated_drops[0]):
		start = seated_drops[0].global_position
		mass = maxf(seated_drops[0].mass, 0.05)
		fall_scale = seated_drops[0].gravity_scale
	var impulse := -displacement.normalized() * maxf(displacement.length() * launch_force_multiplier, min_release_impulse)
	var velocity := impulse / mass
	var gravity_y := float(ProjectSettings.get_setting("physics/2d/default_gravity")) * fall_scale
	var gravity := Vector2(0.0, gravity_y)
	var previous := to_local(start)
	for i in 16:
		var t := float(i + 1) * 0.065
		var world := start + velocity * t + 0.5 * gravity * t * t
		var local := to_local(world)
		if i % 2 == 0:
			draw_line(previous, local, Color(0.55, 0.95, 1.0, 0.75), 2.4, true)
		draw_circle(local, 2.6, Color(0.75, 0.98, 1.0, 0.9))
		previous = local


func _distance_to_curve(local_point: Vector2) -> float:
	if curve_points.size() < 2:
		return INF
	return float(_closest_on_curve(local_point, curve_points).dist)


func _support_droplets(dt: float) -> void:
	var kept: Array[Gloop] = []
	var kept_u: Dictionary = {}
	var kept_speed: Dictionary = {}
	if curve_points.size() < 2:
		seated_drops.clear()
		seat_u.clear()
		seat_speed.clear()
		drop_is_seated = false
		return
	var gravity := Vector2(0.0, float(ProjectSettings.get_setting("physics/2d/default_gravity")))
	for node in get_tree().get_nodes_in_group("gloop"):
		var drop := node as Gloop
		if drop == null or drop.is_absorbed or drop.is_forming or drop.freeze:
			continue
		if drop.membrane_cooldown > 0.0:
			continue
		var id := drop.get_instance_id()
		var local := to_local(drop.global_position)
		var closest := _closest_bezier_u(local)
		var rscale := drop.base_radius / 12.0
		drop_radius = drop.base_radius
		var limit := membrane_radius + drop.base_radius
		var already: bool = seat_u.has(id)
		var prev := to_local(drop.previous_position)
		var fell_through := _fell_onto_curve(prev, local, drop.base_radius)
		if not already and not fell_through and local.distance_to(_bezier(closest)) > limit + 36.0 * rscale:
			continue
		var u := closest if not already else float(seat_u[id])
		var tangent := _bezier(clampf(u + 0.02, 0.0, 1.0)) - _bezier(clampf(u - 0.02, 0.0, 1.0))
		var span := maxf(tangent.length() / 0.04, 40.0)
		if tangent.length() < 0.001:
			tangent = Vector2.RIGHT
		else:
			tangent = tangent.normalized()
		var speed := 0.0 if not already else float(seat_speed.get(id, 0.0))
		var impact := 0.0
		if not already:
			var falling := drop.linear_velocity.y > 30.0 or fell_through
			speed = 0.0 if falling else drop.linear_velocity.dot(tangent) * 0.25
			impact = drop.linear_velocity.length()
			if not is_dragged:
				# Soft catch: the vine takes the drop's momentum and gives under it.
				var v := drop.linear_velocity
				var hand := Vector2(v.x * 0.25, maxf(v.y, 0.0)).limit_length(catch_max_speed) * catch_give
				midpoint_velocity += hand
		speed += gravity.dot(tangent) * drop.gravity_scale * dt
		speed *= 0.955
		if absf(tangent.dot(Vector2.DOWN)) < 0.06:
			speed *= 0.9
		u += (speed / span) * dt
		if u <= 0.05 or u >= 0.95:
			speed *= -0.35
			u = clampf(u, 0.05, 0.95)
		var point := _bezier(u)
		var normal := _bezier_up(u)
		drop.global_position = to_global(point + normal * limit)
		drop.linear_velocity = Vector2.ZERO
		drop.ride_surface(tangent * speed, impact)
		var pull := current_midpoint - rest_midpoint if is_dragged else Vector2.ZERO
		drop.feel(is_dragged, pull)
		kept.append(drop)
		kept_u[id] = u
		kept_speed[id] = speed
	seated_drops.clear()
	seated_drops.append_array(kept)
	seat_u.clear()
	seat_speed.clear()
	for id in kept_u:
		seat_u[id] = kept_u[id]
		seat_speed[id] = kept_speed[id]
	drop_is_seated = seated_drops.size() > 0


func catch_point() -> Vector2:
	var mid := _bezier(0.5)
	return to_global(mid + _bezier_up(0.5) * (membrane_radius + drop_radius + 4.0))


func _fell_onto_curve(prev: Vector2, curr: Vector2, radius: float = 12.0) -> bool:
	var span_left := minf(anchor_left.x, anchor_right.x) - (radius + 4.0)
	var span_right := maxf(anchor_left.x, anchor_right.x) + (radius + 4.0)
	if curr.x < span_left or curr.x > span_right:
		return false
	var k := radius / 12.0
	var above := prev.y <= _bezier(_closest_bezier_u(prev)).y + 10.0 * k
	var below := curr.y >= _bezier(_closest_bezier_u(curr)).y - 8.0 * k
	return above and below and curr.y >= prev.y


func _upward_normal(index: int) -> Vector2:
	var i := clampi(index, 0, curve_points.size() - 2)
	var tangent: Vector2 = curve_points[i + 1] - curve_points[i]
	if tangent.length() < 0.001:
		return Vector2.UP
	var normal := Vector2(-tangent.y, tangent.x).normalized()
	if normal.dot(Vector2.UP) < 0.0:
		normal = -normal
	return normal


func _drops_on_membrane() -> Array[Gloop]:
	var found: Array[Gloop] = []
	for node in get_tree().get_nodes_in_group("gloop"):
		var drop := node as Gloop
		if drop == null or drop.is_absorbed or drop.is_forming:
			continue
		var local := to_local(drop.global_position)
		var hit: Dictionary = _closest_on_curve(local, curve_points)
		if float(hit.dist) <= membrane_radius + drop.base_radius + 8.0 * drop.base_radius / 12.0:
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
