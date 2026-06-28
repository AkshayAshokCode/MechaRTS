extends Control

const BuildingScript = preload("res://scripts/Building.gd")
const SNAP_GRID := 32.0
# Right-panel width — needed to detect world clicks vs panel clicks
const PANEL_W   := 230.0
const TOP_H     := 74.0
const BOT_H     := 60.0

var world_root: Node2D = null

var _ghost:       Node2D = null
var _placing      := false
var _active_type  := ""
var _menu_open    := false
var _constructor: Node = null

# ── Public API (used by RightPanel) ───────────────────────────────────────────

func is_menu_open()   -> bool:   return _menu_open
func is_placing()     -> bool:   return _placing
func get_active_type()-> String: return _active_type

func start_placement(type: String) -> void:
	if _constructor == null:
		return
	_start_placement(type)

func is_blocking_game_input() -> bool:
	return _placing

func toggle_menu() -> void:
	_menu_open = not _menu_open
	if not _menu_open:
		_cancel_placement()

# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("build_menu")
	GameState.selection_changed.connect(_on_selection_changed)

func _on_selection_changed(units: Array) -> void:
	_constructor = null
	for u in units:
		if u.has_method("build"):
			_constructor = u
			break
	if _constructor == null:
		_close_menu()

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_B and _constructor != null:
				_menu_open = not _menu_open
				if not _menu_open:
					_cancel_placement()
				get_viewport().set_input_as_handled()
			elif ke.keycode == KEY_ESCAPE and (_menu_open or _placing):
				_close_menu()
				get_viewport().set_input_as_handled()

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _placing:
				_confirm_placement(_snap(_world_mouse()))
				get_viewport().set_input_as_handled()
				return
			# Close menu when clicking in the game world (not inside top/right panels)
			if _menu_open:
				var vp := get_viewport().get_visible_rect().size
				var in_world := mb.position.x < vp.x - PANEL_W \
					and mb.position.y > TOP_H \
					and mb.position.y < vp.y - BOT_H
				if in_world:
					_close_menu()

		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and _placing:
			_cancel_placement()
			get_viewport().set_input_as_handled()

# ── Ghost placement ────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _placing and _ghost != null:
		var snapped := _snap(_world_mouse())
		_ghost.position = snapped
		_ghost.set("placement_valid", _is_placement_valid(snapped))
		_ghost.queue_redraw()

func _world_mouse() -> Vector2:
	return world_root.get_global_mouse_position()

func _snap(pos: Vector2) -> Vector2:
	return (pos / SNAP_GRID).floor() * SNAP_GRID

func _start_placement(type: String) -> void:
	_cancel_placement()
	_active_type = type
	_placing     = true
	_menu_open   = true
	var b: Node2D = preload("res://scripts/Building.gd").new()
	b.setup(type)
	b.z_index = 30
	world_root.add_child(b)
	_ghost = b

func _confirm_placement(world_pos: Vector2) -> void:
	if _ghost == null or _constructor == null:
		return
	if not _is_placement_valid(world_pos):
		return   # blocked — keep ghost visible, let player pick another spot
	_ghost.position = world_pos
	_ghost.place()
	_constructor.build(_ghost)
	_ghost     = null
	_placing   = false
	_menu_open = false

func _cancel_placement() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_placing     = false
	_active_type = ""

func _close_menu() -> void:
	_cancel_placement()
	_menu_open = false

# Returns false if the proposed footprint at world_pos overlaps any placed building.
func _is_placement_valid(world_pos: Vector2) -> bool:
	if _ghost == null:
		return false
	var ghost_size: Vector2 = _ghost.get("_size")
	var new_rect := Rect2(world_pos - ghost_size * 0.5, ghost_size)
	const PAD := 6.0   # minimum pixel gap required between building edges
	for grp in ["buildings", "enemy_buildings"]:
		for b in get_tree().get_nodes_in_group(grp):
			if b == _ghost:
				continue
			if b.get("is_ghost") == true:
				continue
			var b_size: Variant = b.get("_size")
			if not b_size is Vector2:
				continue
			var b_half := (b_size as Vector2) * 0.5
			var padded := Rect2(
				(b as Node2D).global_position - b_half - Vector2(PAD, PAD),
				(b_size as Vector2) + Vector2(PAD * 2.0, PAD * 2.0))
			if new_rect.intersects(padded):
				return false
	return true
