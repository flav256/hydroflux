extends Node2D
class_name LevelBase

## Shared level lifecycle: spawners, win routing, atmosphere hooks.

@export var level_id: String = "level_00"
@export var next_scene: PackedScene


func on_level_complete() -> void:
	GameManager.complete_current_level()
	AudioController.play_victory()
	if next_scene:
		await get_tree().create_timer(3.0).timeout
		get_tree().change_scene_to_packed(next_scene)
	else:
		await get_tree().create_timer(3.5).timeout
		GameManager.return_to_menu()
