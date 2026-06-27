extends Node2D

const SPEED  := 120.0
const RADIUS := 12.0

var vision_range := 200.0
var move_target  := Vector2.ZERO

var selected := false:
	set(v):
		selected = v
		queue_redraw()

func _ready() -> void:
	add_to_group("units")
	move_target = global_position
	queue_redraw()

func _physics_process(delta: float) -> void:
	var to_target := move_target - global_position
	if to_target.length_squared() > 4.0:
		global_position += to_target.normalized() * SPEED * delta

func _draw() -> void:
	var color := Color(0.2, 0.8, 0.3) if not selected else Color(0.4, 1.0, 0.5)
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_arc(Vector2.ZERO, RADIUS + 1.5, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.5), 1.5)
	if selected:
		draw_arc(Vector2.ZERO, RADIUS + 5.0, 0.0, TAU, 32, Color(0.4, 1.0, 0.5, 0.7), 1.5)
