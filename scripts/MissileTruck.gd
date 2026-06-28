extends "res://scripts/Unit.gd"

const COLOR_IDLE     := Color(0.88, 0.52, 0.12)
const COLOR_SELECTED := Color(1.00, 0.74, 0.32)

func _ready() -> void:
	super._ready()
	max_health             = 80.0
	health                 = 80.0
	vision_range           = 300.0
	attack_range           = 300.0
	attack_damage          = 38.0
	attack_cooldown        = 3.2
	has_obstacle_avoidance = true
	_speed                 = 140.0

func _draw() -> void:
	var col  := COLOR_SELECTED if selected else COLOR_IDLE
	var dark := col.darkened(0.42)

	# Wheels (4 pairs)
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(-RADIUS * 0.65, side * RADIUS * 0.58), RADIUS * 0.26, dark)
		draw_circle(Vector2( RADIUS * 0.55, side * RADIUS * 0.58), RADIUS * 0.26, dark)

	# Truck bed / body
	draw_rect(Rect2(-RADIUS * 1.10, -RADIUS * 0.50, RADIUS * 1.55, RADIUS * 1.00), col)
	# Cab (forward)
	draw_rect(Rect2( RADIUS * 0.45, -RADIUS * 0.50, RADIUS * 0.80, RADIUS * 1.00), col.darkened(0.18))
	# Windshield
	draw_rect(Rect2( RADIUS * 0.52, -RADIUS * 0.44, RADIUS * 0.56, RADIUS * 0.40), col.lightened(0.16))

	# Missile rack (3 launch tubes on top)
	draw_rect(Rect2(-RADIUS * 0.88, -RADIUS * 1.02, RADIUS * 1.50, RADIUS * 0.42), col.darkened(0.28))
	for i in 3:
		var tx := -RADIUS * 0.72 + i * RADIUS * 0.50
		draw_rect(Rect2(tx, -RADIUS * 1.14, RADIUS * 0.22, RADIUS * 0.56), dark)
		draw_circle(Vector2(tx + RADIUS * 0.11, -RADIUS * 1.10), RADIUS * 0.09,
			Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, 0.9))

	if selected:
		draw_arc(Vector2.ZERO, RADIUS + 7.0, 0.0, TAU, 32,
			Color(COLOR_SELECTED.r, COLOR_SELECTED.g, COLOR_SELECTED.b, 0.70), 1.5)
	_draw_health_bar()
