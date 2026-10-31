extends Node

## Routing, chapter list, stars, and points.
## The chapter list is a draft and will move as the narrative changes.

signal level_completed(level_id: String)

const SAVE_PATH := "user://hydroflux.save"
const PLACEHOLDER := "res://scenes/levels/LevelPlaceholder.tscn"
const LEVEL_SELECT := "res://scenes/ui/LevelSelect.tscn"

const LEVELS: Array[Dictionary] = [
	{"id": "level_00", "title": "The First Drop", "chapter": "Chapter 1", "scene": "res://scenes/levels/Level_00.tscn", "fast_seconds": 28.0},
	{"id": "level_01", "title": "The Vein", "chapter": "Chapter 1", "scene": PLACEHOLDER, "fast_seconds": 30.0},
	{"id": "level_02", "title": "The Thread", "chapter": "Chapter 1", "scene": PLACEHOLDER, "fast_seconds": 35.0},
	{"id": "level_03", "title": "The Breath", "chapter": "Chapter 1", "scene": PLACEHOLDER, "fast_seconds": 35.0},
	{"id": "level_04", "title": "The Cup", "chapter": "Chapter 1", "scene": PLACEHOLDER, "fast_seconds": 40.0},
	{"id": "level_05", "title": "The Dark", "chapter": "Chapter 1", "scene": PLACEHOLDER, "fast_seconds": 30.0},
]

var current_level_id: String = ""
var records: Dictionary = {}
var is_paused: bool = false


func _ready() -> void:
	_load_progress()


func level_def(level_id: String) -> Dictionary:
	for entry in LEVELS:
		if entry["id"] == level_id:
			return entry
	return {}


func can_open(level_id: String) -> bool:
	var entry := level_def(level_id)
	if entry.is_empty():
		return false
	if entry["scene"] != PLACEHOLDER:
		return true
	return OS.is_debug_build()


func load_level(level_id: String) -> void:
	if not can_open(level_id):
		return
	var entry := level_def(level_id)
	current_level_id = level_id
	get_tree().change_scene_to_file(entry["scene"])


func open_level_select() -> void:
	set_paused(false)
	AudioController.play_bed()
	get_tree().change_scene_to_file(LEVEL_SELECT)


func record_level(level_id: String, misses: int, seconds: float) -> Dictionary:
	var entry := level_def(level_id)
	var fast: float = float(entry.get("fast_seconds", 30.0))
	var stars := 1
	if misses <= 1:
		stars += 1
	if seconds <= fast:
		stars += 1
	var points := 100 + (stars - 1) * 50 - maxi(0, misses - 1) * 10
	points = maxi(points, 40)
	var prev: Dictionary = records.get(level_id, {})
	var best_stars := maxi(int(prev.get("stars", 0)), stars)
	var best_points := maxi(int(prev.get("points", 0)), points)
	var best_time: float = seconds
	if prev.has("best_time"):
		best_time = minf(float(prev["best_time"]), seconds)
	records[level_id] = {
		"stars": best_stars,
		"points": best_points,
		"best_time": best_time,
	}
	level_completed.emit(level_id)
	_save_progress()
	return {
		"stars": stars,
		"points": points,
		"best_stars": best_stars,
		"total": total_points(),
		"fast": seconds <= fast,
		"clean": misses <= 1,
	}


func total_points() -> int:
	var sum := 0
	for id in records:
		sum += int(records[id].get("points", 0))
	return sum


func stars_for(level_id: String) -> int:
	return int(records.get(level_id, {}).get("stars", 0))


func set_paused(paused: bool) -> void:
	is_paused = paused
	get_tree().paused = paused


func _save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_var({"records": records})


func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = file.get_var()
	if data is Dictionary and data.get("records") is Dictionary:
		records = data["records"]
