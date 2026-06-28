extends Node2D

const RADIUS          := 32.0
const MAX_HARVESTERS  := 4       # up to 4 trucks per node; more trucks = faster drain
const RESERVE_TOTAL   := 8000.0
const REPLENISH_RATE  := 8.0     # MJ/s recovered while idle (vs 40 MJ/s per truck)

const PARTICLE_LIFETIME := 0.70
const PARTICLE_SPEED    := 110.0
const PARTICLE_RATE     := 0.08    # seconds between spawns per docked harvester

var harvest_rate: float = 40.0
var _harvesters:  Array = []
var _remaining:   float = RESERVE_TOTAL
var _depleted:    bool  = false
var _pulse:       float = 0.0

# ── Absorption particles ──────────────────────────────────────────────────────
var _particles:      Array = []   # [{pos, truck, life, max_life, size}]
var _particle_timer: float = 0.0

# ── Pre-computed lava shape (seeded from world position for per-node variety) ─
var _rng := RandomNumberGenerator.new()
var _outer_poly: PackedVector2Array   # cooled crust / border
var _lava_poly:  PackedVector2Array   # hot lava fill layer
var _core_poly:  PackedVector2Array   # inner bright core
var _cracks:     Array = []           # [{from, to}]
var _bubbles:    Array = []           # [{pos, phase, size}]

func _ready() -> void:
	add_to_group("lava_nodes")
	_rng.seed = hash(Vector2i(int(position.x), int(position.y)))
	_outer_poly = _make_poly(RADIUS * 1.18, 18, 0.14)
	_lava_poly  = _make_poly(RADIUS * 0.88, 16, 0.18)
	_core_poly  = _make_poly(RADIUS * 0.44, 12, 0.22)
	_cracks     = _make_cracks(6)
	_bubbles    = _make_bubbles(7)

