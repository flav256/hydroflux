extends Node2D
class_name ElasticTendril

## Slingshot vine: two anchors, quadratic bezier, spring rebound, launch impulse.

signal tendril_stretched(displacement: Vector2, ratio: float)
signal tendril_released(impulse_vector: Vector2)
signal droplet_launched(droplet: Node, velocity: Vector2)

@export_group("Anchors & Geometry")
@export var anchor_left: Vector2 = Vector2(-140.0, 0.0)
@export var anchor_right: Vector2 = Vector2(140.0, 0.0)
@export var grab_radius: float = 65.0
@export var max_stretch_distance: float = 135.0

@export_group("Elastic Physics")
@export var spring_stiffness: float = 180.0
@export var damping: float = 14.0
@export var launch_force_multiplier: float = 8.5
@export var min_release_impulse: float = 120.0

@export_group("Visuals & Glow")
@export var tendril_color: Color = Color(0.9, 0.98, 1.0, 0.9)
@export var tension_glow_color: Color = Color(0.02, 0.71, 0.83, 1.0)
@export var default_thickness: float = 4.0
@export var stretched_thickness: float = 2.2
@export var curve_segments: int = 32

var rest_midpoint: Vector2 = Vector2.ZERO
var current_midpoint: Vector2 = Vector2.ZERO
var midpoint_velocity: Vector2 = Vector2.ZERO
var is_dragged: bool = false
var active_touch_index: int = -1

@onready var line_2d: Line2D = get_node_or_null("Line2D")
@onready var area_2d: Area2D = get_node_or_null("Area2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("Area2D/CollisionShape2D")
@onready var snap_audio: AudioStreamPlayer2D = get_node_or_null("SnapAudio")


func _ready() -> void:
	rest_midpoint = (anchor_left + anchor_right) * 0.5
	current_midpoint = rest_midpoint
	update_visual_curve()
	if area_2d:
		area_2d.body_entered.connect(_on_body_entered)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var local_pos := InputManager.event_local_position(touch, self)
		if touch.pressed:
			if not is_dragged and local_pos.distance_to(current_midpoint) <= grab_radius:
				is_dragged = true
				active_touch_index = touch.index
				_handle_drag(local_pos)
		elif is_dragged and touch.index == active_touch_index:
			_release_tendril()
	elif event is InputEventScreenDrag and is_dragged:
		var drag := event as InputEventScreenDrag
		if drag.index == active_touch_index:
			_handle_drag(InputManager.event_local_position(drag, self))
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		var local_mouse := InputManager.event_local_position(mouse, self)
		if mouse.pressed:
			if local_mouse.distance_to(current_midpoint) <= grab_radius:
				is_dragged = true
				active_touch_index = 0
				_handle_drag(local_mouse)
		elif is_dragged:
			_release_tendril()
	elif event is InputEventMouseMotion and is_dragged:
		_handle_drag(InputManager.event_local_position(event, self))


func _handle_drag(target_pos: Vector2) -> void:
	var offset := target_pos - rest_midpoint
	if offset.length() > max_stretch_distance:
		offset = offset.normalized() * max_stretch_distance
	current_midpoint = rest_midpoint + offset
	midpoint_velocity = Vector2.ZERO
	var ratio := clampf(offset.length() / max_stretch_distance, 0.0, 1.0)
	tendril_stretched.emit(offset, ratio)
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
	_launch_colliding_droplets(impulse_vector)


func _physics_process(delta: float) -> void:
	if not is_dragged:
		var displacement := current_midpoint - rest_midpoint
		var spring_force := -spring_stiffness * displacement
		var damping_force := -damping * midpoint_velocity
		midpoint_velocity += (spring_force + damping_force) * delta
		current_midpoint += midpoint_velocity * delta
		if displacement.length() < 0.25 and midpoint_velocity.length() < 0.9:
			current_midpoint = rest_midpoint
			midpoint_velocity = Vector2.ZERO
		update_visual_curve()
		queue_redraw()
	if collision_shape:
		collision_shape.position = current_midpoint


func update_visual_curve() -> void:
	if line_2d == null:
		return
	var points := PackedVector2Array()
	for i in range(curve_segments + 1):
		var t := float(i) / float(curve_segments)
		points.append(_sample_quadratic_bezier(anchor_left, current_midpoint, anchor_right, t))
	line_2d.points = points
	var stretch_ratio := (current_midpoint - rest_midpoint).length() / max_stretch_distance
	line_2d.width = lerpf(default_thickness, stretched_thickness, stretch_ratio)
	line_2d.default_color = tendril_color.lerp(tension_glow_color, stretch_ratio * 0.85)


func _draw() -> void:
	draw_circle(anchor_left, 5.0, Color(0.1, 0.12, 0.15))
	draw_circle(anchor_right, 5.0, Color(0.1, 0.12, 0.15))
	if is_dragged:
		draw_circle(current_midpoint, 7.0, tension_glow_color)
		draw_circle(current_midpoint, 14.0, Color(tension_glow_color, 0.25))


func _sample_quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return (u * u * p0) + (2.0 * u * t * p1) + (t * t * p2)


func _launch_colliding_droplets(impulse: Vector2) -> void:
	if area_2d == null:
		return
	for body in area_2d.get_overlapping_bodies():
		if body.has_method("apply_launch_impulse"):
			body.apply_launch_impulse(impulse)
			droplet_launched.emit(body, impulse)
		elif body is RigidBody2D:
			(body as RigidBody2D).apply_central_impulse(impulse)
			droplet_launched.emit(body, impulse)


func _on_body_entered(body: Node2D) -> void:
	if midpoint_velocity.length() > 30.0 and body is RigidBody2D:
		(body as RigidBody2D).apply_central_impulse(midpoint_velocity * 1.5)
