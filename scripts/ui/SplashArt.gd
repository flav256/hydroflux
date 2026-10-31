extends Node2D

## The opening image: one light forms on a tooth, falls, and rests on a vine.

var time: float = 0.0
var drop_position: Vector2 = Vector2(640.0, 190.0)
var drop_glow: float = 0.0
var _stretch: Vector2 = Vector2.ONE
var _cycle: float = 0.0
var _weight: float = 0.0

const _TIP := Vector2(640.0, 246.0)
const _LEFT := Vector2(508.0, 448.0)
const _MID := Vector2(640.0, 528.0)
const _RIGHT := Vector2(772.0, 442.0)


func _process(delta: float) -> void:
	time += delta
	_place_drop()
	queue_redraw()


func _place_drop() -> void:
	_cycle = fmod(maxf(time - 0.25, 0.0), 8.2)
	var born := _TIP + Vector2(0.0, 36.0)
	if _cycle < 1.85:
		_weight = 0.0
	elif _cycle < 2.85:
		_weight = ((_cycle - 1.85) / 1.0) ** 2
	else:
		var since := _cycle - 2.85
		_weight = exp(-since * 1.6) * 0.35 + 1.0
	var land := _on_vine(0.5) + Vector2(0.0, -20.0)
	if _cycle < 1.85:
		var k := _cycle / 1.85
		var swell := smoothstep(0.0, 1.0, k)
		var tremble := sin(_cycle * 16.0) * lerpf(0.6, 4.5, k * k)
		var load := sin(_cycle * 6.5) * lerpf(0.0, 7.0, k)
		drop_position = born + Vector2(tremble, load)
		_stretch = Vector2(
			lerpf(0.5, 0.86, swell) + sin(_cycle * 13.0) * 0.05,
			lerpf(1.25, 1.62, swell)
		)
		drop_glow = swell
	elif _cycle < 2.85:
		var fall := (_cycle - 1.85) / 1.0
		var eased := fall * fall
		var wobble := sin(fall * TAU * 1.5) * (1.0 - fall) * 14.0
		drop_position = born.lerp(land, eased) + Vector2(wobble, 0.0)
		_stretch = Vector2(lerpf(0.82, 0.68, fall), lerpf(1.25, 1.7, fall))
		drop_glow = 1.0
	else:
		var since := _cycle - 2.85
		var bounce := sin(since * 13.0) * exp(-since * 2.15) * 18.0
		var sway := sin(since * 5.2) * exp(-since * 1.3) * 8.0
		drop_position = land + Vector2(sway, -absf(bounce))
		var hit := 1.0 + sin(since * 13.0) * exp(-since * 2.0) * 0.32
		var jelly := sin(time * 5.2) * 0.055
		_stretch = Vector2(hit + jelly, (2.0 - hit) - jelly)
		drop_glow = 1.0 - smoothstep(7.35, 8.05, _cycle)


func _draw() -> void:
	_draw_cavern()
	_draw_vine()
	_draw_ripples()
	_draw_drop()
	_draw_words()


func _draw_cavern() -> void:
	var ceiling := PackedVector2Array([
		Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 92),
		Vector2(1040, 70), Vector2(860, 128), Vector2(720, 78),
		Vector2(560, 78), Vector2(420, 132), Vector2(240, 64),
		Vector2(0, 108),
	])
	draw_colored_polygon(ceiling, Color(0, 0, 0, 1))
	var tooth := PackedVector2Array([
		Vector2(612, 78), Vector2(668, 82), Vector2(654, 168),
		Vector2(646, 228), Vector2(640, 246), Vector2(634, 220),
		Vector2(624, 160),
	])
	draw_colored_polygon(tooth, Color(0, 0, 0, 1))
	var ground := PackedVector2Array([
		Vector2(0, 720), Vector2(0, 575), Vector2(260, 612),
		Vector2(480, 548), Vector2(800, 548), Vector2(1040, 618),
		Vector2(1280, 568), Vector2(1280, 720),
	])
	draw_colored_polygon(ground, Color(0, 0, 0, 1))


func _draw_vine() -> void:
	var points := PackedVector2Array()
	for i in 25:
		points.append(_on_vine(float(i) / 24.0))
	draw_polyline(points, Color(0, 0, 0, 1), 16.0, true)
	for i in range(0, points.size() - 1, 2):
		draw_line(points[i], points[i + 1], Color(0.72, 0.96, 1.0, 0.9), 2.2, true)
		draw_circle(points[i], 1.6, Color(0.8, 0.98, 1.0, 0.95))
	draw_circle(_LEFT, 5.0, Color(0, 0, 0, 1))
	draw_circle(_RIGHT, 5.0, Color(0, 0, 0, 1))


