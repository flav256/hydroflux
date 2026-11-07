extends Area2D
class_name TargetCore

## The well: a closed seed that drinks the light. Dormant it breathes, thirsty it
## loosens toward a nearby Gloop, fed it blooms and glowing veins run into the rock.

signal core_activated
signal fluid_received(current_amount: int, required_amount: int)

@export var required_fluid_volume: int = 1
@export var glow_color: Color = Color(0.02, 0.71, 0.83, 1.0)
@export var core_radius: float = 42.0
## Distance at which a Gloop makes the well thirsty.
@export var thirst_radius: float = 220.0
@export var petal_count: int = 6
@export var bloom_time: float = 1.2
@export var vein_count: int = 4
@export var vein_length_min: float = 150.0
@export var vein_length_max: float = 250.0
@export var dormant_energy: float = 0.45
@export var thirsty_energy: float = 0.75
@export var fed_energy: float = 2.4
@export var dormant_light_scale: float = 2.2
@export var fed_light_scale: float = 3.6

var current_volume: int = 0
var is_active: bool = false
var pulse_time: float = 0.0

var _thirst: float = 0.0       # 0..1 eased proximity
var _lean: Vector2 = Vector2.ZERO  # eased direction*strength toward Gloop
var _bloom: float = 0.0        # 0..~1.1 (overshoots), tweened on activation
var _fed: float = 0.0          # 0..1 brightness/color mix
var _vein_t: float = 0.0       # 0..1 growth
var _flash: float = 0.0        # per-absorb pulse
var _veins: Array = []
var _idle_accum: float = 0.0

@onready var light: PointLight2D = get_node_or_null("CoreGlowLight")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	core_activated.connect(_on_activated)
	_build_veins()
	_apply_light()


func _build_veins() -> void:
	## Roots from the bulb's base, mostly down/sideways (within ~75 deg of straight down),
	## smooth low-frequency wander, asymmetric, each with 1-2 short side branches.
	_veins.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919
	var n := maxi(1, vein_count)
	var base := Vector2(0.0, core_radius * 0.5)
	var max_head := deg_to_rad(75.0)
	for i in n:
		var frac := (float(i) + 0.5) / float(n)
		var head0 := clampf(lerpf(-max_head, max_head, frac) + rng.randf_range(-0.22, 0.22), -max_head, max_head)
		var length := rng.randf_range(vein_length_min, vein_length_max)
		var amp := rng.randf_range(0.2, 0.45)
		var freq := rng.randf_range(1.4, 2.6)
		var phase := rng.randf_range(0.0, TAU)
		var start := base + Vector2(head0 * 6.0, 0.0)
		var main := _root_path(start, head0, length, amp, freq, phase, max_head)
		_veins.append({"pts": main, "w": 4.0, "start": 0.0})
		for b in rng.randi_range(1, 2):
			var at := rng.randf_range(0.3, 0.7)
			var idx := int(at * (main.size() - 1))
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var bh := clampf(head0 + side * rng.randf_range(0.5, 0.9), -1.5, 1.5)
			var bp := _root_path(main[idx], bh, length * rng.randf_range(0.25, 0.4),
				rng.randf_range(0.1, 0.25), rng.randf_range(1.5, 2.5), rng.randf_range(0.0, TAU), 1.5)
			_veins.append({"pts": bp, "w": 2.2, "start": at * 0.7})


