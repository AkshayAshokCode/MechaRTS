extends "res://scripts/Unit.gd"

const DOCK_DISTANCE   := 50.0
const COLOR_IDLE       := Color(0.30, 0.60, 1.00)
const COLOR_SELECTED   := Color(0.50, 0.80, 1.00)
const COLOR_HARVESTING := Color(1.00, 0.70, 0.10)
const COLOR_BUILDING   := Color(0.90, 0.85, 0.20)

# --- Harvest state ---
var harvest_target: Node = null
var _harvesting    := false
var _harvest_rate  := 0.0

# --- Construct state ---
var build_target:  Node = null
var _constructing  := false

func _ready() -> void:
	super._ready()
	vision_range = 180.0

# ── Public commands ────────────────────────────────────────────────────────────

func harvest(node: Node) -> void:
	_stop_build()
	_stop_harvest()
	harvest_target = node
	move_target    = (node as Node2D).global_position

func stop_harvesting() -> void:
	_stop_harvest()

func build(building: Node) -> void:
	_stop_harvest()
	_stop_build()
	build_target = building
	move_target  = (building as Node2D).global_position

func stop_building() -> void:
	_stop_build()

# ── Private ────────────────────────────────────────────────────────────────────

func _stop_harvest() -> void:
	if harvest_target != null and is_instance_valid(harvest_target):
		harvest_target.release_harvester(self)
	harvest_target = null
	_harvesting    = false
	_harvest_rate  = 0.0

func _stop_build() -> void:
	build_target  = null
	_constructing = false

func _physics_process(delta: float) -> void:
	# ── Active: harvesting ──────────────────────────────────────────────────
	if _harvesting:
		if not is_instance_valid(harvest_target):
			_stop_harvest()
		else:
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
		queue_redraw()
		return

	# ── Approach: move toward harvest target ────────────────────────────────
	if harvest_target != null:
		var dist := global_position.distance_to((harvest_target as Node2D).global_position)
		if dist <= DOCK_DISTANCE:
			if harvest_target.assign_harvester(self):
				_harvesting   = true
				_harvest_rate = harvest_target.harvest_rate
				move_target   = global_position
				return

	# ── Approach: move toward build target ──────────────────────────────────
	if build_target != null:
		var dist := global_position.distance_to((build_target as Node2D).global_position)
		if dist <= DOCK_DISTANCE:
			_constructing = true
			move_target   = global_position
			return

	super._physics_process(delta)

func _draw() -> void:
	var body_col: Color
	if _constructing:
		body_col = COLOR_BUILDING
	elif _harvesting:
		body_col = COLOR_HARVESTING
	elif selected:
		body_col = COLOR_SELECTED
	else:
		body_col = COLOR_IDLE

	# Truck body
	draw_rect(Rect2(-RADIUS, -RADIUS * 0.55, RADIUS * 2.0, RADIUS * 1.1), body_col)
	# Cab
	draw_rect(Rect2(-RADIUS * 0.5, -RADIUS, RADIUS, RADIUS * 0.55), body_col.darkened(0.25))
	# Outline
	draw_arc(Vector2.ZERO, RADIUS + 2.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.30), 1.0)
	if selected:
		draw_arc(Vector2.ZERO, RADIUS + 6.0, 0.0, TAU, 32, Color(COLOR_SELECTED.r, COLOR_SELECTED.g, COLOR_SELECTED.b, 0.70), 1.5)
	if _harvesting:
		draw_arc(Vector2.ZERO, RADIUS + 9.0, 0.0, TAU, 32, Color(1.0, 0.65, 0.1, 0.65), 2.0)
	if _constructing:
		draw_arc(Vector2.ZERO, RADIUS + 9.0, 0.0, TAU, 32, Color(0.9, 0.9, 0.2, 0.65), 2.0)
