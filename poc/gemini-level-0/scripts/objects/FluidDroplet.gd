extends RigidBody2D
class_name FluidDroplet

## HydroFlux - Fluid Droplet Physics Object
## Bioluminescent cyan liquid drop with realistic gravity,
## deformation stretching, and collision particle splashing.

signal splashed(position: Vector2, normal: Vector2)
signal absorbed_by_target(droplet: FluidDroplet)

@export var droplet_color: Color = Color(0.02, 0.71, 0.83, 1.0)
@export var core_color: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var base_radius: float = 7.0
@export var max_velocity_stretch: float = 1.8

var is_absorbed: boolean = false
@onready var light: PointLight2D = $PointLight2D if has_node("PointLight2D") else null

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	gravity_scale = 1.15
	body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	if is_absorbed:
		return
	queue_redraw()

func _draw() -> void:
	if is_absorbed:
		return
		
	var speed: float = linear_velocity.length()
	var stretch: float = clamp(1.0 + (speed / 700.0) * (max_velocity_stretch - 1.0), 1.0, max_velocity_stretch)
	var squash: float = 1.0 / sqrt(stretch)
	
	var angle: float = linear_velocity.angle()
	draw_set_transform(Vector2.ZERO, angle, Vector2(stretch, squash))
	
	# Outer glowing halo
	draw_circle(Vector2.ZERO, base_radius * 1.4, Color(droplet_color.r, droplet_color.g, droplet_color.b, 0.35))
	# Main liquid body
	draw_circle(Vector2.ZERO, base_radius, droplet_color)
	# High-luminance white core
	draw_circle(Vector2.ZERO, base_radius * 0.45, core_color)

func apply_launch_impulse(impulse: Vector2) -> void:
	# Reset existing downward velocity and apply slingshot impulse vector
	linear_velocity = Vector2.ZERO
	apply_central_impulse(impulse)

func absorb_into_target() -> void:
	is_absorbed = true
	freeze = true
	
	# Shrink and dissolve into the receptacle
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	await tween.finished
	absorbed_by_target.emit(self)
	queue_free()

func _on_body_entered(body: Node) -> void:
	if linear_velocity.length() > 180.0:
		splashed.emit(global_position, -linear_velocity.normalized())