func _root_path(from: Vector2, head0: float, length: float, amp: float, freq: float, phase: float, limit: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 22
	var pos := from
	for s in steps + 1:
		pts.append(pos)
		var t := float(s) / float(steps)
		var h := clampf(head0 + amp * sin(t * freq * PI + phase) * t, -limit, limit)
		pos += Vector2(sin(h), cos(h)) * (length / float(steps))
	return pts


func _process(delta: float) -> void:
	pulse_time += delta
	var target_thirst := 0.0
	var target_lean := Vector2.ZERO
	if not is_active:
		var best := thirst_radius
		for node in get_tree().get_nodes_in_group("gloop"):
			var g := node as Node2D
			if g == null or (g is Gloop and (g as Gloop).is_absorbed):
				continue
			var d := global_position.distance_to(g.global_position)
			if d < best:
				best = d
				target_thirst = 1.0 - d / thirst_radius
				target_lean = (g.global_position - global_position).normalized() * target_thirst
	var k := 1.0 - exp(-delta * 3.0)
	var prev_thirst := _thirst
	var prev_lean := _lean
	_thirst = lerpf(_thirst, target_thirst, k)
	_lean = _lean.lerp(target_lean, k)
	_flash = maxf(0.0, _flash - delta * 2.0)
	_apply_light()
	# Redraw every frame while visibly animating, ~20 Hz for the idle breathing.
	_idle_accum += delta
	var moving := is_active or _flash > 0.0 \
		or absf(_thirst - prev_thirst) > 0.0005 or prev_lean.distance_to(_lean) > 0.0005
	if moving or _idle_accum >= 0.05:
		_idle_accum = 0.0
		queue_redraw()


func _apply_light() -> void:
	if light == null:
		return
	var base := lerpf(dormant_energy, thirsty_energy, _thirst)
	light.energy = lerpf(base, fed_energy, _fed) + _flash * 1.5
	light.texture_scale = lerpf(dormant_light_scale, fed_light_scale, _fed)
	light.color = Color(0.0235294, 0.713726, 0.831373).lerp(glow_color, _fed)


func _breath() -> float:
	return 1.0 + sin(pulse_time * TAU / 4.0) * 0.03


func _draw() -> void:
	var open := clampf(_thirst * 0.14, 0.0, 1.0) + _bloom
	var breath := _breath()
	var fed := _fed
	var R := core_radius
	var rim_a := 0.28 + 0.25 * _thirst + 0.5 * fed + _flash * 0.3
	var rim_col := Color(glow_color.r, glow_color.g, glow_color.b, 1.0)
	var base := Vector2(0.0, R * 0.5) + _lean * 2.0
	var center := Vector2(0.0, R * 0.0)

	_draw_veins()

	# Very faint halo; nothing solid behind the seed.
	draw_circle(center, R * 1.7, Color(glow_color, 0.025 + 0.10 * fed))
	# Dim glow that peeks through the seams while closed.
	draw_circle(center, R * 0.45 * breath, Color(glow_color, (0.22 + 0.2 * _thirst) * (1.0 - fed)))

	var n := clampi(petal_count, 4, 6)
	var spread := 0.62 + 1.35 * open
	var curlk := maxf(0.85 - 1.0 * open, -0.4)
	var length := R * 1.25 * breath
	var width := R * 0.5 * breath
	# Outer petals first, centre-most last.
	var order: Array[int] = []
	for i in n:
		order.append(i)
	order.sort_custom(func(x, y): return absf(float(x) + 0.5 - n * 0.5) > absf(float(y) + 0.5 - n * 0.5))
	for i in order:
		var u := ((float(i) + 0.5) / float(n) - 0.5) * 2.0
		var a := u * spread + _lean.x * 0.22
		var shade := 0.015 + 0.012 * (1.0 - absf(u))
		var sides := _petal(base, a, length, width, curlk)
		var poly: PackedVector2Array = sides[0]
		draw_colored_polygon(poly, Color(shade, shade + 0.012, shade + 0.02, 1.0))
		if fed > 0.01:
			var inner: PackedVector2Array = _petal(base, a, length * 0.9, width * 0.62, curlk)[0]
			draw_colored_polygon(inner, Color(glow_color.r, glow_color.g, glow_color.b, 0.4 * fed))
		# Rim on the outer edge only.
		var edge: PackedVector2Array = sides[2] if a >= 0.0 else sides[1]
		draw_polyline(edge, Color(rim_col, rim_a), 1.6, true)

	# Base of the bulb glows when fed.
	if fed > 0.01:
		draw_circle(base, R * 0.32, Color(glow_color, 0.35 * fed))
		draw_circle(base, R * 0.16, Color(1, 1, 1, 0.5 * fed))
		# Bright core on top: nothing dark above it.
		var cr := R * (0.6 + 0.4 * minf(open, 1.1)) * breath
		draw_circle(center, cr, Color(glow_color, 0.10 * fed))
		draw_circle(center, cr * 0.8, Color(glow_color, 0.18 * fed))
		draw_circle(center, cr * 0.58, Color(glow_color.lerp(Color.WHITE, 0.3), 0.4 * fed))
		draw_circle(center, cr * 0.36, Color(glow_color.lerp(Color.WHITE, 0.7), 0.85 * fed))
		draw_circle(center, cr * 0.18, Color(1, 1, 1, 0.95 * fed))


## Filled teardrop petal rooted at `from`, heading `a` rad from straight up. Returns
## [polygon, left edge, right edge]. `curlk` bends the tip back toward vertical (closed) or outward.
func _petal(from: Vector2, a: float, length: float, width: float, curlk: float) -> Array:
	var steps := 9
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var pos := from
	for s in steps + 1:
		var t := float(s) / float(steps)
		var h := a * (1.0 - curlk * t)
		var d := Vector2(sin(h), -cos(h))
		var p := Vector2(cos(h), sin(h))
		var w := width * sin(PI * pow(t, 0.6))
		left.append(pos - p * w)
		right.append(pos + p * w)
		pos += d * (length / float(steps))
	var poly := PackedVector2Array(left)
	for s in range(steps, -1, -1):
		poly.append(right[s])
	return [poly, left, right]


func _draw_veins() -> void:
	if _vein_t <= 0.001:
		return
	for e in _veins:
		var full: PackedVector2Array = e["pts"]
		var st: float = e["start"]
		var t := clampf((_vein_t - st) / (1.0 - st), 0.0, 1.0)
		t = 1.0 - pow(1.0 - t, 2.0)
		if t <= 0.0:
			continue
		var segs := full.size() - 1
		var upto := t * segs
		var count := mini(int(floor(upto)), segs)
		var w0: float = e["w"]
		for i in mini(count + 1, segs):
			var a := full[i]
			var b := full[i + 1]
			if i == count:
				b = a.lerp(b, upto - float(count))
			var w := lerpf(w0, 1.0, float(i) / float(segs))
			draw_line(a, b, Color(glow_color, 0.10 * _fed), w * 3.0, true)
			draw_line(a, b, Color(glow_color, 0.4 * _fed), w * 1.6, true)
			draw_line(a, b, Color(0.8, 1.0, 1.0, 0.9 * _fed), maxf(w * 0.6, 1.0), true)
		var tip := full[count]
		if count < segs:
			tip = full[count].lerp(full[count + 1], upto - float(count))
		draw_circle(tip, 2.0, Color(1, 1, 1, 0.9 * _fed))


func _on_activated() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_bloom", 1.0, bloom_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_fed", 1.0, bloom_time * 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_vein_t", 1.0, 2.0).set_delay(bloom_time * 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_body_entered(body: Node2D) -> void:
	if body is Gloop and not (body as Gloop).is_absorbed:
		(body as Gloop).absorb_into_target()
		current_volume += 1
		fluid_received.emit(current_volume, required_fluid_volume)
		AudioController.play(AudioController.Cue.CORE_ABSORB)
		_flash = 1.0
		if current_volume >= required_fluid_volume and not is_active:
			is_active = true
			core_activated.emit()
