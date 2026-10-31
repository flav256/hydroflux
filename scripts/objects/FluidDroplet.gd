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
	splash_squash = move_toward(splash_squash, 1.0, delta * 4.0)
	queue_redraw()


func _detach() -> void:
	is_forming = false
	scale = Vector2.ONE
	freeze = false
	AudioController.play_drop_detach()
	detached.emit()


func _draw() -> void:
	if is_absorbed:
		return
	var speed := linear_velocity.length()
	var stretch := clampf(1.0 + (speed / 700.0) * (max_velocity_stretch - 1.0), 1.0, max_velocity_stretch)
	var squash := (1.0 / sqrt(stretch)) * splash_squash
	var angle := 0.0 if is_forming or freeze else linear_velocity.angle()
	draw_set_transform(Vector2.ZERO, angle, Vector2(stretch, squash))
	draw_circle(Vector2.ZERO, base_radius * 3.4, Color(droplet_color, 0.08))
	draw_circle(Vector2.ZERO, base_radius * 2.2, Color(droplet_color, 0.16))
	draw_circle(Vector2.ZERO, base_radius * 1.45, Color(droplet_color, 0.45))
	draw_circle(Vector2.ZERO, base_radius, droplet_color)
	draw_circle(Vector2.ZERO, base_radius * 0.55, Color(0.85, 1.0, 1.0, 0.95))
	draw_circle(Vector2.ZERO, base_radius * 0.22, core_color)


func apply_launch_impulse(impulse: Vector2) -> void:
	if is_forming:
		_detach()
	freeze = false
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
