extends Node

## Dev only. Loads Level 0, then pulls and releases the vine once, so the
## light pass can be recorded without a hand: run with --write-movie.

@export var pull: Vector2 = Vector2(-70.0, 110.0)
@export var release_after: float = 3.6


func _ready() -> void:
	var level: Node = load("res://scenes/levels/Level_00.tscn").instantiate()
	add_child(level)
	await get_tree().create_timer(release_after).timeout
	var vine := level.get_node("ElasticTendril") as ElasticTendril
	vine._begin_drag(vine.rest_midpoint + pull, -1)
	await get_tree().create_timer(0.4).timeout
	vine._release_tendril()
