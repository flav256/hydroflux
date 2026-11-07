extends RigidBody2D
class_name Gloop

## Bioluminescent drop: hang-and-form, detach, stretch-in-flight, splash squash.

signal splashed(at_position: Vector2, normal: Vector2)
signal absorbed_by_target(droplet: Gloop)
signal detached()

@export var droplet_color: Color = Color(0.02, 0.71, 0.83, 1.0)
@export var core_color: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var base_radius: float = 24.0
@export var max_velocity_stretch: float = 1.8
@export var form_duration: float = 0.85
@export var light_energy: float = 1.4

@export_group("Surface Response")
@export var film_impact_threshold: float = 70.0
@export var bead_impact_threshold: float = 160.0
@export var split_impact_threshold: float = 520.0
@export var spread_duration: float = 0.24
@export var surface_reform_rate: float = 0.52
@export var ceiling_hold_duration: float = 0.35
@export var ceiling_reform_rate: float = 1.1
@export var impact_keep: float = 0.7
@export var film_drag: float = 7.0
@export var bead_drag: float = 3.0
@export var ceiling_drag: float = 12.0
@export var stiction_speed: float = 14.0
@export var max_wall_film_radius: float = 4.5

enum Mood { QUIET, IMPATIENT, TICKLED, HELD, FLIGHT, FALL }
enum Moment { FREE, GLIDE, SPREAD, GATHER, SPLIT, FILM }

var is_absorbed: bool = false
var is_forming: bool = false
var form_t: float = 0.0
var impact_flatten: float = 0.0
var impact_normal: Vector2 = Vector2.UP
var membrane_cooldown: float = 0.0
var surface_velocity: Vector2 = Vector2.ZERO
var trail: Array[Vector2] = []

var mood: Mood = Mood.QUIET
var presence: float = 0.0
var idle_time: float = 0.0
var flight_time: float = 0.0
var falling_time: float = 0.0
var gaze: Vector2 = Vector2.ZERO
var giggle: float = 0.0
var seated_fresh: bool = false
var held: bool = false
var hold_dir: Vector2 = Vector2.ZERO
var shape_y: float = 1.0
var shape_v: float = 0.0
var slosh: Vector2 = Vector2.ZERO
var slosh_v: Vector2 = Vector2.ZERO
var prev_motion: Vector2 = Vector2.ZERO
var was_near: bool = false
var settled: float = 0.0
var glide_normal: Vector2 = Vector2.ZERO
var glide_hold: float = 0.0
var bead_pos: PackedVector2Array = PackedVector2Array()
var bead_vel: PackedVector2Array = PackedVector2Array()
var bead_life: PackedFloat32Array = PackedFloat32Array()
var previous_position: Vector2 = Vector2.ZERO
var on_membrane: bool = false
var membrane_touch: float = 0.0
var stone_grace: float = 0.0
var moment: Moment = Moment.FREE
var moment_t: float = 0.0
var split_from: Vector2 = Vector2.ZERO
var split_spots: Array[Vector2] = []
var touch_kind: String = ""
var touch_normal: Vector2 = Vector2.ZERO
var touch_impact_speed: float = 0.0
var velocity_before_contact: Vector2 = Vector2.ZERO
var film_spread: float = 0.0
var film_flat: float = 1.0
var film_normal: Vector2 = Vector2.UP
var film_pos: Vector2 = Vector2.ZERO
var film_vel: Vector2 = Vector2.ZERO
var _wet: Node = null

@onready var light: PointLight2D = get_node_or_null("PointLight2D")


func _ready() -> void:
	add_to_group("gloop")
	# Draw over the thick membrane so Gloop stays visible while it is seated in the curve.
	z_index = 6
	contact_monitor = true
	max_contacts_reported = 4
	gravity_scale = 1.45
	lock_rotation = true
	var film := PhysicsMaterial.new()
	film.friction = 0.04
	film.bounce = 0.0
	physics_material_override = film
	body_entered.connect(_on_body_entered)
	# Gloop is the light; it is not lit by it.
	light_mask = 0
	if light:
		light.color = droplet_color
		light.energy = light_energy
	previous_position = global_position


