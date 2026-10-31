extends Area2D
class_name TargetCore

## Receptacle that absorbs droplets, pulses glow, and fires victory.

signal core_activated
signal fluid_received(current_amount: int, required_amount: int)

@export var required_fluid_volume: int = 1
@export var glow_color: Color = Color(0.02, 0.71, 0.83, 1.0)
@export var core_radius: float = 42.0

var current_volume: int = 0
var is_active: bool = false
var pulse_time: float = 0.0

@onready var light: PointLight2D = get_node_or_null("CoreGlowLight")


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := sin(pulse_time * 2.5) * 0.15 + 0.85
	var fill_ratio := float(current_volume) / float(maxi(1, required_fluid_volume))
	draw_circle(Vector2.ZERO, core_radius * 1.8, Color(glow_color, 0.08 * pulse))
	draw_circle(Vector2.ZERO, core_radius + 10.0, Color(0, 0, 0, 1))
	draw_arc(Vector2.ZERO, core_radius + 2.0, 0.0, TAU, 48, Color(glow_color, 0.85 * pulse), 2.0)
	var inner := core_radius * (0.28 + 0.6 * fill_ratio) * pulse
	draw_circle(Vector2.ZERO, inner, Color(glow_color, 0.35 + 0.5 * fill_ratio))
	draw_circle(Vector2.ZERO, inner * 0.45, Color(1, 1, 1, 0.35 + 0.6 * fill_ratio))


func _on_body_entered(body: Node2D) -> void:
	if body is Gloop and not (body as Gloop).is_absorbed:
		(body as Gloop).absorb_into_target()
		current_volume += 1
		fluid_received.emit(current_volume, required_fluid_volume)
		AudioController.play(AudioController.Cue.CORE_ABSORB)
		var tween := create_tween()
		if light:
			tween.tween_property(light, "energy", 4.0, 0.2).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(light, "energy", 2.2, 0.5)
		if current_volume >= required_fluid_volume and not is_active:
			is_active = true
			core_activated.emit()
