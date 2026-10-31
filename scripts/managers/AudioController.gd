extends Node

## Level bed plus short cues. The drop plays on a cavern reverb bus.

enum Cue {
	DROP_FORM,
	DROP_DETACH,
	DROP_SPLASH,
	TENDRIL_STRAIN,
	TENDRIL_SNAP,
	CORE_ABSORB,
	VICTORY,
}

const STREAMS := {
	Cue.DROP_FORM: "res://assets/audio/drop_form.wav",
	Cue.DROP_DETACH: "res://assets/audio/drop_detach.wav",
	Cue.DROP_SPLASH: "res://assets/audio/drop_splash.wav",
	Cue.TENDRIL_SNAP: "res://assets/audio/snap.wav",
	Cue.CORE_ABSORB: "res://assets/audio/absorb.wav",
	Cue.VICTORY: "res://assets/audio/complete.wav",
}

const BED := "res://assets/audio/level0_bed.wav"
const WATER_BUS := "Water"

var _players: Dictionary = {}
var _bed: AudioStreamPlayer
var _web_unlocked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_water_bus()
	for cue in range(Cue.size()):
		var player := AudioStreamPlayer.new()
		player.bus = WATER_BUS if _is_drop_cue(cue) else "Master"
		player.volume_db = -6.0 if _is_drop_cue(cue) else -10.0
		if STREAMS.has(cue):
			player.stream = load(STREAMS[cue])
		add_child(player)
		_players[cue] = player
	_bed = AudioStreamPlayer.new()
	_bed.bus = "Master"
	_bed.volume_db = -14.0
	_bed.stream = _looping_bed()
	add_child(_bed)
	play_bed()


func _input(event: InputEvent) -> void:
	if _web_unlocked or OS.get_name() != "Web":
		return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		_web_unlocked = true
		if _bed and _bed.stream:
			_bed.play(_bed.get_playback_position())


func play_bed() -> void:
	if _bed.stream == null:
		_bed.stream = _looping_bed()
	if _bed.stream == null:
		return
	if not _bed.playing:
		_bed.volume_db = -14.0
		_bed.play()
	elif _bed.volume_db < -22.0:
		var tween := create_tween()
		tween.tween_property(_bed, "volume_db", -14.0, 1.2)


func stop_bed() -> void:
	_bed.stop()


func duck_bed() -> void:
	var tween := create_tween()
	tween.tween_property(_bed, "volume_db", -28.0, 0.8)


func play(cue: Cue, pitch: float = 1.0) -> void:
	var player: AudioStreamPlayer = _players.get(cue)
	if player == null or player.stream == null:
		return
	player.pitch_scale = clampf(pitch, 0.7, 1.4)
	player.play()


func play_drop_detach() -> void:
	play(Cue.DROP_DETACH, randf_range(0.94, 1.08))


func play_tendril_snap() -> void:
	play(Cue.TENDRIL_SNAP, randf_range(0.96, 1.05))


func play_victory() -> void:
	play(Cue.VICTORY, 1.0)


func _is_drop_cue(cue: int) -> bool:
	return cue == Cue.DROP_FORM or cue == Cue.DROP_DETACH or cue == Cue.DROP_SPLASH or cue == Cue.CORE_ABSORB


func _looping_bed() -> AudioStream:
	var loaded := load(BED)
	if loaded is AudioStreamWAV:
		var wav := loaded as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		# loop_end is a frame index, not seconds. A short index turns the bed into a beep.
		var frames := int(round(wav.get_length() * float(wav.mix_rate)))
		if frames > 1:
			wav.loop_begin = 0
			wav.loop_end = frames - 1
		return wav
	return loaded


func _ensure_water_bus() -> void:
	var index := AudioServer.get_bus_index(WATER_BUS)
	if index == -1:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, WATER_BUS)
	AudioServer.set_bus_send(index, "Master")
	AudioServer.set_bus_volume_db(index, 0.0)
	if AudioServer.get_bus_effect_count(index) > 0:
		return
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.62
	reverb.damping = 0.35
	reverb.spread = 0.8
	reverb.hipass = 0.12
	reverb.dry = 0.82
	reverb.wet = 0.28
	reverb.predelay_msec = 18.0
	reverb.predelay_feedback = 0.08
	AudioServer.add_bus_effect(index, reverb)