func begin_formation() -> void:
	is_forming = true
	form_t = 0.0
	freeze = true
	collision_layer = 0
	collision_mask = 0
	scale = Vector2(0.15, 0.35)
	if light:
		light.energy = 0.0
	AudioController.play(AudioController.Cue.DROP_FORM, randf_range(0.9, 1.1))


func ignore_membrane(duration: float) -> void:
	membrane_cooldown = duration


func _physics_process(delta: float) -> void:
	if membrane_cooldown > 0.0:
		membrane_cooldown = maxf(membrane_cooldown - delta, 0.0)
	if is_absorbed:
		return
	if is_forming:
		form_t += delta / maxf(form_duration, 0.05)
		var eased := smoothstep(0.0, 1.0, clampf(form_t, 0.0, 1.0))
		scale = Vector2(lerpf(0.15, 1.0, eased), lerpf(0.35, 1.05, eased))
		if light:
			light.energy = light_energy * eased
		if form_t >= 1.0:
			_detach()
	impact_flatten = move_toward(impact_flatten, 0.0, delta * 2.6)
	if is_forming:
		trail.clear()
	elif Engine.get_physics_frames() % 2 == 0:
		trail.append(global_position)
		if trail.size() > 8:
			trail.remove_at(0)
	_glide_on_stone(delta)
	_live(delta)
	_viscosity(delta)
	previous_position = global_position
	velocity_before_contact = linear_velocity
	queue_redraw()


func _detach() -> void:
	is_forming = false
	scale = Vector2.ONE
	freeze = false
	collision_layer = 2
	collision_mask = 13
	global_position.y = maxf(global_position.y, 188.0)
	linear_velocity = Vector2(0.0, 36.0)
	stone_grace = 0.45
	if light:
		light.energy = light_energy
	AudioController.play_drop_detach()
	detached.emit()


func ride_surface(velocity: Vector2, impact_speed: float) -> void:
	surface_velocity = velocity
	if impact_speed > 90.0:
		shape_v -= clampf(impact_speed / 220.0, 0.4, 2.4)
		slosh_v += Vector2(0.0, clampf(impact_speed / 900.0, 0.0, 1.6))


func feel(is_held: bool, pull: Vector2) -> void:
	seated_fresh = true
	on_membrane = true
	membrane_touch = 0.2
	held = is_held
	if moment == Moment.GLIDE:
		moment = Moment.FREE
		glide_normal = Vector2.ZERO
	if pull.length_squared() > 4.0:
		hold_dir = pull.normalized()


