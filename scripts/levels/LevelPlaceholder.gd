extends Node2D


func _ready() -> void:
	var entry := GameManager.level_def(GameManager.current_level_id)
	var title: String = entry.get("title", "Level")
	$Title.text = title
	$Note.text = "This room is not built yet."


func _on_back_pressed() -> void:
	GameManager.open_level_select()
