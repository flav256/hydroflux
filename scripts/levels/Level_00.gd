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
var live_drop: FluidDroplet
var respawn_wait: float = 0.0

@onready var spawner: Marker2D = $Spawner_Phase1
@onready var tendril: ElasticTendril = $ElasticTendril
@onready var target_core: TargetCore = $TargetCore
@onready var camera: Camera2D = $Camera2D
@onready var hint: Label = $HUD/Hint


func _ready() -> void:
	level_id = "level_00"
	if tendril:
		tendril.tendril_stretched.connect(_on_tendril_stretched)
		tendril.tendril_released.connect(_on_tendril_released)
	if target_core:
		target_core.core_activated.connect(_on_target_activated)
	get_tree().create_timer(1.2).timeout.connect(spawn_first_drop)


func spawn_first_drop() -> void:
	_spawn_drop(true)
	current_phase = LevelPhase.PHASE_2_TENDRIL_INTRO


func _spawn_drop(form: bool) -> void:
	if droplet_scene == null or spawner == null:
		return
	if is_instance_valid(live_drop) and not live_drop.is_absorbed:
		return
	var droplet: FluidDroplet = droplet_scene.instantiate()
	droplet.global_position = spawner.global_position
	add_child(droplet)
	live_drop = droplet
	if form and droplet.has_method("begin_formation"):
		droplet.begin_formation()


func _process(delta: float) -> void:
	if victory_started:
		return
	var lost := not is_instance_valid(live_drop) or live_drop.is_absorbed or live_drop.global_position.y > 820.0
	if lost and target_core and not target_core.is_active:
		respawn_wait += delta
		if respawn_wait > 1.1:
			respawn_wait = 0.0
			_spawn_drop(true)
	else:
		respawn_wait = 0.0
	if hint:
		hint.text = _hint_line()


func _hint_line() -> String:
	if victory_started:
		return "The well is lit."
	if not is_instance_valid(live_drop) or live_drop.is_forming:
		return "A light is forming."
	if tendril and tendril.is_dragged:
		return "Release."
	if live_drop.global_position.y > 680.0:
		return "Pull back, away from the ring, then let go."
	if live_drop.linear_velocity.length() < 45.0 and live_drop.global_position.y > 320.0:
		return "Pull the vine back, then release."
	return "Let it reach the vine."


func _on_tendril_stretched(_disp: Vector2, _ratio: float) -> void:
	if current_phase == LevelPhase.PHASE_2_TENDRIL_INTRO:
		current_phase = LevelPhase.PHASE_3_LAUNCH_AND_VICTORY


func _on_tendril_released(_impulse: Vector2) -> void:
	pass


func _on_target_activated() -> void:
	if victory_started:
		return
	victory_started = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property($CanvasModulate, "color", Color(1.4, 1.5, 1.55, 1.0), 2.0)
	if camera:
		tween.tween_property(camera, "zoom", Vector2(1.1, 1.1), 2.5).set_trans(Tween.TRANS_CUBIC)
	on_level_complete()