func _draw() -> void:
	if is_absorbed:
		return
	if moment == Moment.FILM:
		_draw_film()
		return
	var motion := linear_velocity
	if surface_velocity.length_squared() > motion.length_squared():
		motion = surface_velocity
	var now := Time.get_ticks_msec() * 0.001
	var speed := motion.length()
	var dir := Vector2.DOWN
	if speed > 36.0:
		dir = motion.normalized()
	var stretch := clampf(speed / 480.0, 0.0, 0.9)
	if freeze and not is_forming:
		stretch = 0.06 + sin(now * 3.4) * 0.035
	var step := 0
	for point in trail:
		step += 1
		var local := to_local(point)
		if local.length() < base_radius * 0.7:
			continue
		var fade := 1.0 - float(step) / float(trail.size() + 1)
		var thread := local * 0.42
		draw_line(thread, local, Color(droplet_color, 0.4 * fade), lerpf(1.1, 3.2, fade) * base_radius / 12.0, true)
		draw_circle(local, base_radius * lerpf(0.22, 0.48, fade), Color(droplet_color, 0.34 * fade))
	draw_circle(Vector2.ZERO, base_radius * 3.3, Color(droplet_color, 0.07))
	draw_circle(Vector2.ZERO, base_radius * 2.1, Color(droplet_color, 0.12))
	var sx := shape_x_now()
	var body := PackedVector2Array()
	for i in 40:
		var a := TAU * float(i) / 40.0
		var n := Vector2(cos(a), sin(a))
		var along := n.dot(dir)
		var side := n - dir * along
		var wide := base_radius * sx * (1.0 + stretch * 0.08)
		var tall := base_radius * shape_y
		var p := side * wide + dir * along * tall * (0.9 - stretch * 0.12)
		if along < 0.0:
			p += -dir * base_radius * (0.22 + stretch * 0.85) * (-along)
		var neck := clampf((stretch - 0.18) / 0.55, 0.0, 1.0)
		if along < 0.2 and along > -0.65:
			var pinch := 1.0 - neck * 0.62 * (1.0 - absf(along + 0.15) / 0.5)
			p = dir * p.dot(dir) + (p - dir * p.dot(dir)) * pinch
		p += n * sin(a * 3.0 + now * 6.5) * base_radius * (0.035 + giggle * 0.07)
		p += n * sin(a * 7.0 - now * 24.0) * base_radius * giggle * 0.055
		if settled > 0.25 and speed < 42.0 and n.y > 0.15 and glide_normal == Vector2.ZERO:
			var cap := base_radius * lerpf(1.02, 0.78, settled)
			if p.y > cap:
				p.y = lerpf(p.y, cap, settled)
				p.x *= lerpf(1.0, 1.14, settled * n.y)
		if glide_normal.length_squared() > 0.5:
			var into := -global_transform.basis_xform_inv(glide_normal)
			var depth := p.dot(into)
			if depth > 0.0:
				p -= into * depth * 0.7
				var along_stone := Vector2(-into.y, into.x)
				p += along_stone * depth * 0.35 * signf(p.dot(along_stone) + 0.001)
		# Flatten across the contact normal and widen along the surface without
		# changing the drawn area. This keeps gentle impacts watery instead of
		# making the drop visibly shrink on contact.
		if impact_flatten > 0.001:
			var normal_local := global_transform.basis_xform_inv(impact_normal).normalized()
			var normal_part := normal_local * p.dot(normal_local)
			var tangent_part := p - normal_part
			var tangent_scale := sqrt(1.0 + impact_flatten * 0.7)
			p = tangent_part * tangent_scale + normal_part / tangent_scale
		body.append(p)
	draw_colored_polygon(body, droplet_color)
	var inner := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		inner.append(slosh * 0.85 + Vector2(cos(a), sin(a)) * base_radius * 0.46 * Vector2(shape_x_now(), shape_y))
	draw_colored_polygon(inner, Color(0.55, 0.96, 1.0, 0.55))
	var gloss_center := Vector2(-base_radius * 0.14, -base_radius * 0.22) - dir * base_radius * 0.08
	draw_arc(
		gloss_center,
		base_radius * 0.47,
		PI * 1.13,
		PI * 1.73,
		12,
		Color(0.96, 1.0, 1.0, 0.42),
		maxf(base_radius * 0.055, 0.65),
		true
	)
	var glint := -dir * base_radius * 0.12 + Vector2(cos(now * 2.3), sin(now * 2.9)) * base_radius * 0.18
	draw_circle(glint, base_radius * 0.36, Color(0.9, 1.0, 1.0, 0.92))
	draw_circle(glint * 0.35, base_radius * 0.13, core_color)
	_draw_presence(now)
	for i in bead_pos.size():
		var fade := clampf(bead_life[i] / 0.35, 0.0, 1.0)
		draw_circle(to_local(bead_pos[i]), lerpf(1.2, 3.4, fade) * base_radius / 12.0, Color(droplet_color, 0.85 * fade))


