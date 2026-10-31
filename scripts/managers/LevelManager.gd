extends Node

## Scene-local coordinator. Levels attach this or extend LevelBase.

signal phase_changed(phase_name: String)
signal victory()


func announce_phase(phase_name: String) -> void:
	phase_changed.emit(phase_name)


func announce_victory() -> void:
	victory.emit()
	GameManager.complete_current_level()
