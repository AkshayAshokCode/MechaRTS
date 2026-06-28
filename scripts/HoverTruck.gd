extends "res://scripts/Unit.gd"

const HARVEST_DOCK_DIST    := 95.0   # trigger: start harvesting when within this distance
const HARVEST_APPROACH_DIST := 78.0  # nav target: park ~46 px clear of lava visual edge
const BUILD_DOCK_MARGIN    := 45.0   # extra clearance beyond building collision radius
const HEAL_DOCK_DIST       := 52.0   # approach within this range to start healing
const HEAL_RATE            := 25.0   # HP restored per second
const COLOR_IDLE       := Color(0.30, 0.60, 1.00)
const COLOR_SELECTED   := Color(0.50, 0.80, 1.00)
const COLOR_HARVESTING := Color(1.00, 0.70, 0.10)
const COLOR_BUILDING   := Color(0.90, 0.85, 0.20)
const COLOR_HEALING    := Color(0.20, 1.00, 0.55)

# --- Harvest state ---
var harvest_target: Node = null
var _harvesting    := false
var _harvest_rate  := 0.0

# --- Construct state ---
var build_target:  Node = null
var _constructing  := false

# --- Heal state ---
var heal_target:  Node = null
var _healing      := false

# --- Part pickup state ---
var _pickup_target: Node = null

var _beam_phase: float = 0.0

func _ready() -> void:
	super._ready()
	vision_range = 180.0

# Cab protrudes in -Y (local up) → front is -Y → offset angle by 90°
func _update_facing(moved: Vector2) -> void:
	rotation = moved.angle() + PI / 2.0

# ── Public commands ────────────────────────────────────────────────────────────

func harvest(node: Node) -> void:
	_stop_build()
	_stop_heal()
	_stop_harvest()
	harvest_target = node
	move_target    = _approach_pos((node as Node2D).global_position, HARVEST_APPROACH_DIST)
	unit_state     = STATE_TASKED

func stop_harvesting() -> void:
	_stop_harvest()

func build(building: Node) -> void:
	_stop_harvest()
	_stop_heal()
	_stop_build()
	build_target = building
	move_target  = _approach_pos((building as Node2D).global_position, _build_dock_dist(building) - 15.0)
	unit_state   = STATE_TASKED

func stop_building() -> void:
	_stop_build()

func heal(target: Node) -> void:
	_stop_harvest()
	_stop_build()
	_stop_heal()
	heal_target = target
	move_target = _approach_pos((target as Node2D).global_position, HEAL_DOCK_DIST - 14.0)
	unit_state  = STATE_TASKED

func stop_healing() -> void:
	_stop_heal()

func pickup(node: Node) -> void:
	_stop_harvest()
	_stop_build()
	_stop_heal()
	_pickup_target = node
	move_target    = (node as Node2D).global_position
	unit_state     = STATE_TASKED

# Returns a position at `stop_dist` from target, approached from current location.
func _approach_pos(target_pos: Vector2, stop_dist: float) -> Vector2:
	var to_target := target_pos - global_position
	if to_target.length() <= stop_dist:
		return global_position
	return target_pos - to_target.normalized() * stop_dist

func _build_dock_dist(building: Node) -> float:
	if building.has_method("get_collision_radius"):
		return building.get_collision_radius() + BUILD_DOCK_MARGIN
	return 70.0

# ── Private ────────────────────────────────────────────────────────────────────

func _stop_harvest() -> void:
	if harvest_target != null and is_instance_valid(harvest_target):
		harvest_target.release_harvester(self)
	harvest_target = null
	_harvesting    = false
	_harvest_rate  = 0.0
	unit_state     = STATE_IDLE

func _stop_build() -> void:
	if _constructing and build_target != null and is_instance_valid(build_target):
		if build_target.has_method("remove_builder"):
			build_target.remove_builder()
	build_target  = null
	_constructing = false
	unit_state    = STATE_IDLE

func _stop_heal() -> void:
	heal_target = null
	_healing    = false
	unit_state  = STATE_IDLE

