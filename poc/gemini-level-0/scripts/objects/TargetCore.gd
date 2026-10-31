extends Area2D
class_name TargetCore

## HydroFlux - Target Core Receptacle
## Absorbs fluid droplets, illuminates the cavern, and signals level victory.

signal core_activated
signal fluid_received(current_amount: int, required_amount: int)

@export var required_fluid_volume: int = 1
@export var glow_color: Color = Color(0.02, 0.71, 0.83, 1.0)
@export var core_radius: float = 32.0

var current_volume: int = 0
var is_active: boolean = false
var pulse_time: float = 0.0

@onready var light: PointLight2D = $CoreGlowLight if has_node("CoreGlowLight") else null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()

func _draw() -> void:
	var pulse: float = sin(pulse_time * 2.5) * 0.15 + 0.85
	var fill_ratio: float = float(current_volume) / float(max(1, required_fluid_volume))
	
	# Outer receptacle dark silhouette ring
	draw_circle(Vector2.ZERO, core_radius + 4.0, Color(0.05, 0.06, 0.08))
	draw_arc(Vector2.ZERO, core_radius, 0.0, TAU, 32, Color(0.2, 0.25, 0.3), 3.0)
	
	# Inner glowing liquid core
	if fill_ratio > 0.0:
		var inner_rad: float = core_radius * 0.85 * fill_ratio * pulse
		draw_circle(Vector2.ZERO, inner_rad, Color(glow_color.r, glow_color.g, glow_color.b, 0.8))
		draw_circle(Vector2.ZERO, inner_rad * 0.5, Color.WHITE)

func _on_body_entered(body: Node2D) -> void:
	if body is FluidDroplet and not body.is_absorbed:
		body.absorb_into_target()
		current_volume += 1
		fluid_received.emit(current_volume, required_fluid_volume)
		
		# Animate activation ripple
		var tween: Tween = create_tween()
		if light:
			tween.tween_property(light, "energy", 4.0, 0.2).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(light, "energy", 2.2, 0.5)
			
		if current_volume >= required_fluid_volume and not is_active:
			is_active = true
			core_activated.emit()
