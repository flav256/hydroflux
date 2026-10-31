extends Node

## Contextual ambient bed + one-shot SFX. Real files land in assets/audio/.
## Until then, a lightweight Web-like procedural fallback is silent no-ops
## when streams are missing so the game stays playable.

enum Cue {
	DROP_FORM,
	DROP_DETACH,
	DROP_SPLASH,
	TENDRIL_STRAIN,
	TENDRIL_SNAP,
	CORE_ABSORB,
	VICTORY,
}

var _players: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for cue in range(Cue.size()):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players[cue] = player


func play(cue: Cue, pitch: float = 1.0) -> void:
	var player: AudioStreamPlayer = _players.get(cue)
	if player == null or player.stream == null:
		return
	player.pitch_scale = clampf(pitch, 0.7, 1.4)
	player.play()


func play_drop_detach() -> void:
	play(Cue.DROP_DETACH, randf_range(0.94, 1.08))


func play_tendril_snap() -> void:
	play(Cue.TENDRIL_SNAP, randf_range(0.95, 1.08))


func play_victory() -> void:
	play(Cue.VICTORY, 1.0)
