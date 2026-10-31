extends Control

## Opening. One drop finds the vine, then the room waits for a touch.

var _left: bool = false
var _glow: ShaderMaterial


func _ready() -> void:
	AudioController.play_bed()
	var source := $Backdrop.material as ShaderMaterial
	_glow = source.duplicate() as ShaderMaterial
	$Backdrop.material = _glow
	_glow.set_shader_parameter("glow_center", Vector2(0.5, 0.34))


func _process(_delta: float) -> void:
	var art := $Art
	var pos: Vector2 = art.drop_position
	var amount: float = art.drop_glow
	_glow.set_shader_parameter("glow_center", Vector2(pos.x / 1280.0, pos.y / 720.0))
	var heart := Vector3(0.12, 0.42, 0.5).lerp(Vector3(0.28, 0.72, 0.78), amount * 0.35)
	_glow.set_shader_parameter("heart_color", heart)


func _input(event: InputEvent) -> void:
	if _left or $Art.time < 0.6:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_go()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_go()


func _go() -> void:
	if _left:
		return
	_left = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	tween.tween_callback(func() -> void:
		GameManager.open_level_select()
	)
