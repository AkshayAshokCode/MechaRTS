extends "res://scripts/Unit.gd"

const COLOR := Color(0.95, 0.25, 0.20)

# Head/eyes drawn at top (-Y local) → front is -Y → offset angle by 90°
func _update_facing(moved: Vector2) -> void:
	rotation = moved.angle() + PI / 2.0

func _ready() -> void:
	super._ready()
	remove_from_group("units")
	add_to_group("enemy_units")
	faction         = 1
	max_health      = 120.0
	health          = 120.0
	vision_range          = 0.0
	attack_range          = 160.0
	attack_damage         = 12.0
	attack_cooldown       = 2.0
	has_obstacle_avoidance = true

func _draw() -> void:
	# Blocky combot body
	draw_rect(Rect2(-RADIUS * 0.9, -RADIUS * 0.8, RADIUS * 1.8, RADIUS * 1.8), COLOR)
	# Shoulder pads
	draw_rect(Rect2(-RADIUS * 1.2, -RADIUS * 0.8, RADIUS * 0.5, RADIUS * 0.7), COLOR.darkened(0.2))
	draw_rect(Rect2( RADIUS * 0.7, -RADIUS * 0.8, RADIUS * 0.5, RADIUS * 0.7), COLOR.darkened(0.2))
	# Head
	draw_rect(Rect2(-RADIUS * 0.5, -RADIUS * 1.3, RADIUS, RADIUS * 0.6), COLOR.darkened(0.15))
	# Eyes
	draw_circle(Vector2(-RADIUS * 0.25, -RADIUS * 1.05), 2.5, Color(1.0, 0.9, 0.0))
	draw_circle(Vector2( RADIUS * 0.25, -RADIUS * 1.05), 2.5, Color(1.0, 0.9, 0.0))
	_draw_health_bar()
