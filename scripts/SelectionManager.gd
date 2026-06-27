extends Node2D

const DRAG_THRESHOLD := 12.0   # screen-space pixels before press+move = drag
const PANEL_W        := 230.0  # must match RightPanel.PANEL_W
const TOP_H          := 74.0   # must match HUD.TOP_H
const BOT_H          := 60.0   # must match BottomBar.BOT_H

var _drag_start_world  := Vector2.ZERO
var _drag_start_screen := Vector2.ZERO
var _dragging          := false

func _input(event: InputEvent) -> void:
	# Let BuildMenu own all input while ghost placement is active
	var bm := get_tree().get_first_node_in_group("build_menu")
	if bm != null and bm.is_blocking_game_input():
		return

	# Key bindings
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_V:
				_try_queue_vehicle()
				get_viewport().set_input_as_handled()
		return

	if not event is InputEventMouseButton and not event is InputEventMouseMotion:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		var vp_h := get_viewport().get_visible_rect().size.y
		if _in_right_panel(mb.position) or mb.position.y <= TOP_H \
				or mb.position.y >= vp_h - BOT_H:
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
			var pickup    := _pickup_at(world_pos)
			var enemy     := _enemy_at(world_pos)
			var lava      := _lava_node_at(world_pos)
			if pickup:
				_order_pickup(pickup)
			elif enemy:
				_order_attack(enemy)
			elif lava:
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

func _in_right_panel(screen_pos: Vector2) -> bool:
	return screen_pos.x >= get_viewport().get_visible_rect().size.x - PANEL_W

func _point_select(world_pos: Vector2) -> void:
	var units := get_tree().get_nodes_in_group("units")

	# Units take priority over buildings
	var hit: Node = null
	var best_dist := 24.0
	for unit in units:
		var d: float = (unit as Node2D).global_position.distance_to(world_pos)
		if d < best_dist:
			best_dist = d
			hit       = unit

	if hit != null:
		for unit in units:
			unit.selected = (unit == hit)
		GameState.select_units(units.filter(func(u) -> bool: return u.selected))
		GameState.select_building(null)
		return

	# Check player buildings
	for building in get_tree().get_nodes_in_group("buildings"):
		if building.has_method("contains_point") and building.contains_point(world_pos):
			for unit in units:
				unit.selected = false
			GameState.select_units([])
			GameState.select_building(building)
			return

	# Nothing hit — deselect everything
	for unit in units:
		unit.selected = false
	GameState.select_units([])
	GameState.select_building(null)

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
	GameState.select_building(null)

func _enemy_at(world_pos: Vector2) -> Node:
	var best: Node = null
	var best_dist  := 44.0
	for node in get_tree().get_nodes_in_group("enemy_units"):
		var d := (node as Node2D).global_position.distance_to(world_pos)
		if d < best_dist:
			best_dist = d
			best      = node
	if best != null:
		return best
	for node in get_tree().get_nodes_in_group("enemy_buildings"):
		if node.has_method("contains_point"):
			if node.contains_point(world_pos):
				return node
		else:
			var d := (node as Node2D).global_position.distance_to(world_pos)
			if d < best_dist:
				best = node
	return best

func _pickup_at(world_pos: Vector2) -> Node:
	for node in get_tree().get_nodes_in_group("part_pickups"):
		if is_instance_valid(node):
			if (node as Node2D).global_position.distance_to(world_pos) <= 30.0:
				return node
	return null

func _order_pickup(node: Node) -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.selected and unit.has_method("pickup"):
			unit.pickup(node)

func _lava_node_at(world_pos: Vector2) -> Node:
	for node in get_tree().get_nodes_in_group("lava_nodes"):
		if (node as Node2D).global_position.distance_to(world_pos) <= 44.0:
			return node
	return null

func _order_attack(target: Node) -> void:
	var target_pos := (target as Node2D).global_position
	var sel := _selected_units()
	var offsets := _formation_offsets(sel.size(), 36.0)
	for i in sel.size():
		var unit: Node = sel[i]
		if unit.has_method("stop_harvesting"): unit.stop_harvesting()
		if unit.has_method("stop_building"):   unit.stop_building()
		unit.move_target = target_pos + offsets[i]

func _order_harvest(node: Node) -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.selected and unit.has_method("harvest"):
			unit.harvest(node)

func _order_move(world_pos: Vector2) -> void:
	var sel := _selected_units()
	var offsets := _formation_offsets(sel.size(), 42.0)
	for i in sel.size():
		var unit: Node = sel[i]
		if unit.has_method("stop_harvesting"): unit.stop_harvesting()
		if unit.has_method("stop_building"):   unit.stop_building()
		unit.move_target = world_pos + offsets[i]

func _selected_units() -> Array:
	var sel: Array = []
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.selected:
			sel.append(unit)
	return sel

# Returns an Array of Vector2 offsets arranged in a centred grid.
func _formation_offsets(count: int, spacing: float) -> Array:
	if count <= 1:
		return [Vector2.ZERO]
	var offsets: Array = []
	var cols: int = ceili(sqrt(float(count)))
	var rows: int = ceili(float(count) / float(cols))
	var total_h: float = (rows - 1) * spacing
	for i in count:
		var row: int = i / cols
		var col: int = i % cols
		var cols_in_row: int = min(cols, count - row * cols)
		var ox: float = (col - (cols_in_row - 1) * 0.5) * spacing
		var oy: float = row * spacing - total_h * 0.5
		offsets.append(Vector2(ox, oy))
	return offsets

func _try_queue_vehicle() -> void:
	var sb := GameState.selected_building
	if sb != null and is_instance_valid(sb) and sb.has_method("queue_vehicle"):
		sb.queue_vehicle()
