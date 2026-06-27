extends Node2D

const RADIUS        := 32.0
const MAX_HARVESTERS := 2

var harvest_rate: float = 40.0  # MJ/sec per docked truck
var _harvesters: Array = []
var _pulse := 0.0

func _ready() -> void:
	add_to_group("lava_nodes")

func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 2.5, TAU)
	queue_redraw()

func assign_harvester(truck: Node) -> bool:
	if _harvesters.size() >= MAX_HARVESTERS:
		return false
	if truck not in _harvesters:
		_harvesters.append(truck)
	return true

func release_harvester(truck: Node) -> void:
	_harvesters.erase(truck)

func _draw() -> void:
	var p := (sin(_pulse) + 1.0) * 0.5  # 0..1

	# Outer glow
	draw_circle(Vector2.ZERO, RADIUS + 10.0 + p * 6.0, Color(1.0, 0.3, 0.0, 0.10))
	draw_circle(Vector2.ZERO, RADIUS + 5.0,             Color(1.0, 0.4, 0.0, 0.20))
	# Core layers
	draw_circle(Vector2.ZERO, RADIUS,          Color(0.85, 0.25, 0.04))
	draw_circle(Vector2.ZERO, RADIUS * 0.62,   Color(1.00, 0.55, 0.10))
	draw_circle(Vector2.ZERO, RADIUS * 0.32,   Color(1.00, 0.88, 0.50))
	# Harvester-docked ring
	if not _harvesters.is_empty():
		draw_arc(Vector2.ZERO, RADIUS + 3.0, 0.0, TAU, 32, Color(0.2, 1.0, 0.4, 0.85), 2.5)
