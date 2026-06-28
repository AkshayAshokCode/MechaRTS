extends Node2D

const DRAG_THRESHOLD := 12.0   # screen-space pixels before press+move = drag
const PANEL_W        := 230.0  # must match RightPanel.PANEL_W
const TOP_H          := 74.0   # must match HUD.TOP_H
const BOT_H          := 60.0   # must match BottomBar.BOT_H

var _drag_start_world      := Vector2.ZERO
var _drag_start_screen     := Vector2.ZERO
var _dragging              := false
var _lmb_started_in_game   := false   # press was in the game area, not UI

var _move_marker_pos:   Vector2 = Vector2.ZERO
var _move_marker_timer: float   = 0.0

var _pings:             Array   = []   # [{pos, timer}]
var _cursor_is_cross:   bool    = false
var _patrol_mode:       bool    = false   # true: next right-click sets patrol destination

func _ready() -> void:
	add_to_group("selection_manager")
	GameState.ping_at.connect(func(world_pos: Vector2) -> void:
		_pings.append({"pos": world_pos, "timer": 2.5}))

func _process(delta: float) -> void:
	if _move_marker_timer > 0.0:
		_move_marker_timer = maxf(0.0, _move_marker_timer - delta)
		queue_redraw()

	for i in range(_pings.size() - 1, -1, -1):
		_pings[i]["timer"] -= delta
		if _pings[i]["timer"] <= 0.0:
			_pings.remove_at(i)
	if not _pings.is_empty():
		queue_redraw()

	# Attack cursor: crosshair when a unit is selected and mouse is over an enemy
	var mp := get_viewport().get_mouse_position()
	var panel_x := get_viewport().get_visible_rect().size.x - 230.0
	if mp.x < panel_x:
		var should_cross := false
		if not GameState.selected_units.is_empty():
			var world_pos := get_global_mouse_position()
			should_cross = _enemy_at(world_pos) != null
		if should_cross != _cursor_is_cross:
			_cursor_is_cross = should_cross
			DisplayServer.cursor_set_shape(
				DisplayServer.CURSOR_CROSS if should_cross else DisplayServer.CURSOR_ARROW)

func _unhandled_input(event: InputEvent) -> void:
	# Let BuildMenu own all input while ghost placement is active
	var bm := get_tree().get_first_node_in_group("build_menu")
	if bm != null and bm.is_blocking_game_input():
		return

	# Key bindings
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			match ke.keycode:
				KEY_V:
					_try_queue_vehicle()
					get_viewport().set_input_as_handled()
				KEY_S:
					for unit in _selected_units():
						unit.move_target = (unit as Node2D).global_position
					get_viewport().set_input_as_handled()
				KEY_H:
					# Hold position — identical to stop in current model
					for unit in _selected_units():
						unit.move_target = (unit as Node2D).global_position
					get_viewport().set_input_as_handled()
				KEY_A:
					# Attack-move: move to mouse world position; auto-attack fires en route
					var world_pos := get_global_mouse_position()
					_order_move(world_pos)
					get_viewport().set_input_as_handled()
				KEY_P:
					if not _selected_units().is_empty():
						toggle_patrol_mode()
					get_viewport().set_input_as_handled()
		return

	if not event is InputEventMouseButton and not event is InputEventMouseMotion:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var vp_h := get_viewport().get_visible_rect().size.y
		var in_ui := _in_right_panel(mb.position) or mb.position.y <= TOP_H \
				or mb.position.y >= vp_h - BOT_H

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_lmb_started_in_game = not in_ui
				if in_ui:
					return
				_drag_start_world  = get_global_mouse_position()
				_drag_start_screen = mb.position
				_dragging          = false
			else:
				if not _lmb_started_in_game:
					return
				_lmb_started_in_game = false
				if _dragging:
					_box_select()
				else:
					_point_select(get_global_mouse_position())
				_dragging = false
				queue_redraw()
			get_viewport().set_input_as_handled()

		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if in_ui:
				return
			var world_pos := get_global_mouse_position()
			if _patrol_mode:
				_order_patrol(world_pos)
				get_viewport().set_input_as_handled()
				return
			var pickup    := _pickup_at(world_pos)
			var enemy     := _enemy_at(world_pos)
			var healable  := _healable_at(world_pos)
			var lava      := _lava_node_at(world_pos)
			var ubuilt    := _unbuilt_building_at(world_pos)
			if pickup:
				_order_pickup(pickup)
			elif enemy:
				_order_attack(enemy)
			elif healable:
				_order_heal(healable)
			elif lava:
				_order_harvest(lava)
			elif ubuilt:
				_order_build(ubuilt)
			else:
				_order_move(world_pos)
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not _lmb_started_in_game:
			return
		var dist := (event as InputEventMouseMotion).position.distance_to(_drag_start_screen)
		if not _dragging and dist > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			queue_redraw()

