extends "res://scripts/Unit.gd"

const COLOR_IDLE     := Color(0.18, 0.80, 0.72)
const COLOR_SELECTED := Color(0.42, 1.00, 0.92)

func _ready() -> void:
	super._ready()
	max_health             = 100.0
	health                 = 100.0
	vision_range           = 240.0
	attack_range           = 165.0
	attack_damage          = 18.0
	attack_cooldown        = 1.2
	has_obstacle_avoidance = true
	_speed                 = 165.0

func _draw() -> void:
	var col  := COLOR_SELECTED if selected else COLOR_IDLE
	var dark := col.darkened(0.44)

	# Hover skirts (wide flat bands top + bottom)
	draw_rect(Rect2(-RADIUS * 1.38, -RADIUS * 0.85, RADIUS * 2.76, RADIUS * 0.48), dark)
	draw_rect(Rect2(-RADIUS * 1.38,  RADIUS * 0.37, RADIUS * 2.76, RADIUS * 0.48), dark)

	# Hover vent glow along bottom skirt
	for i in 5:
		var vx := -RADIUS * 1.10 + i * RADIUS * 0.54
		draw_circle(Vector2(vx, RADIUS * 0.52), RADIUS * 0.11,
			Color(col.r, col.g, col.b, 0.50))

	# Sleek main hull
	draw_rect(Rect2(-RADIUS * 1.12, -RADIUS * 0.52, RADIUS * 2.24, RADIUS * 1.04), col)
	# Nose wedge
	draw_rect(Rect2( RADIUS * 0.72, -RADIUS * 0.36, RADIUS * 0.40, RADIUS * 0.72),
		col.lightened(0.10))

	# Slim turret ring
	draw_circle(Vector2.ZERO, RADIUS * 0.38, col.darkened(0.24))
	draw_circle(Vector2.ZERO, RADIUS * 0.14, col.darkened(0.40))

	# Slim barrel
	draw_line(Vector2.ZERO, Vector2(RADIUS * 1.50, 0.0), col.darkened(0.10), 2.5)
	draw_rect(Rect2(RADIUS * 1.22, -2.0, RADIUS * 0.32, 4.0), col.darkened(0.34))

	if selected:
		draw_arc(Vector2.ZERO, RADIUS + 7.0, 0.0, TAU, 32,
			Color(COLOR_SELECTED.r, COLOR_SELECTED.g, COLOR_SELECTED.b, 0.70), 1.5)
	_draw_health_bar()
