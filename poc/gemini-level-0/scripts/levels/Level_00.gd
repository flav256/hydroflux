extends Node2D

## HydroFlux - Level 0: The First Drop
## Narrative-driven atmospheric tutorial coordinator.
## Guides player through observation, tendril interaction, and first slingshot launch.

enum LevelPhase {
	PHASE_1_OBSERVATION,
	PHASE_2_TENDRIL_INTRO,
	PHASE_3_LAUNCH_AND_VICTORY
}

@export var droplet_scene: PackedScene
@export var auto_spawn_interval: float = 4.0

var current_phase: LevelPhase = LevelPhase.PHASE_1_OBSERVATION
var spawn_timer: float = 0.0

@onready var spawner: Marker2D = $Spawner_Phase1
@onready var tendril: ElasticTendril = $ElasticTendril
@onready var target_core: TargetCore = $TargetCore
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	# Connect signals
	if tendril:
		tendril.tendril_stretched.connect(_on_tendril_stretched)
		tendril.tendril_released.connect(_on_tendril_released)
		
	if target_core:
		target_core.core_activated.connect(_on_target_activated)
		
	# Phase 1: Spawn initial observation droplet after 1.2s delay
	get_tree().create_timer(1.2).timeout.connect(spawn_first_drop)

func spawn_first_drop() -> void:
	if not droplet_scene or not spawner:
		return
	var droplet: RigidBody2D = droplet_scene.instantiate()
	droplet.global_position = spawner.global_position
	add_child(droplet)
	
	# In Phase 1, wait for droplet to fall into lower basin, then transition to Phase 2
	if current_phase == LevelPhase.PHASE_1_OBSERVATION:
		get_tree().create_timer(4.0).timeout.connect(_advance_to_phase_2)

func _advance_to_phase_2() -> void:
	current_phase = LevelPhase.PHASE_2_TENDRIL_INTRO
	# Pulse tendril aura to invite player touch
	if tendril:
		var tween: Tween = create_tween().set_loops(3)
		tween.tween_property(tendril, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.6)
		tween.tween_property(tendril, "modulate", Color.WHITE, 0.6)
	
	# Spawn continuous drops for slingshot practice
	_spawn_continuous_drop()

func _spawn_continuous_drop() -> void:
	if current_phase == LevelPhase.PHASE_1_OBSERVATION:
		return
	var droplet: RigidBody2D = droplet_scene.instantiate()
	droplet.global_position = spawner.global_position
	add_child(droplet)

func _process(delta: float) -> void:
	if current_phase >= LevelPhase.PHASE_2_TENDRIL_INTRO and target_core and not target_core.is_active:
		spawn_timer += delta
		if spawn_timer >= auto_spawn_interval:
			spawn_timer = 0.0
			_spawn_continuous_drop()

func _on_tendril_stretched(_disp: Vector2, _ratio: float) -> void:
	if current_phase == LevelPhase.PHASE_2_TENDRIL_INTRO:
		current_phase = LevelPhase.PHASE_3_LAUNCH_AND_VICTORY

func _on_tendril_released(_impulse: Vector2) -> void:
	pass

func _on_target_activated() -> void:
	# Cavern illumination and stage complete
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property($CanvasModulate, "color", Color(0.18, 0.22, 0.25, 1.0), 2.0)
	if camera:
		tween.tween_property(camera, "zoom", Vector2(1.1, 1.1), 2.5).set_trans(Tween.TRANS_CUBIC)
	
	# Transition to Level 1
	get_tree().create_timer(3.5).timeout.connect(func():
		print("HydroFlux: Level 0 complete. Loading Level 1...")
	)
