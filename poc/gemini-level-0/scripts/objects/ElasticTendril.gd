extends Node2D
class_name ElasticTendril

## HydroFlux - Elastic Tendril Slingshot Movement Controller
## Atmospheric physics-based sling system inspired by Contre-Jour.
## Connects two fixed anchor points with a dynamic bezier curve that can be pulled
## and released, imparting spring impulse vectors to colliding fluid droplets.

signal tendril_stretched(displacement: Vector2, ratio: number)
signal tendril_released(impulse_vector: Vector2)
signal droplet_launched(droplet: Node, velocity: Vector2)

# --- Configuration Exports ---
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

# --- Internal State ---
var rest_midpoint: Vector2 = Vector2.ZERO
var current_midpoint: Vector2 = Vector2.ZERO
var midpoint_velocity: Vector2 = Vector2.ZERO
var is_dragged: boolean = false
var active_touch_index: int = -1

# Audio & visual references
@onready var line_2d: Line2D = $Line2D if has_node("Line2D") else null
@onready var area_2d: Area2D = $Area2D if has_node("Area2D") else null
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D if has_node("Area2D/CollisionShape2D") else null
@onready var snap_audio: AudioStreamPlayer2D = $SnapAudio if has_node("SnapAudio") else null

func _ready() -> void:
	rest_midpoint = (anchor_left + anchor_right) * 0.5
	current_midpoint = rest_midpoint
	update_visual_curve()
	
	if area_2d:
		area_2d.body_entered.connect(_on_body_entered)

func _unhandled_input(event: InputEvent) -> void:
	# Multi-touch input on mobile
	if event is InputEventScreenTouch:
		var local_touch_pos: Vector2 = to_local(event.position)
		if event.pressed:
			if not is_dragged and local_touch_pos.distance_to(current_midpoint) <= grab_radius:
				is_dragged = true
				active_touch_index = event.index
				_handle_drag(local_touch_pos)
		elif is_dragged and event.index == active_touch_index:
			_release_tendril()
			
	elif event is InputEventScreenDrag and is_dragged:
		if event.index == active_touch_index:
			var local_drag_pos: Vector2 = to_local(event.position)
			_handle_drag(local_drag_pos)

	# Desktop Mouse fallback for debugging and testing
	elif event is InputEventMouseButton:
		var local_mouse_pos: Vector2 = to_local(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if local_mouse_pos.distance_to(current_midpoint) <= grab_radius:
					is_dragged = true
					active_touch_index = 0
					_handle_drag(local_mouse_pos)
			elif is_dragged:
				_release_tendril()
				
	elif event is InputEventMouseMotion and is_dragged:
		var local_mouse_pos: Vector2 = to_local(event.position)
		_handle_drag(local_mouse_pos)

func _handle_drag(target_pos: Vector2) -> void:
	var offset: Vector2 = target_pos - rest_midpoint
	var stretch_length: float = offset.length()
	
	if stretch_length > max_stretch_distance:
		offset = offset.normalized() * max_stretch_distance
		
	current_midpoint = rest_midpoint + offset
	midpoint_velocity = Vector2.ZERO
	
	var ratio: float = clamp(stretch_length / max_stretch_distance, 0.0, 1.0)
	tendril_stretched.emit(offset, ratio)
	update_visual_curve()
	queue_redraw()

func _release_tendril() -> void:
	is_dragged = false
	active_touch_index = -1
	
	var displacement: Vector2 = current_midpoint - rest_midpoint
	var stretch_dist: float = displacement.length()
	
	if stretch_dist > 5.0:
		# Calculate restorative launch impulse vector
		var impulse_direction: Vector2 = -displacement.normalized()
		var impulse_magnitude: float = max(stretch_dist * launch_force_multiplier, min_release_impulse)
		var impulse_vector: Vector2 = impulse_direction * impulse_magnitude
		
		# Give midpoint initial snap velocity
		midpoint_velocity = impulse_vector * 0.4
		
		# Play tactile snap sound effect
		if snap_audio:
			snap_audio.pitch_scale = randf_range(0.95, 1.08)
			snap_audio.play()
			
		tendril_released.emit(impulse_vector)
		_launch_colliding_droplets(impulse_vector)

func _physics_process(delta: float) -> void:
	if not is_dragged:
		# Damped spring oscillation toward rest midpoint
		var displacement: Vector2 = current_midpoint - rest_midpoint
		var spring_force: Vector2 = -spring_stiffness * displacement
		var damping_force: Vector2 = -damping * midpoint_velocity
		var acceleration: Vector2 = spring_force + damping_force
		
		midpoint_velocity += acceleration * delta
		current_midpoint += midpoint_velocity * delta
		
		# Stop micro-jitters
		if displacement.length() < 0.2 and midpoint_velocity.length() < 0.8:
			current_midpoint = rest_midpoint
			midpoint_velocity = Vector2.ZERO
			
		update_visual_curve()
		queue_redraw()

func update_visual_curve() -> void:
	if line_2d:
		var points: PackedVector2Array = PackedVector2Array()
		for i in range(curve_segments + 1):
			var t: float = float(i) / float(curve_segments)
			points.append(_sample_quadratic_bezier(anchor_left, current_midpoint, anchor_right, t))
		line_2d.points = points
		
		# Dynamic thickness based on tension
		var stretch_ratio: float = (current_midpoint - rest_midpoint).length() / max_stretch_distance
		line_2d.width = lerp(default_thickness, stretched_thickness, stretch_ratio)
		line_2d.default_color = tendril_color.lerp(tension_glow_color, stretch_ratio * 0.85)

func _draw() -> void:
	# Draw anchor points (organic silhouette dots)
	draw_circle(anchor_left, 5.0, Color(0.1, 0.12, 0.15))
	draw_circle(anchor_right, 5.0, Color(0.1, 0.12, 0.15))
	
	# Draw touch indicator if dragged
	if is_dragged:
		draw_circle(current_midpoint, 7.0, tension_glow_color)
		draw_circle(current_midpoint, 14.0, Color(tension_glow_color.r, tension_glow_color.g, tension_glow_color.b, 0.25))

func _sample_quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return (u * u * p0) + (2.0 * u * t * p1) + (t * t * p2)

func _launch_colliding_droplets(impulse: Vector2) -> void:
	if not area_2d:
		return
	var overlapping_bodies: Array[Node2D] = area_2d.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.has_method("apply_launch_impulse"):
			body.apply_launch_impulse(impulse)
			droplet_launched.emit(body, impulse)
		elif body is RigidBody2D:
			body.apply_central_impulse(impulse)
			droplet_launched.emit(body, impulse)

func _on_body_entered(body: Node2D) -> void:
	# If tendril is currently vibrating or rebounding, impart impulse on contact
	if midpoint_velocity.length() > 30.0 and body is RigidBody2D:
		var contact_impulse: Vector2 = midpoint_velocity * 1.5
		body.apply_central_impulse(contact_impulse)