func _draw() -> void:
	# Patrol routes for selected units
	for unit in _selected_units():
		if unit.get("unit_state") != 3:   # STATE_PATROL
			continue
		var pts = unit.get("patrol_points")
		if not (pts is Array) or (pts as Array).size() < 2:
			continue
		var p0: Vector2 = pts[0]
		var p1: Vector2 = pts[1]
		# Dashed-style line via short segments
		var seg := p1 - p0
		var seg_len := seg.length()
		var seg_dir := seg / seg_len if seg_len > 0.001 else Vector2.RIGHT
		var dash := 12.0
		var gap  := 8.0
		var t    := 0.0
		while t < seg_len:
			var a := p0 + seg_dir * t
			var b := p0 + seg_dir * minf(t + dash, seg_len)
			draw_line(a, b, Color(0.35, 1.00, 0.55, 0.55), 1.5)
			t += dash + gap
		draw_circle(p0, 5.0, Color(0.35, 1.00, 0.55, 0.75))
		draw_circle(p1, 5.0, Color(0.35, 1.00, 0.55, 0.75))
		# Arrow at each end
		var arw0 := seg_dir.rotated(PI * 0.75) * 7.0
		var arw1 := seg_dir.rotated(-PI * 0.75) * 7.0
		draw_line(p1, p1 + arw0, Color(0.35, 1.00, 0.55, 0.70), 1.5)
		draw_line(p1, p1 + arw1, Color(0.35, 1.00, 0.55, 0.70), 1.5)

	# Move marker pulse
	if _move_marker_timer > 0.0:
		var t     := _move_marker_timer / 0.55
		var alpha := t * 0.80
		var r     := 8.0 + (1.0 - t) * 20.0
		draw_circle(_move_marker_pos, r, Color(0.35, 1.00, 0.45, alpha * 0.25))
		draw_arc(_move_marker_pos, r, 0.0, TAU, 24, Color(0.35, 1.00, 0.45, alpha), 1.8)

	# Minimap pings — three expanding concentric rings, cyan
	for ping in _pings:
		var life  : float = ping["timer"]          # 2.5 → 0
		var t     : float = 1.0 - life / 2.5      # 0 → 1
		var alpha : float = life / 2.5             # 1 → 0
		for ring in 3:
			var phase := fmod(t + ring * 0.33, 1.0)
			var r     := 20.0 + phase * 80.0
			draw_arc(ping["pos"], r, 0.0, TAU, 32,
				Color(0.10, 0.90, 1.00, alpha * (1.0 - phase) * 0.75), 2.0)

	# Drag-select box
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

func _unbuilt_building_at(world_pos: Vector2) -> Node:
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.get("is_ghost") == true or b.get("is_built") == true:
			continue
		if b.has_method("contains_point") and b.contains_point(world_pos):
			return b
	return null

func _order_attack(target: Node) -> void:
	var target_pos := (target as Node2D).global_position
	var sel     := _selected_units()
	var facing  := (target_pos - _selection_centroid()).normalized()
	var offsets := _formation_offsets(sel.size(), 60.0, facing)
	for i in sel.size():
		var unit: Node = sel[i]
		if unit.has_method("stop_harvesting"): unit.stop_harvesting()
		if unit.has_method("stop_building"):   unit.stop_building()
		if unit.has_method("stop_healing"):    unit.stop_healing()
		unit.move_target = target_pos + offsets[i]
		if unit.has_method("flash_order"):     unit.flash_order()

func _order_build(building: Node) -> void:
	for unit in _selected_units():
		if unit.has_method("build"):
			unit.build(building)

func _order_harvest(node: Node) -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.selected and unit.has_method("harvest"):
			unit.harvest(node)