func _physics_process(delta: float) -> void:
	# ── Active: harvesting ──────────────────────────────────────────────────
	if _harvesting:
		if not is_instance_valid(harvest_target) or harvest_target.get("_depleted") == true:
			_stop_harvest()
		else:
			# Always drain lava; only store energy when below cap
			if GameState.energy < GameState.energy_cap:
				GameState.add_energy(_harvest_rate * delta)
		queue_redraw()
		return

	# ── Active: constructing ────────────────────────────────────────────────
	if _constructing:
		if not is_instance_valid(build_target) or build_target.is_built:
			_stop_build()
		else:
			var rate: float = build_target.build_cost / build_target.build_time
			if GameState.spend_energy(rate * delta):
				if build_target.advance_build(delta):
					_stop_build()
		_beam_phase = fmod(_beam_phase + delta * 2.2, 1.0)
		queue_redraw()
		return

	# ── Active: healing ─────────────────────────────────────────────────────
	if _healing:
		if not is_instance_valid(heal_target):
			_stop_heal()
		else:
			var h:  float = heal_target.get("health")
			var mh: float = heal_target.get("max_health")
			if h >= mh:
				_stop_heal()
			else:
				heal_target.set("health", minf(h + HEAL_RATE * delta, mh))
				heal_target.queue_redraw()
		_beam_phase = fmod(_beam_phase + delta * 2.8, 1.0)
		queue_redraw()
		return

	# ── Approach: collect a dropped part ───────────────────────────────────
	if _pickup_target != null:
		if not is_instance_valid(_pickup_target):
			_pickup_target = null
			unit_state     = STATE_IDLE
		else:
			var dist := global_position.distance_to((_pickup_target as Node2D).global_position)
			if dist <= HARVEST_DOCK_DIST:
				var pd: Variant = _pickup_target.get("part_data")
				if pd is Dictionary and not (pd as Dictionary).is_empty():
					GameState.add_part((pd as Dictionary).duplicate())
				_pickup_target.queue_free()
				_pickup_target = null
				move_target    = global_position
				unit_state     = STATE_IDLE

	# ── Approach: move toward harvest target ────────────────────────────────
	if harvest_target != null:
		var dist := global_position.distance_to((harvest_target as Node2D).global_position)
		if dist <= HARVEST_DOCK_DIST:
			if harvest_target.assign_harvester(self):
				_harvesting   = true
				_harvest_rate = harvest_target.harvest_rate
				move_target   = global_position
				return

	# ── Approach: move toward heal target ───────────────────────────────────
	if heal_target != null:
		if not is_instance_valid(heal_target):
			_stop_heal()
		else:
			var dist := global_position.distance_to((heal_target as Node2D).global_position)
			if dist <= HEAL_DOCK_DIST:
				_healing    = true
				move_target = global_position
				return
			else:
				# Continuously chase moving targets (vehicles/combots)
				move_target = _approach_pos((heal_target as Node2D).global_position, HEAL_DOCK_DIST - 14.0)

	# ── Approach: move toward build target ──────────────────────────────────
	if build_target != null:
		var dist := global_position.distance_to((build_target as Node2D).global_position)
		if dist <= _build_dock_dist(build_target):
			_constructing = true
			if build_target.has_method("add_builder"):
				build_target.add_builder()
			move_target   = global_position
			return

	super._physics_process(delta)

func _draw() -> void:
	var body_col: Color
	if _constructing:
		body_col = COLOR_BUILDING
	elif _harvesting:
		body_col = COLOR_HARVESTING
	elif _healing:
		body_col = COLOR_HEALING
	elif selected:
		body_col = COLOR_SELECTED
	else:
		body_col = COLOR_IDLE

	var u := _iso_up()
	_draw_shadow()
	# South face — connects body bottom to ground, gives 3D depth
	draw_colored_polygon(PackedVector2Array([
		Vector2(-RADIUS + u.x, RADIUS * 0.55 + u.y),
		Vector2( RADIUS + u.x, RADIUS * 0.55 + u.y),
		Vector2( RADIUS,       RADIUS * 0.55),
		Vector2(-RADIUS,       RADIUS * 0.55),
	]), body_col.darkened(0.50))
	# Truck body (top face)
	draw_rect(Rect2(-RADIUS + u.x, -RADIUS * 0.55 + u.y, RADIUS * 2.0, RADIUS * 1.1), body_col)
	# Cab
	draw_rect(Rect2(-RADIUS * 0.5 + u.x, -RADIUS + u.y, RADIUS, RADIUS * 0.55), body_col.darkened(0.25))
	# Outline
	draw_arc(u, RADIUS + 2.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.30), 1.0)
	if selected:
		draw_arc(u, RADIUS + 6.0, 0.0, TAU, 32, Color(COLOR_SELECTED.r, COLOR_SELECTED.g, COLOR_SELECTED.b, 0.70), 1.5)
	if _harvesting:
		draw_arc(u, RADIUS + 9.0, 0.0, TAU, 32, Color(1.0, 0.65, 0.1, 0.65), 2.0)
	if _constructing:
		draw_arc(u, RADIUS + 9.0, 0.0, TAU, 32, Color(0.9, 0.9, 0.2, 0.65), 2.0)
		if build_target != null and is_instance_valid(build_target):
			_draw_beam((build_target as Node2D).global_position, Color(1.0, 0.88, 0.15))
	if _healing:
		draw_arc(u, RADIUS + 9.0, 0.0, TAU, 32, Color(0.2, 1.0, 0.55, 0.65), 2.0)
		if heal_target != null and is_instance_valid(heal_target):
			_draw_beam((heal_target as Node2D).global_position, Color(0.18, 1.0, 0.58))
	_draw_health_bar()


# Animated energy-packet beam from truck centre to a world-space target.
# Draws 5 glowing dots travelling along the line, each pulsing in size and alpha.
func _draw_beam(target_world: Vector2, col: Color) -> void:
	var target_local := to_local(target_world)
	var dist := target_local.length()
	if dist < 8.0:
		return

	# Faint guide line
	draw_line(Vector2.ZERO, target_local, Color(col.r, col.g, col.b, 0.18), 1.5)

	# 5 energy packets evenly spaced, marching toward the target
	const N := 5
	for i in N:
		var t := fmod(_beam_phase + float(i) / float(N), 1.0)
		var pos  := target_local * t
		var wave := sin(t * PI)            # 0 at ends, 1 at midpoint
		var r    := 2.2 + wave * 2.0       # grows toward mid-beam
		var a    := wave * 0.90
		draw_circle(pos, r,       Color(col.r, col.g, col.b, a))
		draw_circle(pos, r * 0.4, Color(1.0, 1.0, 1.0, a * 0.80))  # bright core
