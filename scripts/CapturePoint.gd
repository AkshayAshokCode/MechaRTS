extends Node2D

const CAPTURE_RADIUS := 90.0
const CAPTURE_TIME   := 8.0     # seconds to fully capture from neutral
const ENERGY_RATE    := 20.0    # MJ/s granted to player while held
const STRUCT_RADIUS  := 22.0

# -1.0 = fully enemy | 0.0 = neutral | +1.0 = fully player
var _progress:  float = 0.0
var _label:     String = ""
var _pulse:     float  = 0.0
var _contested: bool   = false

func setup(lbl: String) -> void:
	_label = lbl
	add_to_group("capture_points")
	queue_redraw()

func _process(delta: float) -> void:
	var p_near := _count_nearby("units")       > 0
	var e_near := _count_nearby("enemy_units") > 0
	_contested  = p_near and e_near

	if p_near and not _contested:
		_progress = minf(_progress + delta / CAPTURE_TIME, 1.0)
	elif e_near and not _contested:
		_progress = maxf(_progress - delta / CAPTURE_TIME, -1.0)
	# contested or nobody: no change

	if _progress >= 1.0:
		GameState.add_energy(ENERGY_RATE * delta)

	_pulse = fmod(_pulse + delta * 2.0, TAU)
	queue_redraw()

func _count_nearby(group: String) -> int:
	var n := 0
	for unit in get_tree().get_nodes_in_group(group):
		if (unit as Node2D).global_position.distance_to(global_position) <= CAPTURE_RADIUS:
			n += 1
	return n

func _draw() -> void:
	var t := _progress

	# ── Fill color by capture state ───────────────────────────────────────────
	var fill_col: Color
	if t >= 1.0:
		fill_col = Color(0.18, 0.48, 1.00)
	elif t <= -1.0:
		fill_col = Color(1.00, 0.20, 0.16)
	elif t > 0.0:
		fill_col = Color(0.18, 0.48, 1.00, 0.40 + t * 0.38)
	elif t < 0.0:
		fill_col = Color(1.00, 0.20, 0.16, 0.40 + (-t) * 0.38)
	else:
		fill_col = Color(0.55, 0.55, 0.58)

	# ── Octagon body ─────────────────────────────────────────────────────────
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		pts.append(Vector2(cos(a), sin(a)) * STRUCT_RADIUS)
	draw_colored_polygon(pts, fill_col)

	# Internal cross detail
	draw_line(Vector2(0.0, -STRUCT_RADIUS * 0.55), Vector2(0.0,  STRUCT_RADIUS * 0.55),
		Color(1.0, 1.0, 1.0, 0.18), 1.5)
	draw_line(Vector2(-STRUCT_RADIUS * 0.55, 0.0), Vector2( STRUCT_RADIUS * 0.55, 0.0),
		Color(1.0, 1.0, 1.0, 0.18), 1.5)

	# Octagon outline
	for i in 8:
		draw_line(pts[i], pts[(i + 1) % 8], Color(1.0, 1.0, 1.0, 0.55), 1.5)

	# ── Capture progress ring ─────────────────────────────────────────────────
	if t != 0.0:
		var ring_col := Color(0.35, 0.65, 1.00, 0.92) if t > 0.0 \
			else Color(1.00, 0.28, 0.12, 0.92)
		var sweep := absf(t) * TAU
		draw_arc(Vector2.ZERO, STRUCT_RADIUS + 9.0,
			-PI * 0.5, -PI * 0.5 + sweep,
			maxi(4, int(sweep * 12.0)), ring_col, 3.5)

	# ── Held glow pulse ───────────────────────────────────────────────────────
	if absf(t) >= 1.0:
		var g := sin(_pulse) * 0.07 + 0.16
		var glow_col := Color(0.28, 0.58, 1.00, g) if t > 0.0 \
			else Color(1.00, 0.26, 0.12, g)
		draw_circle(Vector2.ZERO, STRUCT_RADIUS + 16.0, glow_col)

	# ── Status text ───────────────────────────────────────────────────────────
	var font := ThemeDB.fallback_font
	# Center dot / income badge when player holds
	if t >= 1.0:
		draw_circle(Vector2.ZERO, 5.0, Color(0.85, 1.00, 0.35, 0.95))
		draw_string(font, Vector2(-14.0, -STRUCT_RADIUS - 6.0), "+20 MJ/s",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.80, 1.00, 0.35, 0.90))
	elif t <= -1.0:
		draw_circle(Vector2.ZERO, 5.0, Color(1.00, 0.35, 0.25, 0.95))

	# Name label below
	draw_string(font, Vector2(-20.0, STRUCT_RADIUS + 14.0), _label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 1.0, 1.0, 0.78))

	# Contested flash
	if _contested:
		var fl := sin(_pulse * 3.0) * 0.5 + 0.5
		draw_arc(Vector2.ZERO, STRUCT_RADIUS + 9.0, 0.0, TAU, 32,
			Color(1.00, 0.75, 0.10, fl * 0.85), 3.5)
