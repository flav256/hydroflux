extends Node2D
class_name LevelBase

## Shared level lifecycle: spawners, win routing, atmosphere hooks.

const WetGlowScript := preload("res://scripts/objects/WetGlow.gd")

@export var level_id: String = "level_00"
@export var next_scene: PackedScene

@export_group("Light")
## Backlight the room keeps before its well is fed. 1.0 is fully lit.
@export var room_ambient: float = 0.3
## Backlight after the well blooms.
@export var bloom_ambient: float = 1.0


func on_level_complete() -> void:
	GameManager.complete_current_level()
	AudioController.play_victory()
	if next_scene:
		await get_tree().create_timer(3.0).timeout
		get_tree().change_scene_to_packed(next_scene)
	else:
		await get_tree().create_timer(3.5).timeout
		GameManager.return_to_menu()


## Dims the room, gives every cavern rock a shadow, and adds the wet-stone glow layer.
func setup_light_room() -> void:
	var room := room_material()
	if room:
		room.set_shader_parameter("ambient", room_ambient)
	for node in find_children("*", "CollisionPolygon2D", true, false):
		var shape := node as CollisionPolygon2D
		if not (shape.get_parent() is StaticBody2D):
			continue
		var polygon := OccluderPolygon2D.new()
		polygon.polygon = shape.polygon
		var occluder := LightOccluder2D.new()
		occluder.occluder = polygon
		shape.add_child(occluder)
	add_child(WetGlowScript.new())


func room_material() -> ShaderMaterial:
	var background := get_node_or_null("Background") as CanvasItem
	if background == null:
		return null
	return background.material as ShaderMaterial