func _make_poly(r: float, n: int, variance: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a  := TAU * i / n
		var rv := r * (1.0 + _rng.randf_range(-variance, variance))
		pts.append(Vector2(cos(a) * rv, sin(a) * rv))
	return pts

func _make_cracks(n: int) -> Array:
	var cks := []
	for _i in n:
		var a   := _rng.randf() * TAU
		var len := _rng.randf_range(RADIUS * 0.25, RADIUS * 0.90)
		cks.append({
			"from": Vector2(cos(a), sin(a)) * _rng.randf_range(3.0, 8.0),
			"to":   Vector2(cos(a), sin(a)) * len,
		})
	return cks

func _make_bubbles(n: int) -> Array:
	var bubs := []
	for _i in n:
		bubs.append({
			"pos":   Vector2(
				_rng.randf_range(-RADIUS * 0.60, RADIUS * 0.60),
				_rng.randf_range(-RADIUS * 0.60, RADIUS * 0.60)),
			"phase": _rng.randf() * TAU,
			"size":  _rng.randf_range(3.0, 7.5),
		})
	return bubs

# ── Core logic ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 2.5, TAU)

	if _depleted:
		# Slowly cool and regenerate — never removed from world
		_remaining = minf(_remaining + REPLENISH_RATE * delta, RESERVE_TOTAL)
		if _remaining >= RESERVE_TOTAL * 0.08:
			_depleted    = false
			harvest_rate = 40.0
		queue_redraw()
		return

	if not _harvesters.is_empty():
		var active := 0
		for truck in _harvesters:
			if is_instance_valid(truck):
				active += 1
		if active > 0:
			var drained := harvest_rate * active * delta
			_remaining   = maxf(0.0, _remaining - drained)
			if _remaining <= 0.0:
				_deplete()
	elif _remaining < RESERVE_TOTAL:
		_remaining = minf(_remaining + REPLENISH_RATE * delta, RESERVE_TOTAL)

	_update_particles(delta)
	queue_redraw()

func has_capacity() -> bool:
	return _harvesters.size() < MAX_HARVESTERS and not _depleted

func assign_harvester(truck: Node) -> bool:
	if _harvesters.size() >= MAX_HARVESTERS or _depleted:
		return false
	if truck not in _harvesters:
		_harvesters.append(truck)
	return true

func release_harvester(truck: Node) -> void:
	_harvesters.erase(truck)

func _deplete() -> void:
	_depleted    = true
	harvest_rate = 0.0
	_harvesters.clear()
	_particles.clear()
	GameState.lava_depleted.emit()

# ── Particle system ───────────────────────────────────────────────────────────

func _update_particles(delta: float) -> void:
	if _harvesters.is_empty():
		_particles.clear()
		return

	# Spawn one particle per harvester at the set rate
	_particle_timer -= delta
	if _particle_timer <= 0.0:
		_particle_timer = PARTICLE_RATE
		for truck in _harvesters:
			if not is_instance_valid(truck):
				continue
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(0.0, RADIUS * 0.55)
			_particles.append({
				"pos":      Vector2(cos(a) * r, sin(a) * r),
				"truck":    truck,
				"life":     PARTICLE_LIFETIME,
				"max_life": PARTICLE_LIFETIME,
				"size":     _rng.randf_range(2.5, 4.5),
			})

	# Advance each particle toward its truck (in lava-local space)
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["life"] -= delta
		if p["life"] <= 0.0:
			_particles.remove_at(i)
			continue
		var truck = p["truck"]
		if not is_instance_valid(truck):
			_particles.remove_at(i)
			continue
		var truck_local: Vector2 = (truck as Node2D).global_position - global_position
		var to_target:   Vector2 = truck_local - p["pos"]
		if to_target.length_squared() > 4.0:
			p["pos"] += to_target.normalized() * PARTICLE_SPEED * delta

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	var ratio := _remaining / RESERVE_TOTAL
	var p     := (sin(_pulse) + 1.0) * 0.5   # 0..1 oscillator

	# ── Depleted state — cooled rock, slowly regenerating ───────────────────
	if _depleted:
		draw_colored_polygon(_outer_poly, Color(0.17, 0.13, 0.11, 1.0))
		for crack in _cracks:
			draw_line(crack["from"], crack["to"],
				Color(0.07, 0.05, 0.04, 0.65), 1.2)
		draw_string(ThemeDB.fallback_font, Vector2(-22.0, 4.0), "DEPLETED",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.45, 0.35, 0.32, 0.90))
		# Replenish progress bar
		var prog := _remaining / RESERVE_TOTAL
		var bw   := RADIUS * 1.8
		draw_rect(Rect2(-bw * 0.5, RADIUS + 4.0, bw, 4.0), Color(0.08, 0.08, 0.08, 0.85))
		draw_rect(Rect2(-bw * 0.5, RADIUS + 4.0, bw * prog, 4.0), Color(0.40, 0.75, 0.30, 0.90))
		return

	# ── Outer ambient glow (pulsing) ─────────────────────────────────────────
	draw_colored_polygon(_outer_poly,
		Color(1.0, 0.38, 0.0, (0.07 + p * 0.07) * ratio * 2.2))

	# Warning ring when nearly exhausted
	if ratio < 0.25:
		var warn_r := RADIUS + 13.0 + p * 10.0
		draw_arc(Vector2.ZERO, warn_r, 0.0, TAU, 32,
			Color(1.0, 0.88, 0.0, 0.15 + p * 0.18), 2.5)

	# ── Cooled crust border ──────────────────────────────────────────────────
	draw_colored_polygon(_outer_poly, Color(0.13, 0.05, 0.02, 1.0))

	# ── Hot lava fill — hue drains toward dull red as reserve drops ──────────
	var lava_r := lerpf(0.50, 0.92, ratio)
	var lava_g := lerpf(0.08, 0.28, ratio) + p * 0.08
	draw_colored_polygon(_lava_poly, Color(lava_r, lava_g, 0.02, 1.0))

	# Cracks in the solidified crust
	for crack in _cracks:
		draw_line(crack["from"], crack["to"],
			Color(0.06, 0.02, 0.01, 0.80), 1.5)

	# ── Inner bright core ─────────────────────────────────────────────────────
	var core_r := lerpf(0.65, 1.00, ratio)
	var core_g := lerpf(0.40, 0.82, ratio) + p * 0.12
	draw_colored_polygon(_core_poly, Color(core_r, core_g, 0.17, 1.0))

	# ── Bubbling spots (each has its own phase) ───────────────────────────────
	for bub in _bubbles:
		var bp := (sin(_pulse * 1.8 + float(bub["phase"])) + 1.0) * 0.5
		var bs := float(bub["size"]) * (0.55 + bp * 0.45) * ratio
		if bs > 0.5:
			draw_circle(bub["pos"], bs,
				Color(1.0, 0.74 + bp * 0.22, 0.20 * bp, 0.48 + bp * 0.42))

	# Harvester active ring + multi-harvester count badge
	if not _harvesters.is_empty():
		draw_arc(Vector2.ZERO, RADIUS + 4.0, 0.0, TAU, 32,
			Color(0.3, 1.0, 0.45, 0.85), 2.5)
		if _harvesters.size() > 1:
			draw_string(ThemeDB.fallback_font, Vector2(-7.0, -3.0),
				"×%d" % _harvesters.size(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 1.0, 0.55, 0.95))
	elif _remaining < RESERVE_TOTAL * 0.98:
		# Faint green ring + "↑" while replenishing
		draw_arc(Vector2.ZERO, RADIUS + 4.0, 0.0, TAU, 32,
			Color(0.25, 0.70, 0.35, 0.40), 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(-4.0, -3.0), "↑",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.35, 0.90, 0.45, 0.80))

	# Reserve percentage text (only visible when nearly depleted)
	if ratio < 0.35:
		draw_string(ThemeDB.fallback_font, Vector2(-12.0, 7.0),
			"%d%%" % int(ratio * 100.0),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.85, 0.45, 0.90))

	# ── Absorption particles — lava energy flowing toward the truck ───────────
	for part in _particles:
		var t: float = float(part["life"]) / float(part["max_life"])
		var s: float = float(part["size"]) * (0.25 + t * 0.75)
		var p_pos := Vector2(part["pos"])
		# Core droplet
		draw_circle(p_pos, s,
			Color(1.0, 0.58 + t * 0.35, 0.06, t * 0.95))
		# Outer glow halo (only on fresh particles)
		if t > 0.35:
			draw_arc(p_pos, s + 2.0, 0.0, TAU, 8,
				Color(1.0, 0.46, 0.04, t * 0.42), 1.0)
