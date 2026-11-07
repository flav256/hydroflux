extends LevelBase

## Level 0 — The First Drop. Observation, tendril invite, first launch.

enum LevelPhase {
	PHASE_1_OBSERVATION,
	PHASE_2_TENDRIL_INTRO,
	PHASE_3_LAUNCH_AND_VICTORY,
}

@export var droplet_scene: PackedScene
@export var auto_spawn_interval: float = 4.0

var current_phase: LevelPhase = LevelPhase.PHASE_1_OBSERVATION
var victory_started: bool = false
var live_drop: Gloop
var respawn_wait: float = 0.0
var misses: int = 0
var started_ms: int = 0

const QUICK_MISS_RESPAWN_DELAY: float = 0.55
const RESTING_SURFACE_RESPAWN_DELAY: float = 1.2

@onready var spawner: Marker2D = $Spawner_Phase1
@onready var tendril: ElasticTendril = $ElasticTendril
@onready var target_core: TargetCore = $TargetCore
@onready var camera: Camera2D = $Camera2D
@onready var hint: Label = $HUD/Hint
@onready var map_button: Button = $HUD/MapButton


func _ready() -> void:
	level_id = "level_00"
	started_ms = Time.get_ticks_msec()
	AudioController.play_bed()
	setup_light_room()
	if tendril:
		tendril.tendril_stretched.connect(_on_tendril_stretched)
		tendril.tendril_released.connect(_on_tendril_released)
	if target_core:
		target_core.core_activated.connect(_on_target_activated)
	if map_button:
		map_button.pressed.connect(_on_map_pressed)
	if has_node("Tooth"):
		$Tooth.add_to_group("tooth")
	if has_node("Roof"):
		$Roof.add_to_group("roof")
	get_tree().create_timer(1.2).timeout.connect(spawn_first_drop)


func spawn_first_drop() -> void:
	_spawn_drop(true)
	current_phase = LevelPhase.PHASE_2_TENDRIL_INTRO


func _spawn_drop(form: bool) -> void:
	if droplet_scene == null or spawner == null:
		return
	if is_instance_valid(live_drop) and not live_drop.is_absorbed:
		return
	var droplet: Gloop = droplet_scene.instantiate()
	droplet.global_position = spawner.global_position
	add_child(droplet)
	live_drop = droplet
	if form and droplet.has_method("begin_formation"):
		droplet.begin_formation()


func _process(delta: float) -> void:
	if victory_started:
		return
	var fell := _drop_missed()
	if fell and target_core and not target_core.is_active:
		respawn_wait += delta
		var respawn_delay := QUICK_MISS_RESPAWN_DELAY
		if (
			is_instance_valid(live_drop)
			and live_drop.moment != Gloop.Moment.FILM
			and not live_drop.on_membrane
			and live_drop.linear_velocity.length() < 25.0
		):
			respawn_delay = RESTING_SURFACE_RESPAWN_DELAY
		if respawn_wait > respawn_delay:
			respawn_wait = 0.0
			misses += 1
			if is_instance_valid(live_drop):
				live_drop.queue_free()
			live_drop = null
			_spawn_drop(true)
	else:
		respawn_wait = 0.0
	if hint:
		hint.text = _hint_line()


func _hint_line() -> String:
	if victory_started:
		return "The well is lit."
	if not is_instance_valid(live_drop):
		return "A light gathers in the dark."
	if live_drop.moment == Gloop.Moment.FILM:
		return live_drop.surface_line()
	if live_drop.is_forming:
		return "A light gathers in the dark."
	if tendril and tendril.is_dragged:
		return "The vine holds its breath."
	if respawn_wait > 0.0:
		return "The dark takes it back."
	if live_drop.on_membrane:
		if live_drop.mood == Gloop.Mood.IMPATIENT:
			return "It looks for your hand."
		return "It waits in the curve."
	if live_drop.linear_velocity.length() > 80.0:
		return "It is given to the air."
	if live_drop.global_position.y < 340.0:
		return "It lets go of the tooth."
	return "It looks for the vine."


func _drop_missed() -> bool:
	if not is_instance_valid(live_drop) or live_drop.is_absorbed or live_drop.is_forming:
		return false
	if live_drop.moment == Gloop.Moment.FILM:
		return live_drop.global_position.y > 690.0
	var p := live_drop.global_position
	# The floor sits above the old cutoff, so a missed drop used to rest there forever.
	if p.y > 690.0 or p.x < -20.0 or p.x > 1300.0:
		return true
	if live_drop.membrane_cooldown <= 0.0 and live_drop.linear_velocity.length() < 25.0:
		if tendril and not tendril.seated_drops.has(live_drop) and p.y > 520.0:
			return true
	return false


func _on_tendril_stretched(_disp: Vector2, _ratio: float) -> void:
	if current_phase == LevelPhase.PHASE_2_TENDRIL_INTRO:
		current_phase = LevelPhase.PHASE_3_LAUNCH_AND_VICTORY


func _on_tendril_released(_impulse: Vector2) -> void:
	pass


func _on_map_pressed() -> void:
	GameManager.open_level_select()


func _on_target_activated() -> void:
	if victory_started:
		return
	victory_started = true
	var seconds := (Time.get_ticks_msec() - started_ms) / 1000.0
	var result := GameManager.record_level(level_id, misses, seconds)
	AudioController.duck_bed()
	AudioController.play_victory()
	var tween := create_tween().set_parallel(true)
	tween.tween_property($CanvasModulate, "color", Color(1.45, 1.55, 1.6, 1.0), 1.4)
	if camera:
		tween.tween_property(camera, "zoom", Vector2(1.08, 1.08), 1.6).set_trans(Tween.TRANS_CUBIC)
	var room := room_material()
	if room:
		tween.tween_property(room, "shader_parameter/ambient", bloom_ambient, 2.2).set_trans(Tween.TRANS_SINE)
	_show_result(result)
	await get_tree().create_timer(4.4).timeout
	if is_inside_tree():
		GameManager.open_level_select()


func _show_result(result: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.28)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = "The well is lit"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.85, 0.97, 1))
	title.position = Vector2(340, 230)
	title.size = Vector2(600, 56)
	layer.add_child(title)
	var stars := Label.new()
	var row := ""
	for i in 3:
		row += "★  " if i < int(result["stars"]) else "☆  "
	stars.text = row
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars.add_theme_font_size_override("font_size", 42)
	stars.add_theme_color_override("font_color", Color(0.95, 0.88, 0.45))
	stars.position = Vector2(340, 300)
	stars.size = Vector2(600, 64)
	stars.scale = Vector2(0.4, 0.4)
	stars.pivot_offset = Vector2(300, 32)
	layer.add_child(stars)
	var note := Label.new()
	var bits: PackedStringArray = []
	if result["clean"]:
		bits.append("few misses")
	if result["fast"]:
		bits.append("quick")
	var why := ""
	if bits.size() > 0:
		why = "  ·  " + ", ".join(bits)
	note.text = "%d points%s" % [int(result["points"]), why]
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 18)
	note.add_theme_color_override("font_color", Color(0.8, 0.9, 0.92, 0.85))
	note.position = Vector2(340, 380)
	note.size = Vector2(600, 40)
	layer.add_child(note)
	var pop := create_tween()
	pop.tween_property(stars, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
