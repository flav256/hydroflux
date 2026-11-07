extends Node2D
class_name WetGlow

## Wet stone remembers the light. Gloop leaves a fading glow wherever it
## lands, spreads, or glides, so a miss still maps the room.

@export var lifetime: float = 16.0
@export var max_marks: int = 240
@export var glow_color: Color = Color(0.3, 0.92, 1.0, 1.0)

var _pos := PackedVector2Array()
var _dir := PackedVector2Array()
var _width := PackedFloat32Array()
var _age := PackedFloat32Array()


func _ready() -> void:
	add_to_group("wet_glow")
	# Above the silhouette plates so the wet edge shows on black stone.
	z_index = 5
	light_mask = 0
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


## `at` is a world point on the stone, `along` the surface tangent, `width` the wet span.
func mark(at: Vector2, along: Vector2, width: float) -> void:
	var local := to_local(at)
	var newest := _pos.size() - 1
	for i in range(newest, maxi(newest - 6, -1), -1):
		if _pos[i].distance_to(local) < width * 0.3:
			_age[i] = 0.0
			_width[i] = maxf(_width[i], width)
			return
	_pos.append(local)
	_dir.append(along.normalized() if along.length_squared() > 0.0001 else Vector2.RIGHT)
	_width.append(width)
	_age.append(0.0)
	if _pos.size() > max_marks:
		_remove(0)


func _process(delta: float) -> void:
	if _pos.is_empty():
		return
	for i in range(_pos.size() - 1, -1, -1):
		_age[i] += delta
		if _age[i] >= lifetime:
			_remove(i)
	queue_redraw()


func _remove(i: int) -> void:
	_pos.remove_at(i)
	_dir.remove_at(i)
	_width.remove_at(i)
	_age.remove_at(i)


func _draw() -> void:
	for i in _pos.size():
		var fade := 1.0 - _age[i] / lifetime
		fade *= fade
		var half := _dir[i] * _width[i] * 0.5
		var a := _pos[i] - half
		var b := _pos[i] + half
		draw_line(a, b, Color(glow_color, 0.07 * fade), 14.0, true)
		draw_line(a, b, Color(glow_color, 0.5 * fade), 2.2, true)