func apply_launch_impulse(impulse: Vector2) -> void:
	if is_forming:
		_detach()
	freeze = false
	surface_velocity = Vector2.ZERO
	held = false
	seated_fresh = false
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	shape_v += clampf(impulse.length() / 380.0, 0.35, 1.7)
	apply_central_impulse(impulse)


func _viscosity(delta: float) -> void:
	if freeze or is_forming or is_absorbed:
		return
	if moment == Moment.FILM:
		return
	var drag := 0.22
	if moment == Moment.GLIDE:
		drag = 2.15
	elif on_membrane:
		return
	linear_velocity *= exp(-drag * delta)
	if moment == Moment.GLIDE:
		surface_velocity = linear_velocity


func _live(delta: float) -> void:
	membrane_touch = maxf(membrane_touch - delta, 0.0)
	if membrane_touch <= 0.0:
		on_membrane = false
	var motion := linear_velocity
	if surface_velocity.length_squared() > motion.length_squared():
		motion = surface_velocity
	var speed := motion.length()
	var on_vine := seated_fresh
	if not on_vine:
		held = false
	var airborne := not on_vine and not freeze and not is_forming and moment != Moment.FILM
	if airborne and speed > 90.0:
		flight_time += delta
	else:
		flight_time = move_toward(flight_time, 0.0, delta * 2.0)
	if airborne and linear_velocity.y > 100.0:
		falling_time += delta
	else:
		falling_time = move_toward(falling_time, 0.0, delta * 2.5)
	var near := false
	if not is_forming and not is_absorbed and InputManager.has_pointer:
		near = global_position.distance_to(InputManager.world_pointer) < base_radius * 3.8
	if near and not was_near and not held:
		giggle = 1.0
		shape_v += 0.9
	was_near = near and not held
	var tickled := near and not held and not is_forming
	giggle = move_toward(giggle, 1.0 if tickled else 0.0, delta * (1.5 if tickled else 1.1))
	var resting := on_vine and speed < 36.0 and not held and not is_forming
	if resting and not near:
		idle_time += delta
	else:
		idle_time = move_toward(idle_time, 0.0, delta * 2.4)
	var show := false
	var next := Mood.QUIET
	if held and on_vine:
		next = Mood.HELD
		show = true
	elif tickled:
		next = Mood.TICKLED
		show = true
	elif resting and idle_time > 1.15:
		next = Mood.IMPATIENT
		show = true
	elif airborne and falling_time > 0.28:
		next = Mood.FALL
		show = true
	elif airborne and speed > 90.0 and flight_time < 0.65:
		next = Mood.FLIGHT
		show = true
	mood = next
	var presence_target := 1.0 if show else 0.0
	if mood == Mood.FLIGHT:
		presence_target = clampf(1.0 - maxf(flight_time - 0.12, 0.0) / 0.53, 0.0, 1.0)
	presence = move_toward(presence, presence_target, delta * (4.0 if show else 1.3))
	var now := Time.get_ticks_msec() * 0.001
	var gaze_target := Vector2.ZERO
	if mood == Mood.IMPATIENT:
		gaze_target = Vector2(sin(now * 0.52) * 1.15, -1.5 + sin(now * 0.8) * 0.22)
	elif mood == Mood.HELD:
		gaze_target = hold_dir * 1.2
	elif mood == Mood.TICKLED:
		gaze_target = Vector2(sin(now * 8.0) * 0.3, -0.4)
	elif mood == Mood.FLIGHT:
		gaze_target = linear_velocity.normalized() * 1.15
	elif mood == Mood.FALL:
		gaze_target = Vector2(0.0, 1.3)
	gaze = gaze.lerp(gaze_target, 1.0 - exp(-5.0 * delta))
	settled = move_toward(settled, 1.0 if resting else 0.0, delta * 2.2)
	var target_y := 1.0
	var damp := 12.0
	if moment == Moment.GLIDE:
		target_y = 0.72
		damp = 16.0
	elif speed > 80.0:
		target_y = 1.0 + clampf(speed / 720.0, 0.0, 0.62)
		damp = 8.5
	elif on_vine and speed < 80.0:
		target_y = 0.94
	if mood == Mood.HELD:
		target_y = 0.98
		damp = 18.0
	shape_v += ((target_y - shape_y) * 58.0 - shape_v * damp) * delta
	shape_y = clampf(shape_y + shape_v * delta, 0.45, 2.15)
	var accel := (motion - prev_motion) / maxf(delta, 0.001)
	prev_motion = motion
	slosh_v += ((-accel * 0.0011) - slosh * 28.0 - slosh_v * 12.0) * delta
	slosh = (slosh + slosh_v * delta).limit_length(base_radius * 0.34)
	seated_fresh = false


