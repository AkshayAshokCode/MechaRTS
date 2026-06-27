extends "res://scripts/Unit.gd"

const DOCK_DISTANCE := 50.0  # world px — node edge + margin
const COLOR_IDLE      := Color(0.30, 0.60, 1.00)
const COLOR_SELECTED  := Color(0.50, 0.80, 1.00)
const COLOR_HARVESTING := Color(1.00, 0.70, 0.10)

var harvest_target: Node = null
var _harvesting    := false
var _harvest_rate  := 0.0

func _ready() -> void:
	super._ready()
	vision_range = 180.0

func harvest(node: Node) -> void:
	_stop_harvest()
	harvest_target = node
	move_target    = (node as Node2D).global_position

func stop_harvesting() -> void:
	_stop_harvest()

func _stop_harvest() -> void:
	if harvest_target != null and is_instance_valid(harvest_target):
		harvest_target.release_harvester(self)
	harvest_target = null
	_harvesting    = false
	_harvest_rate  = 0.0

func _physics_process(delta: float) -> void:
	if harvest_target != null and not _harvesting:
		var dist := global_position.distance_to((harvest_target as Node2D).global_position)
		if dist <= DOCK_DISTANCE:
			if harvest_target.assign_harvester(self):
				_harvesting   = true
				_harvest_rate = harvest_target.harvest_rate
				move_target   = global_position  # stop moving

	if _harvesting:
		if not is_instance_valid(harvest_target):
			_stop_harvest()
		else:
			GameState.add_energy(_harvest_rate * delta)
		queue_redraw()
	else:
		super._physics_process(delta)

func _draw() -> void:
	var body_col := COLOR_HARVESTING if _harvesting else (COLOR_SELECTED if selected else COLOR_IDLE)
	# Rectangular truck body
	draw_rect(Rect2(-RADIUS, -RADIUS * 0.55, RADIUS * 2.0, RADIUS * 1.1), body_col)
	# Cab
	draw_rect(Rect2(-RADIUS * 0.5, -RADIUS, RADIUS, RADIUS * 0.55), body_col.darkened(0.2))
	# Outline
	draw_arc(Vector2.ZERO, RADIUS + 2.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.35), 1.0)
	if selected:
		draw_arc(Vector2.ZERO, RADIUS + 6.0, 0.0, TAU, 32, COLOR_SELECTED * Color(1,1,1,0.7), 1.5)
	if _harvesting:
		# Pulsing harvest ring
		draw_arc(Vector2.ZERO, RADIUS + 9.0, 0.0, TAU, 32, Color(1.0, 0.65, 0.1, 0.65), 2.0)
