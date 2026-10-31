extends Control


func _on_play_pressed() -> void:
	GameManager.load_level("level_00")


func _on_quit_pressed() -> void:
	get_tree().quit()
