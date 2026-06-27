extends Node2D

const DRAG_THRESHOLD := 5.0

var _drag_start := Vector2.ZERO
var _dragging   := false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_start = get_global_mouse_position()
				_dragging   = false
			else:
				if _dragging:
					_box_select()
				else:
					_point_select(get_global_mouse_position())
				_dragging = false
				queue_redraw()

		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_order_move(get_global_mouse_position())

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not _dragging:
			if get_global_mouse_position().distance_to(_drag_start) > DRAG_THRESHOLD:
				_dragging = true
		if _dragging:
			queue_redraw()

func _draw() -> void:
	if not _dragging:
		return
	var world_end := get_global_mouse_position()
	var rect      := Rect2(_drag_start, world_end - _drag_start)
	draw_rect(rect, Color(0.3, 0.8, 0.3, 0.15), true)
	draw_rect(rect, Color(0.3, 0.8, 0.3, 0.8), false, 1.0)

func _point_select(world_pos: Vector2) -> void:
	var units     := get_tree().get_nodes_in_group("units")
	var hit: Node = null
	var best_dist := 20.0
	for unit in units:
		var d: float = (unit as Node2D).global_position.distance_to(world_pos)
		if d < best_dist:
			best_dist = d
			hit       = unit
	for unit in units:
		unit.selected = (unit == hit)
	GameState.select_units(units.filter(func(u) -> bool: return u.selected))

func _box_select() -> void:
	var world_end := get_global_mouse_position()
	var rect      := Rect2(_drag_start, world_end - _drag_start).abs()
	var units     := get_tree().get_nodes_in_group("units")
	var sel: Array = []
	for unit in units:
		var inside: bool = rect.has_point((unit as Node2D).global_position)
		unit.selected = inside
		if inside:
			sel.append(unit)
	GameState.select_units(sel)

func _order_move(world_pos: Vector2) -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.selected:
			unit.move_target = world_pos