func shape_x_now() -> float:
	return 1.0 / sqrt(maxf(shape_y, 0.42))


func _draw_presence(now: float) -> void:
	if presence < 0.03:
		return
	var open := 1.0
	if mood == Mood.TICKLED:
		open = 0.22
	elif mood == Mood.FLIGHT:
		open = 0.5
	elif mood == Mood.FALL:
		open = 1.18
	elif mood != Mood.HELD:
		var phase := fposmod(now + 0.4, 3.6)
		if phase < 0.14:
			open = phase / 0.14
		elif phase > 3.15:
			open = (3.6 - phase) / 0.45
	var gap := base_radius * 0.35
	var eye_axis := Vector2.RIGHT
	var eye_angle := 0.0
	if mood == Mood.FLIGHT:
		var travel := linear_velocity.normalized()
		if travel.length_squared() > 0.1:
			eye_axis = Vector2(-travel.y, travel.x)
			eye_angle = travel.angle() + PI * 0.5
			gap = base_radius * 0.26
	elif mood == Mood.FALL:
		gap = base_radius * 0.39
	if mood == Mood.HELD:
		gap = base_radius * 0.24
	elif mood == Mood.IMPATIENT:
		gap = base_radius * 0.40
	var origin := slosh * 1.2 + Vector2(0.0, base_radius * 0.1)
	var tilt := sin(now * 0.4) * 0.55 if mood == Mood.IMPATIENT else 0.0
	var ink := Color(0.012, 0.03, 0.045, 0.95 * presence)
	for side in [-1.0, 1.0]:
		var pos: Vector2 = origin + eye_axis * (side * gap) + Vector2(0.0, tilt * side * 2.0) + gaze * 0.3
		if mood == Mood.TICKLED:
			draw_arc(pos + Vector2(0.0, 1.0), 4.2, PI + 0.5, TAU - 0.5, 9, ink, 2.2, true)
		else:
			var ry := maxf(4.7 * open, 0.3)
			var rx := 3.6
			if mood == Mood.FLIGHT:
				rx = 3.3
				ry = maxf(5.0 * open, 0.3)
			_eye_disk(pos, rx, ry, ink, eye_angle)
			if open > 0.4:
				var pupil := gaze.limit_length(1.0)
				_eye_disk(pos + Vector2(pupil.x * 1.3, pupil.y * 0.9), 1.7, maxf(1.7 * open, 0.3), Color(0, 0, 0, presence), eye_angle)


