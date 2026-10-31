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
var spawn_timer: float = 0.0
var victory_started: bool = false

@onready var spawner: Marker2D = $Spawner_Phase1
@onready var tendril: ElasticTendril = $ElasticTendril
@onready var target_core: TargetCore = $TargetCore
@onready var camera: Camera2D = $Camera2D


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
	if current_phase == LevelPhase.PHASE_1_OBSERVATION:
		get_tree().create_timer(4.2).timeout.connect(_advance_to_phase_2)


func _advance_to_phase_2() -> void:
	current_phase = LevelPhase.PHASE_2_TENDRIL_INTRO
	if tendril:
		var tween := create_tween().set_loops(3)
		tween.tween_property(tendril, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.6)
		tween.tween_property(tendril, "modulate", Color.WHITE, 0.6)
	_spawn_drop(true)


func _spawn_drop(form: bool) -> void:
	if droplet_scene == null or spawner == null:
		return
	var droplet: FluidDroplet = droplet_scene.instantiate()
	droplet.global_position = spawner.global_position
	add_child(droplet)
	if form and droplet.has_method("begin_formation"):
		droplet.begin_formation()


func _process(delta: float) -> void:
	if victory_started:
		return
	if current_phase >= LevelPhase.PHASE_2_TENDRIL_INTRO and target_core and not target_core.is_active:
		spawn_timer += delta
		if spawn_timer >= auto_spawn_interval:
			spawn_timer = 0.0
			_spawn_drop(true)


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
	tween.tween_property($CanvasModulate, "color", Color(0.18, 0.22, 0.25, 1.0), 2.0)
	if camera:
		tween.tween_property(camera, "zoom", Vector2(1.1, 1.1), 2.5).set_trans(Tween.TRANS_CUBIC)
	on_level_complete()
