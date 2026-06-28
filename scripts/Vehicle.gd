extends "res://scripts/Unit.gd"

const COLOR_IDLE     := Color(0.20, 0.55, 1.00)
const COLOR_SELECTED := Color(0.45, 0.75, 1.00)

func _ready() -> void:
	super._ready()
	max_health              = 150.0
	health                  = 150.0
	vision_range            = 220.0
	attack_range            = 180.0
	attack_damage           = 20.0
	attack_cooldown         = 1.5
	has_obstacle_avoidance  = true

func _draw() -> void:
	var col  := COLOR_SELECTED if selected else COLOR_IDLE
	var dark := col.darkened(0.45)

	# Track bands
	var tr_y1 := -RADIUS * 0.90
	var tr_y2 :=  RADIUS * 0.65
	draw_rect(Rect2(-RADIUS * 1.3, tr_y1, RADIUS * 2.6, RADIUS * 0.25), dark)
	draw_rect(Rect2(-RADIUS * 1.3, tr_y2, RADIUS * 2.6, RADIUS * 0.25), dark)
	# Track link dividers
	for i in 6:
		var x := -RADIUS * 1.3 + RADIUS * 2.6 * i / 5.0
		draw_line(Vector2(x, tr_y1), Vector2(x, tr_y1 + RADIUS * 0.25),
			col.darkened(0.25), 1.0)
		draw_line(Vector2(x, tr_y2), Vector2(x, tr_y2 + RADIUS * 0.25),
			col.darkened(0.25), 1.0)

	# Hull body
	draw_rect(Rect2(-RADIUS * 1.3, -RADIUS * 0.65, RADIUS * 2.6, RADIUS * 1.3), col)
	# Subtle upper-hull armor shadow
	draw_rect(Rect2(-RADIUS * 1.3, -RADIUS * 0.65, RADIUS * 2.6, RADIUS * 0.42), col.darkened(0.14))
	# Front grille
	draw_rect(Rect2(RADIUS * 0.88, -RADIUS * 0.38, RADIUS * 0.34, RADIUS * 0.76),
		col.darkened(0.30))

	# Turret ring + hatch
	draw_circle(Vector2.ZERO, RADIUS * 0.54, col.darkened(0.28))
	draw_circle(Vector2.ZERO, RADIUS * 0.22, col.darkened(0.48))

	# Gun barrel
	draw_line(Vector2.ZERO, Vector2(RADIUS * 1.65, 0.0), col.darkened(0.14), 4.0)
	# Barrel shroud (tip detail)
	draw_rect(Rect2(RADIUS * 1.35, -3.0, RADIUS * 0.38, 6.0), col.darkened(0.36))

	if selected:
		draw_arc(Vector2.ZERO, RADIUS + 7.0, 0.0, TAU, 32,
			Color(COLOR_SELECTED.r, COLOR_SELECTED.g, COLOR_SELECTED.b, 0.70), 1.5)
	_draw_health_bar()