func _eye_disk(center: Vector2, rx: float, ry: float, color: Color, angle: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	draw_colored_polygon(pts, color)


func absorb_into_target() -> void:
	if is_absorbed:
		return
	is_absorbed = true
	# freeze/collision changes are illegal inside a physics callback.
	set_deferred("freeze", true)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	if light:
		tween.tween_property(light, "energy", 0.0, 0.3)
	await tween.finished
	absorbed_by_target.emit(self)
	queue_free()


func _glide_on_stone(delta: float) -> void:
	angular_velocity = 0.0
	_step_beads(delta)
	if moment == Moment.FILM:
		flow_on_surface(delta)
		return
	if is_forming or is_absorbed or freeze:
		return
	if stone_grace > 0.0:
		stone_grace = maxf(stone_grace - delta, 0.0)
		return
	if touch_kind.is_empty() or touch_normal == Vector2.ZERO:
		return
	var impact_speed := touch_impact_speed
	touch_impact_speed = 0.0
	if impact_speed < film_impact_threshold:
		if impact_speed > 24.0:
			_impact_deform(touch_normal, impact_speed)
			_leave_wet(global_position - touch_normal * base_radius, Vector2(touch_normal.y, -touch_normal.x), base_radius * 2.0)
		return
	begin_film(touch_normal, impact_speed)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	state.angular_velocity = 0.0
	touch_kind = ""
	touch_normal = Vector2.ZERO
	touch_impact_speed = 0.0
	var rank := 0
	for i in state.get_contact_count():
		var other := state.get_contact_collider_object(i) as Node
		if other == null:
			continue
		var kind := ""
		var weight := 0
		if other.is_in_group("tooth"):
			kind = "tooth"
			weight = 3
		elif other.is_in_group("roof"):
			kind = "roof"
			weight = 2
		elif other is StaticBody2D:
			kind = "stone"
			weight = 1
		if weight <= rank:
			continue
		var normal: Vector2 = state.transform.basis_xform(state.get_contact_local_normal(i))
		# Godot returns the body's contact position in world coordinates already.
		var contact: Vector2 = state.get_contact_local_position(i)
		var toward := state.transform.origin - contact
		if normal.dot(toward) < 0.0:
			normal = -normal
		if normal.length_squared() < 0.0001:
			continue
		rank = weight
		touch_kind = kind
		touch_normal = normal.normalized()
	var incoming := velocity_before_contact
	if incoming.length_squared() < 0.01:
		incoming = state.linear_velocity
	touch_impact_speed = maxf(-incoming.dot(touch_normal), 0.0)


func _contact_kind() -> String:
	return touch_kind


func _stone_normal() -> Vector2:
	if touch_kind != "stone":
		return Vector2.ZERO
	return touch_normal


func begin_film(normal: Vector2, impact: float) -> void:
	moment = Moment.FILM
	moment_t = 0.0
	film_spread = 0.12
	film_normal = normal.normalized()
	film_flat = clampf(absf(film_normal.dot(Vector2.UP)), 0.0, 1.0)
	film_pos = global_position
	var along := velocity_before_contact - film_normal * velocity_before_contact.dot(film_normal)
	film_vel = along * impact_keep
	freeze = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_splash_on(film_normal, impact)


func flow_on_surface(delta: float) -> void:
	# One response for every surface. Flatness is how level the face is.
	# Gravity along the face carries the sheet. Surface tension pulls it back into one drop.
	moment_t += delta
	var gravity_y := float(ProjectSettings.get_setting("physics/2d/default_gravity")) * gravity_scale
	var gravity := Vector2(0.0, gravity_y)
	var tangent := gravity - film_normal * gravity.dot(film_normal)
	var flat := clampf(absf(film_normal.dot(Vector2.UP)), 0.0, 1.0)
	film_flat = flat
	var spill := 1.0 - flat
	var gather := lerpf(0.16, 1.55, flat) * lerpf(0.75, 1.7, 1.0 - film_spread)
	var is_ceiling := film_normal.dot(Vector2.DOWN) > 0.82
	# Momentum: gravity along the face accelerates the film, drag (stronger when gathered
	# into a bead the opposite way: bead runs faster) bleeds it. Ceilings cling hard.
	var drag := lerpf(bead_drag, film_drag, film_spread)
	if is_ceiling:
		drag = maxf(drag, ceiling_drag)
	film_vel += (tangent - drag * film_vel) * delta
	if moment_t < spread_duration:
		film_spread = move_toward(film_spread, 1.0, delta / maxf(spread_duration, 0.01))
	elif is_ceiling and moment_t < spread_duration + ceiling_hold_duration:
		film_spread = 1.0
	else:
		if is_ceiling:
			gather = minf(gather, ceiling_reform_rate)
		elif flat > 0.55:
			gather = minf(gather, surface_reform_rate)
		film_spread = move_toward(film_spread, 0.0, gather * delta)
	var space := get_world_2d().direct_space_state
	if space == null:
		_leave_surface(true)
		return
	var origin := film_pos + film_vel * delta
	var query := PhysicsRayQueryParameters2D.create(origin + film_normal * base_radius * (28.0 / 12.0), origin - film_normal * base_radius * (48.0 / 12.0))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		_leave_surface(true)
		return
	var found: Vector2 = hit.normal
	if found.dot(film_normal) < 0.0:
		found = -found
	film_normal = found.normalized()
	# Follow the curve: keep the speed, turn it onto the new tangent.
	var speed_along := film_vel.length()
	var turned := film_vel - film_normal * film_vel.dot(film_normal)
	film_vel = turned.normalized() * speed_along if turned.length_squared() > 0.000001 else Vector2.ZERO
	flat = clampf(absf(film_normal.dot(Vector2.UP)), 0.0, 1.0)
	film_flat = flat
	if flat > 0.94 and film_vel.length() < stiction_speed:
		film_vel = Vector2.ZERO
	var hug := lerpf(base_radius * 0.42, base_radius, 1.0 - film_spread)
	film_pos = hit.position + film_normal * hug
	var wet_span := lerpf(base_radius, base_radius * lerpf(max_wall_film_radius, 6.6, film_flat), film_spread) * 2.0
	_leave_wet(hit.position, Vector2(film_normal.y, -film_normal.x), wet_span)
	global_position = film_pos
	var peel := gravity.dot(film_normal)
	if is_ceiling and moment_t >= spread_duration + ceiling_hold_duration and film_spread < 0.08:
		_leave_surface(true)
	elif film_spread < 0.1 and peel > 90.0:
		_leave_surface(true)
	elif film_spread < 0.08 and flat > 0.82 and peel <= 0.0:
		_leave_surface(false)


func _leave_surface(falling: bool) -> void:
	moment = Moment.FREE
	freeze = false
	collision_layer = 2
	collision_mask = 13
	stone_grace = 0.45
	glide_normal = Vector2.ZERO
	global_position = film_pos + film_normal * base_radius * 0.5
	# Small push off the face: full 40 px/s from a near-still film (roof drip), fading to 5% of
	# the film's speed when it leaves a fast slide, so the hand-off stays continuous.
	var carried := film_vel.length()
	var push := lerpf(40.0, carried * 0.05, smoothstep(40.0, 120.0, carried))
	linear_velocity = film_vel + (film_normal * push if falling else Vector2.ZERO)
	film_vel = Vector2.ZERO
	film_spread = 0.0


func surface_line() -> String:
	if film_spread > 0.62:
		return "It opens where it lands."
	if film_flat > 0.78:
		if film_spread > 0.2:
			return "It finds the low place."
		return "It is one drop again."
	if film_flat < 0.32:
		return "It spills, slowly."
	return "It follows the slope."


func _draw_film() -> void:
	var normal := film_normal
	var tangent := Vector2(normal.y, -normal.x)
	if tangent.dot(Vector2.DOWN) < 0.0:
		tangent = -tangent
	var max_spread_radius := lerpf(max_wall_film_radius, 6.6, film_flat)
	var wide := lerpf(base_radius, base_radius * max_spread_radius, film_spread)
	# Keep the 2D liquid area close to the round drop as the sheet widens.
	var thick := base_radius * base_radius / maxf(wide, base_radius)
	var body := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		var wobble := 1.0 + sin(a * 3.0 + moment_t * 5.0) * film_spread * 0.035
		body.append(tangent * cos(a) * wide * wobble + normal * sin(a) * thick)
	draw_colored_polygon(body, droplet_color)
	var reflection := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		reflection.append(tangent * (-wide * 0.08 + cos(a) * wide * 0.32) + normal * (thick * 0.3 + sin(a) * thick * 0.22))
	draw_colored_polygon(reflection, Color(0.55, 0.96, 1.0, 0.38))
	var sheen := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		var u := lerpf(-0.34, 0.16, t)
		var v := 0.52 + sin(t * PI) * 0.1
		sheen.append(tangent * wide * u + normal * thick * v)
	draw_polyline(sheen, Color(0.98, 1.0, 1.0, 0.5), maxf(base_radius * 0.045, 0.55), true)
	for i in bead_pos.size():
		var fade := clampf(bead_life[i] / 0.7, 0.0, 1.0)
		draw_circle(to_local(bead_pos[i]), lerpf(1.2, 3.6, fade) * base_radius / 12.0, Color(droplet_color, 0.8 * fade))


func _splash_on(normal: Vector2, speed: float) -> void:
	_impact_deform(normal, speed)
	var count := 0
	if speed >= split_impact_threshold:
		count = 5
	elif speed >= bead_impact_threshold:
		count = 2
	var tangent := Vector2(normal.y, -normal.x)
	for i in count:
		var side := -1.0 if i < count / 2 else 1.0
		bead_pos.append(global_position - normal * base_radius * 0.2)
		bead_vel.append(tangent * side * randf_range(30.0, 110.0) + normal * randf_range(40.0, 130.0))
		bead_life.append(randf_range(1.35, 1.9))
	if speed > 90.0:
		splashed.emit(global_position, normal)
		AudioController.play(AudioController.Cue.DROP_SPLASH, randf_range(0.94, 1.08))


func _impact_deform(normal: Vector2, speed: float) -> void:
	var strength := clampf(speed / 760.0, 0.0, 1.0)
	impact_flatten = maxf(impact_flatten, strength)
	impact_normal = normal.normalized()
	shape_v -= lerpf(0.08, 2.4, strength)
	slosh_v += -normal * lerpf(0.03, 1.2, strength)


func _step_beads(delta: float) -> void:
	var kept_pos := PackedVector2Array()
	var kept_vel := PackedVector2Array()
	var kept_life := PackedFloat32Array()
	for i in bead_pos.size():
		var life := bead_life[i] - delta
		var pull := global_position - bead_pos[i]
		var dist := pull.length()
		if dist < base_radius * 1.25:
			continue
		if life <= 0.0:
			life = 0.24
		var velocity: Vector2 = bead_vel[i] + Vector2(0.0, 220.0) * delta
		velocity += pull / dist * 460.0 * delta
		velocity *= exp(-2.4 * delta)
		kept_pos.append(bead_pos[i] + velocity * delta)
		kept_vel.append(velocity)
		kept_life.append(life)
	bead_pos = kept_pos
	bead_vel = kept_vel
	bead_life = kept_life


func _on_body_entered(body: Node) -> void:
	if is_forming or is_absorbed:
		return
	if body is StaticBody2D:
		return
	var speed := linear_velocity.length()
	var normal := -linear_velocity.normalized() if speed > 0.01 else Vector2.UP
	_impact_deform(normal, speed)
	if speed > 180.0:
		splashed.emit(global_position, -linear_velocity.normalized())
		AudioController.play(AudioController.Cue.DROP_SPLASH, randf_range(0.92, 1.12))


func _leave_wet(at: Vector2, along: Vector2, width: float) -> void:
	# Wet stone keeps a little of the light (WetGlow), so a miss still maps the room.
	if not is_instance_valid(_wet):
		_wet = get_tree().get_first_node_in_group("wet_glow")
		if _wet == null:
			return
	_wet.call("mark", at, along, width)