func _draw_drop() -> void:
	if drop_glow <= 0.02:
		return
	var alpha := drop_glow
	var pulse := 0.85 + 0.15 * sin(time * 7.0)
	draw_circle(drop_position, 52.0 * pulse, Color(0.3, 0.92, 1.0, 0.1 * alpha))
	draw_circle(drop_position, 30.0, Color(0.5, 0.96, 1.0, 0.18 * alpha))
	if _cycle < 1.85:
		_draw_neck(alpha)
	var body := PackedVector2Array()
	var wobble := sin(time * 9.0) * 0.08
	for i in 32:
		var a := TAU * float(i) / 32.0
		var px := sin(a) * (14.0 + wobble * cos(a)) * _stretch.x
		var py := (cos(a) - 0.5 * sin(a) * sin(a)) * 19.0 * _stretch.y
		body.append(drop_position + Vector2(px, py))
	draw_colored_polygon(body, Color(0.45, 0.94, 1.0, alpha))
	var glint := Vector2(cos(time * 2.6) * 4.5, sin(time * 3.4) * 3.2 - 3.0)
	draw_circle(drop_position + glint * _stretch, 5.0 * _stretch.x, Color(0.96, 1.0, 1.0, 0.95 * alpha))
	draw_circle(drop_position + glint * _stretch * 0.45, 2.1, Color(1, 1, 1, alpha))
	if _cycle > 4.3 and _cycle < 7.5:
		var wake := smoothstep(4.3, 5.1, _cycle) * (1.0 - smoothstep(6.9, 7.5, _cycle))
		var look := Vector2(sin(time * 0.5) * 1.3, -1.6)
		var blink := 1.0
		var phase := fmod(time, 3.6)
		if phase > 3.2:
			blink = (3.6 - phase) / 0.4
		for side in [-1.0, 1.0]:
			var eye := drop_position + Vector2(side * 4.6, 2.2) + look
			_eye_disk(eye, 1.7, maxf(1.5 * blink, 0.14), Color(0.01, 0.03, 0.05, 0.9 * alpha * wake))
	if _cycle > 2.85 and _cycle < 4.4:
		var bead_t := (_cycle - 2.85) / 1.5
		var bead := drop_position + Vector2(10.0, -6.0 + bead_t * 16.0)
		var bead_a := (1.0 - bead_t) * alpha
		draw_circle(bead, lerpf(4.5, 1.5, bead_t), Color(0.7, 0.97, 1.0, bead_a))


func _draw_neck(alpha: float) -> void:
	var pinch := clampf(_cycle / 1.85, 0.0, 1.0)
	var top := _TIP
	var bottom := drop_position + Vector2(0.0, -16.0 * _stretch.y)
	var width := lerpf(6.5, 0.7, pinch * pinch)
	var mid := top.lerp(bottom, 0.55) + Vector2(sin(time * 14.0) * 2.2, 0.0)
	var neck := PackedVector2Array([
		top + Vector2(-width * 0.45, 0.0),
		mid + Vector2(-width, 0.0),
		bottom + Vector2(-width * 0.35, 0.0),
		bottom + Vector2(width * 0.35, 0.0),
		mid + Vector2(width, 0.0),
		top + Vector2(width * 0.45, 0.0),
	])
	draw_colored_polygon(neck, Color(0.55, 0.95, 1.0, alpha * (1.0 - pinch * 0.35)))


func _draw_ripples() -> void:
	if _cycle < 2.85:
		return
	var age := _cycle - 2.85
	var origin := _on_vine(0.5)
	for i in 3:
		var t := age - float(i) * 0.28
		if t <= 0.0 or t > 1.6:
			continue
		var radius := lerpf(8.0, 54.0 + float(i) * 10.0, t / 1.6)
		var fade := (1.0 - t / 1.6) * drop_glow
		draw_arc(origin, radius, PI, TAU, 28, Color(0.65, 0.95, 1.0, 0.45 * fade), 1.6, true)


func _draw_words() -> void:
	var font := ThemeDB.fallback_font
	var shown := clampf((time - 0.8) / 1.6, 0.0, 1.0)
	_draw_tracked(font, "HYDROFLUX", 34, Vector2(640, 632), 14.0, Color(0.86, 0.97, 1.0, 0.94 * shown))
	_draw_tracked(font, "water carries the light", 15, Vector2(640, 662), 3.2, Color(0.7, 0.88, 0.92, 0.62 * shown))
	var breathe := 0.35 + 0.25 * sin(time * 1.6)
	if time > 2.2:
		_draw_tracked(font, "tap to enter", 13, Vector2(640, 688), 2.4, Color(0.75, 0.9, 0.94, breathe))


func _draw_tracked(font: Font, text: String, size: int, center: Vector2, gap: float, color: Color) -> void:
	var width := 0.0
	for i in text.length():
		width += font.get_string_size(text.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if i < text.length() - 1:
			width += gap
	var x := center.x - width * 0.5
	for i in text.length():
		var ch := text.substr(i, 1)
		draw_string(font, Vector2(x, center.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + gap


func _on_vine(t: float) -> Vector2:
	var u := 1.0 - t
	var sag := Vector2(0.0, 14.0 * _weight)
	return u * u * _LEFT + 2.0 * u * t * (_MID + sag) + t * t * _RIGHT


func _eye_disk(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)
