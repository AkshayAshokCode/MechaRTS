extends Node2D

const PICKUP_RADIUS := 28.0   # HoverTruck must be within this to collect
const PULSE_SPEED   := 2.8

var part_data: Dictionary = {}
var _age: float = 0.0

func setup(p: Dictionary, world_pos: Vector2) -> void:
	part_data = p
	position  = world_pos
	add_to_group("part_pickups")
	z_index   = 20

func _process(delta: float) -> void:
	_age += delta
	queue_redraw()

func _draw() -> void:
	var col: Color = part_data.get("col", Color.WHITE)
	var pulse := 0.65 + 0.35 * sin(_age * PULSE_SPEED)

	# Glow ring (pulsing)
	draw_arc(Vector2.ZERO, PICKUP_RADIUS * 0.55, 0.0, TAU, 32,
		Color(col.r, col.g, col.b, 0.28 * pulse), 6.0)
	# Solid core
	draw_circle(Vector2.ZERO, 9.0,
		Color(col.r * 0.45, col.g * 0.45, col.b * 0.45, 0.90))
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 24,
		Color(col.r, col.g, col.b, 0.90 * pulse), 2.0)

	# Slot initial (T / L / A)
	var font := ThemeDB.fallback_font
	var slot_str: String = part_data.get("slot", "?")
	var abbr: String = slot_str.substr(0, 1).to_upper()
	draw_string(font, Vector2(-4.0, 5.0), abbr,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 1.0, 1.0, 0.95 * pulse))
