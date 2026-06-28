extends Node2D

var health: float     = 0.0
var max_health: float = 0.0
var _size:  Vector2   = Vector2(80.0, 60.0)
var _color: Color     = Color(0.75, 0.18, 0.18)
var _label: String    = ""
var is_hq:  bool      = false

func setup(sz: Vector2, col: Color, label: String, hp: float, hq: bool = false) -> void:
	_size      = sz
	_color     = col
	_label     = label
	max_health = hp
	health     = hp
	is_hq      = hq
	add_to_group("enemy_buildings")
	queue_redraw()

func get_collision_radius() -> float:
	return max(_size.x, _size.y) * 0.5 + 4.0

func contains_point(world_pos: Vector2) -> bool:
	var half := _size * 0.5
	return Rect2(global_position - half, _size).has_point(world_pos)

func take_damage(amount: float, _hit_from: Vector2 = Vector2.ZERO) -> void:
	health = maxf(0.0, health - amount)
	queue_redraw()
	if health <= 0.0:
		if is_hq:
			GameState.end_game(true)
		queue_free()

func _draw() -> void:
	var half    := _size * 0.5
	var hw      := half.x
	var hh      := half.y
	const ISO_Y := 0.55
	var H_screen := minf(_size.x, _size.y) * 0.30
	var H_local  := H_screen / ISO_Y
	var top_off  := Vector2(0.0, -H_local)

	# South face (horizontal band, plan-oblique)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-hw, hh), Vector2(hw, hh),
		Vector2(hw, hh - H_local), Vector2(-hw, hh - H_local),
	]), _color.darkened(0.45))
	# Top face
	draw_colored_polygon(PackedVector2Array([
		Vector2(-hw, -hh) + top_off, Vector2(hw, -hh) + top_off,
		Vector2(hw,  hh)  + top_off, Vector2(-hw, hh) + top_off,
	]), _color)

	var top_rect := Rect2(-hw, -hh + top_off.y, _size.x, _size.y)
	draw_rect(top_rect, Color(1.0, 0.55, 0.55, 0.5), false, 1.5)
	if _label != "":
		draw_string(ThemeDB.fallback_font,
			Vector2(-hw + 4.0, top_off.y + hh - 5.0),
			_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.75, 0.75, 0.9))
	if is_hq:
		draw_string(ThemeDB.fallback_font,
			Vector2(-hw + 4.0, top_off.y - hh + 12.0),
			"HQ", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 1.0, 0.3, 0.95))
	if health < max_health:
		var bar_y := hh + 5.0
		draw_rect(Rect2(-hw, bar_y, _size.x, 5.0), Color(0.1, 0.1, 0.1, 0.9))
		draw_rect(Rect2(-hw, bar_y, _size.x * health / max_health, 5.0), Color(1.0, 0.2, 0.1))
