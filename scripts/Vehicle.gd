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
	var col := COLOR_SELECTED if selected else COLOR_IDLE
	# Tracks
	draw_rect(Rect2(-RADIUS * 1.3, -RADIUS * 0.9, RADIUS * 2.6, RADIUS * 0.25), col.darkened(0.45))
	draw_rect(Rect2(-RADIUS * 1.3,  RADIUS * 0.65, RADIUS * 2.6, RADIUS * 0.25), col.darkened(0.45))
	# Hull
	draw_rect(Rect2(-RADIUS * 1.3, -RADIUS * 0.65, RADIUS * 2.6, RADIUS * 1.3), col)
	# Turret
	draw_circle(Vector2.ZERO, RADIUS * 0.52, col.darkened(0.3))
	# Gun barrel (points right)
	draw_line(Vector2.ZERO, Vector2(RADIUS * 1.6, 0.0), col.darkened(0.15), 3.5)
	if selected:
		draw_arc(Vector2.ZERO, RADIUS + 6.0, 0.0, TAU, 32,
			Color(COLOR_SELECTED.r, COLOR_SELECTED.g, COLOR_SELECTED.b, 0.70), 1.5)
	_draw_health_bar()
