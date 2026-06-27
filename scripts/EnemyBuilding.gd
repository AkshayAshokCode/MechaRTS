extends Node2D

var health: float     = 0.0
var max_health: float = 0.0
var _size:  Vector2   = Vector2(80.0, 60.0)
var _color: Color     = Color(0.75, 0.18, 0.18)
var _label: String    = ""

func setup(sz: Vector2, col: Color, label: String, hp: float) -> void:
	_size      = sz
	_color     = col
	_label     = label
	max_health = hp
	health     = hp
	add_to_group("enemy_buildings")
	queue_redraw()

func get_collision_radius() -> float:
	return max(_size.x, _size.y) * 0.5 + 4.0

func contains_point(world_pos: Vector2) -> bool:
	var half := _size * 0.5
	return Rect2(global_position - half, _size).has_point(world_pos)

func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	queue_redraw()
	if health <= 0.0:
		queue_free()

func _draw() -> void:
	var half := _size * 0.5
	var rect := Rect2(-half, _size)
	draw_rect(rect, _color)
	draw_rect(rect, Color(1.0, 0.55, 0.55, 0.5), false, 1.5)
	if _label != "":
		draw_string(ThemeDB.fallback_font, Vector2(-half.x + 4.0, half.y - 5.0),
			_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.75, 0.75, 0.9))
	if health < max_health:
		var bar_w := _size.x
		var bar_y := half.y + 5.0
		draw_rect(Rect2(-half.x, bar_y, bar_w, 5.0), Color(0.1, 0.1, 0.1, 0.9))
		draw_rect(Rect2(-half.x, bar_y, bar_w * health / max_health, 5.0),
			Color(1.0, 0.2, 0.1))
