extends RigidBody2D
class_name FluidDroplet

## Bioluminescent drop: hang-and-form, detach, stretch-in-flight, splash squash.

signal splashed(at_position: Vector2, normal: Vector2)
signal absorbed_by_target(droplet: FluidDroplet)
signal detached()

@export var droplet_color: Color = Color(0.02, 0.71, 0.83, 1.0)
@export var core_color: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var base_radius: float = 12.0
@export var max_velocity_stretch: float = 1.8
@export var form_duration: float = 0.85

var is_absorbed: bool = false
var is_forming: bool = false
var form_t: float = 0.0
var splash_squash: float = 1.0
var membrane_cooldown: float = 0.0
var surface_velocity: Vector2 = Vector2.ZERO
var trail: Array[Vector2] = []

@onready var light: PointLight2D = get_node_or_null("PointLight2D")


func _ready() -> void:
	add_to_group("fluid_droplet")
	contact_monitor = true
	max_contacts_reported = 4
	gravity_scale = 1.15
	body_entered.connect(_on_body_entered)
	if light:
		light.color = droplet_color
		light.energy = 1.15


func begin_formation() -> void:
	is_forming = true
	form_t = 0.0
	freeze = true
	scale = Vector2(0.15, 0.35)
	AudioController.play(AudioController.Cue.DROP_FORM, randf_range(0.9, 1.1))


func ignore_membrane(duration: float) -> void:
	membrane_cooldown = duration


func _physics_process(delta: float) -> void:
	if membrane_cooldown > 0.0:
		membrane_cooldown = maxf(membrane_cooldown - delta, 0.0)
	if is_absorbed:
		return
	if is_forming:
		form_t += delta / maxf(form_duration, 0.05)
		var eased := smoothstep(0.0, 1.0, clampf(form_t, 0.0, 1.0))
		scale = Vector2(lerpf(0.15, 1.0, eased), lerpf(0.35, 1.05, eased))
		if form_t >= 1.0:
			_detach()
	splash_squash = move_toward(splash_squash, 1.0, delta * 3.2)
	if is_forming:
		trail.clear()
	elif Engine.get_physics_frames() % 2 == 0:
		trail.append(global_position)
		if trail.size() > 8:
			trail.remove_at(0)
	queue_redraw()


func _detach() -> void:
	is_forming = false
	scale = Vector2.ONE
	freeze = false
	AudioController.play_drop_detach()
	detached.emit()


func ride_surface(velocity: Vector2, impact_speed: float) -> void:
	surface_velocity = velocity
	if impact_speed > 90.0:
		splash_squash = clampf(1.0 - impact_speed / 1600.0, 0.48, 0.8)


func _draw() -> void:
	if is_absorbed:
		return
	var motion := linear_velocity
	if surface_velocity.length_squared() > motion.length_squared():
		motion = surface_velocity
	var now := Time.get_ticks_msec() * 0.001
	var speed := motion.length()
	var dir := Vector2.DOWN
	if speed > 36.0:
		dir = motion.normalized()
	var stretch := clampf(speed / 480.0, 0.0, 0.9)
	if freeze and not is_forming:
		stretch = 0.06 + sin(now * 3.4) * 0.035
	var step := 0
	for point in trail:
		step += 1
		var local := to_local(point)
		if local.length() < base_radius * 0.7:
			continue
		var fade := 1.0 - float(step) / float(trail.size() + 1)
		draw_circle(local, base_radius * lerpf(0.28, 0.72, fade), Color(droplet_color, 0.28 * fade))
	draw_circle(Vector2.ZERO, base_radius * 3.3, Color(droplet_color, 0.07))
	draw_circle(Vector2.ZERO, base_radius * 2.1, Color(droplet_color, 0.12))
	var body := PackedVector2Array()
	for i in 26:
		var a := TAU * float(i) / 26.0
		var n := Vector2(cos(a), sin(a))
		var along := n.dot(dir)
		var side := n - dir * along
		var wide := base_radius * splash_squash * (1.0 + stretch * 0.12)
		var p := side * wide + dir * along * base_radius * (0.82 - stretch * 0.2)
		if along < 0.0:
			p += -dir * base_radius * (0.45 + stretch * 1.15) * (-along)
		p += n * sin(a * 3.0 + now * 7.0) * base_radius * 0.055
		body.append(p)
	draw_colored_polygon(body, droplet_color)
	var glint := -dir * base_radius * 0.12 + Vector2(cos(now * 2.3), sin(now * 2.9)) * base_radius * 0.18
	draw_circle(glint, base_radius * 0.36, Color(0.9, 1.0, 1.0, 0.92))
	draw_circle(glint * 0.35, base_radius * 0.13, core_color)


func apply_launch_impulse(impulse: Vector2) -> void:
	if is_forming:
		_detach()
	freeze = false
	surface_velocity = Vector2.ZERO
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	apply_central_impulse(impulse)


func absorb_into_target() -> void:
	if is_absorbed:
		return
	is_absorbed = true
	# freeze/collision changes are illegal inside a physics callback.
	set_deferred("freeze", true)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	if light:
		tween.tween_property(light, "energy", 0.0, 0.3)
	await tween.finished
	absorbed_by_target.emit(self)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if is_forming or is_absorbed:
		return
	splash_squash = 0.62
	if linear_velocity.length() > 180.0:
		splashed.emit(global_position, -linear_velocity.normalized())
		AudioController.play(AudioController.Cue.DROP_SPLASH, randf_range(0.92, 1.12))
	if body is StaticBody2D:
		pass
