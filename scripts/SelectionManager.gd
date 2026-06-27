extends Node2D

const DRAG_THRESHOLD := 12.0  # screen-space pixels before press+move = drag

# Must match MiniMap constants
const MM_SIZE   := Vector2(200.0, 150.0)
const MM_MARGIN := Vector2(10.0, 10.0)

var _drag_start_world  := Vector2.ZERO
var _drag_start_screen := Vector2.ZERO
var _dragging          := false

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton and not event is InputEventMouseMotion:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		# Let minimap handle its own area
		if _in_minimap(mb.position):
			return

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_start_world  = get_global_mouse_position()
				_drag_start_screen = mb.position
				_dragging          = false
			else:
				if _dragging:
					_box_select()
				else:
					_point_select(get_global_mouse_position())
				_dragging = false
				queue_redraw()
			get_viewport().set_input_as_handled()

		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var world_pos := get_global_mouse_position()
			var lava      := _lava_node_at(world_pos)
			if lava:
				_order_harvest(lava)
			else:
				_order_move(world_pos)
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var dist := (event as InputEventMouseMotion).position.distance_to(_drag_start_screen)
		if not _dragging and dist > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			queue_redraw()

func _draw() -> void:
	if not _dragging:
		return
	var world_end := get_global_mouse_position()
	var rect      := Rect2(_drag_start_world, world_end - _drag_start_world)
	draw_rect(rect, Color(0.3, 0.8, 0.3, 0.15), true)
	draw_rect(rect, Color(0.3, 0.8, 0.3, 0.8), false, 1.0)

func _in_minimap(screen_pos: Vector2) -> bool:
	var origin := get_viewport().get_visible_rect().size - MM_SIZE - MM_MARGIN
	return Rect2(origin, MM_SIZE).has_point(screen_pos)

func _point_select(world_pos: Vector2) -> void:
	var units     := get_tree().get_nodes_in_group("units")
	var hit: Node = null
	var best_dist := 24.0
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
	var rect      := Rect2(_drag_start_world, world_end - _drag_start_world).abs()
	if rect.size.length() < 10.0:
		_point_select(get_global_mouse_position())
		return
	var units  := get_tree().get_nodes_in_group("units")
	var sel: Array = []
	for unit in units:
		var inside: bool = rect.has_point((unit as Node2D).global_position)
		unit.selected = inside
		if inside:
			sel.append(unit)
	GameState.select_units(sel)

func _lava_node_at(world_pos: Vector2) -> Node:
	for node in get_tree().get_nodes_in_group("lava_nodes"):
		if (node as Node2D).global_position.distance_to(world_pos) <= 44.0:
			return node
	return null

func _order_harvest(node: Node) -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.selected and unit.has_method("harvest"):
			unit.harvest(node)

func _order_move(world_pos: Vector2) -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.selected:
			if unit.has_method("stop_harvesting"):
				unit.stop_harvesting()
			unit.move_target = world_pos