func toggle_patrol_mode() -> void:
	# If any selected unit is patrolling, cancel all patrols and leave mode
	var any_patrolling := false
	for u in _selected_units():
		if u.get("unit_state") == 3:   # STATE_PATROL
			any_patrolling = true
			break
	if any_patrolling:
		for u in _selected_units():
			if u.has_method("cancel_patrol"):
				u.cancel_patrol()
		_patrol_mode = false
	else:
		_patrol_mode = not _patrol_mode
	queue_redraw()

func _order_patrol(world_pos: Vector2) -> void:
	var sel     := _selected_units()
	var facing  := (world_pos - _selection_centroid()).normalized()
	var offsets := _formation_offsets(sel.size(), 60.0, facing)
	for i in sel.size():
		var unit: Node = sel[i]
		if unit.has_method("set_patrol"):
			unit.set_patrol((unit as Node2D).global_position, world_pos + offsets[i])
	_patrol_mode       = false
	_move_marker_pos   = world_pos
	_move_marker_timer = 0.55
	queue_redraw()

func _order_move(world_pos: Vector2) -> void:
	var sel     := _selected_units()
	var facing  := (world_pos - _selection_centroid()).normalized()
	var offsets := _formation_offsets(sel.size(), 60.0, facing)
	for i in sel.size():
		var unit: Node = sel[i]
		if unit.has_method("stop_harvesting"): unit.stop_harvesting()
		if unit.has_method("stop_building"):   unit.stop_building()
		if unit.has_method("stop_healing"):    unit.stop_healing()
		unit.move_target = world_pos + offsets[i]
		if unit.has_method("flash_order"):     unit.flash_order()
	_move_marker_pos   = world_pos
	_move_marker_timer = 0.55

func _selected_units() -> Array:
	var sel: Array = []
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.selected:
			sel.append(unit)
	return sel

# Returns an Array of Vector2 offsets arranged in a centred grid.
# Builds per-unit target offsets around a destination point.
# facing  = normalised direction of travel (group centroid → target).
# Row 0 lands at the destination; extra rows trail behind it.
# spacing must be > SEPARATION_RADIUS (52) so units don't push each other off their spots.
func _formation_offsets(count: int, spacing: float,
		facing: Vector2 = Vector2(0.0, 1.0)) -> Array:
	if count <= 1:
		return [Vector2.ZERO]
	var fwd   := facing.normalized() if facing.length_squared() > 0.01 else Vector2(0.0, 1.0)
	var right := Vector2(-fwd.y, fwd.x)   # perpendicular axis
	var back  := -fwd                      # rows trail away from destination
	var cols  : int = ceili(sqrt(float(count)))
	var offsets: Array = []
	for i in count:
		var row : int = i / cols
		var col : int = i % cols
		var cols_in_row : int = mini(cols, count - row * cols)
		# Centre each row horizontally, trail rows backward from the target
		var ox := (col - (cols_in_row - 1) * 0.5) * spacing
		var oy := float(row) * spacing
		offsets.append(right * ox + back * oy)
	return offsets

# Returns the centroid of currently selected units (world space).
func _selection_centroid() -> Vector2:
	var sel := _selected_units()
	if sel.is_empty():
		return Vector2.ZERO
	var c := Vector2.ZERO
	for u in sel:
		c += (u as Node2D).global_position
	return c / float(sel.size())

func _healable_at(world_pos: Vector2) -> Node:
	# Friendly units with missing health
	for unit in get_tree().get_nodes_in_group("units"):
		var h  = unit.get("health")
		var mh = unit.get("max_health")
		if h == null or mh == null or h >= mh:
			continue
		if (unit as Node2D).global_position.distance_to(world_pos) <= 44.0:
			return unit
	# Player buildings (built, damaged)
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.get("is_built") != true:
			continue
		var h  = b.get("health")
		var mh = b.get("max_health")
		if h == null or mh == null or h >= mh:
			continue
		if b.has_method("contains_point") and b.contains_point(world_pos):
			return b
	return null

func _order_heal(target: Node) -> void:
	for unit in _selected_units():
		if unit == target:
			continue
		if unit.has_method("heal"):
			unit.heal(target)
		if unit.has_method("flash_order"):
			unit.flash_order()

func _try_queue_vehicle() -> void:
	var sb := GameState.selected_building
	if sb != null and is_instance_valid(sb) and sb.has_method("queue_vehicle"):
		sb.queue_vehicle()
