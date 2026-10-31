extends Node

## Global progression, pause, and scene routing.

signal level_completed(level_id: String)
signal game_paused(paused: bool)

const SAVE_PATH := "user://hydroflux.save"
const LEVEL_SCENES := {
	"level_00": "res://scenes/levels/Level_00.tscn",
}

var current_level_id: String = "level_00"
var unlocked_levels: PackedStringArray = PackedStringArray(["level_00"])
var is_paused: bool = false


func _ready() -> void:
	_load_progress()


func load_level(level_id: String) -> void:
	if not LEVEL_SCENES.has(level_id):
		push_error("Unknown level: %s" % level_id)
		return
	current_level_id = level_id
	get_tree().change_scene_to_file(LEVEL_SCENES[level_id])


func complete_current_level() -> void:
	level_completed.emit(current_level_id)
	_unlock_next(current_level_id)
	_save_progress()


func return_to_menu() -> void:
	set_paused(false)
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func set_paused(paused: bool) -> void:
	is_paused = paused
	get_tree().paused = paused
	game_paused.emit(paused)


func _unlock_next(level_id: String) -> void:
	if level_id == "level_00" and not unlocked_levels.has("level_01"):
		unlocked_levels.append("level_01")


func _save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_var({"unlocked": Array(unlocked_levels)})


func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = file.get_var()
	if data is Dictionary and data.has("unlocked"):
		unlocked_levels = PackedStringArray(data["unlocked"])
