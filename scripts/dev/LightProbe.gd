extends Node

## Dev only. Loads Level 0, then pulls and releases the vine once, so the
## light pass can be recorded without a hand: run with --write-movie.

@export var pull: Vector2 = Vector2(-145.0, 54.0)
@export var release_after: float = 3.6


var _trace := false
var _t0 := -1.0
var _next := 0.0
var _gloop: Gloop = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pull="):
			var p := a.substr(7).split(",")
			pull = Vector2(float(p[0]), float(p[1]))
		elif a == "--trace":
			_trace = true
	var level: Node = load("res://scenes/levels/Level_00.tscn").instantiate()
	add_child(level)
	if _trace:
		var core := get_tree().get_first_node_in_group("target_core")
		if core == null:
			core = level.find_child("TargetCore", true, false)
		if core and core.has_signal("core_activated"):
			core.connect("core_activated", func(): print("core_activated at t=%.2f" % _t0))
	await get_tree().create_timer(release_after).timeout
	var vine := level.get_node("ElasticTendril") as ElasticTendril
	vine._begin_drag(vine.rest_midpoint + pull, -1)
	await get_tree().create_timer(0.4).timeout
	vine._release_tendril()
	_t0 = 0.0
	_gloop = get_tree().get_first_node_in_group("gloop") as Gloop


func _process(d: float) -> void:
	if not _trace or _t0 < 0.0:
		return
	_t0 += d
	var t := _t0
	if t > 3.5 or t < _next:
		return
	_next += 0.1
	if not is_instance_valid(_gloop):
		_gloop = get_tree().get_first_node_in_group("gloop") as Gloop
		if _gloop == null:
			return
	if _gloop.moment == Gloop.Moment.FILM:
		print("t=%.1f pos=(%.0f,%.0f) FILM film_vel=(%.0f,%.0f)|%.0f| spread=%.2f" % [t, _gloop.global_position.x, _gloop.global_position.y, _gloop.film_vel.x, _gloop.film_vel.y, _gloop.film_vel.length(), _gloop.film_spread])
	else:
		print("t=%.1f pos=(%.0f,%.0f) moment=%d vel=(%.0f,%.0f)|%.0f| spread=%.2f" % [t, _gloop.global_position.x, _gloop.global_position.y, _gloop.moment, _gloop.linear_velocity.x, _gloop.linear_velocity.y, _gloop.linear_velocity.length(), _gloop.film_spread])
