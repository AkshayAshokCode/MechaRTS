extends Control

const BuildingScript = preload("res://scripts/Building.gd")

const SNAP_GRID := 32.0
const BTN_W    := 130.0
const BTN_H    :=  58.0
const BTN_PAD  :=   8.0
const PANEL_H  :=  78.0

var world_root: Node2D = null

var _ghost:        Node2D = null
var _placing       := false
var _active_type   := ""
var _menu_open     := false
var _constructor:  Node = null

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
	queue_redraw()

func is_blocking_game_input() -> bool:
	return _placing

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_B and _constructor != null:
				_menu_open = not _menu_open
				if not _menu_open:
					_cancel_placement()
				queue_redraw()
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
			if _menu_open:
				var clicked := _btn_at(mb.position)
				if clicked != "":
					_start_placement(clicked)
					get_viewport().set_input_as_handled()
				elif not _in_panel(mb.position):
					_close_menu()

		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and _placing:
			_cancel_placement()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _placing and _ghost != null:
		_ghost.position = _snap(_world_mouse())
	if _menu_open or _placing:
		queue_redraw()

func _world_mouse() -> Vector2:
	return world_root.get_global_mouse_position()

func _snap(pos: Vector2) -> Vector2:
	return (pos / SNAP_GRID).floor() * SNAP_GRID

func _start_placement(type: String) -> void:
	_cancel_placement()
	_active_type = type
	_placing     = true
	var b: Node2D = preload("res://scripts/Building.gd").new()
	b.setup(type)
	b.z_index = 30
	world_root.add_child(b)
	_ghost = b

func _confirm_placement(world_pos: Vector2) -> void:
	if _ghost == null or _constructor == null:
		return
	_ghost.position = world_pos
	_ghost.place()
	_constructor.build(_ghost)
	_ghost     = null
	_placing   = false
	_menu_open = false
	queue_redraw()

func _cancel_placement() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_placing     = false
	_active_type = ""

func _close_menu() -> void:
	_cancel_placement()
	_menu_open = false
	queue_redraw()

# --- Layout helpers ---

func _panel_origin() -> Vector2:
	var n      := BuildingScript.DEFS.size()
	var total_w := n * BTN_W + (n + 1) * BTN_PAD
	var vp     := get_viewport().get_visible_rect().size
	return Vector2((vp.x - total_w) * 0.5, vp.y - PANEL_H - 10.0)

func _in_panel(screen_pos: Vector2) -> bool:
	var o := _panel_origin()
	var n := BuildingScript.DEFS.size()
	return Rect2(o, Vector2(n * BTN_W + (n + 1) * BTN_PAD, PANEL_H)).has_point(screen_pos)

func _btn_at(screen_pos: Vector2) -> String:
	var o   := _panel_origin()
	var idx := 0
	for key in BuildingScript.DEFS:
		var bx   := o.x + BTN_PAD + idx * (BTN_W + BTN_PAD)
		var brect := Rect2(bx, o.y + BTN_PAD, BTN_W, BTN_H)
		if brect.has_point(screen_pos):
			return key
		idx += 1
	return ""

# --- Drawing ---

func _draw() -> void:
	var font := ThemeDB.fallback_font

	# Hint when constructor selected but menu closed
	if _constructor != null and not _menu_open and not _placing:
		draw_string(font, Vector2(10.0, 50.0), "B  —  Build",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.45))
		return

	if not _menu_open and not _placing:
		return

	var o   := _panel_origin()
	var n   := BuildingScript.DEFS.size()
	var total_w := n * BTN_W + (n + 1) * BTN_PAD

	# Panel background
	draw_rect(Rect2(o, Vector2(total_w, PANEL_H)), Color(0.04, 0.04, 0.09, 0.93))
	draw_rect(Rect2(o, Vector2(total_w, PANEL_H)), Color(0.45, 0.45, 0.55, 0.65), false, 1.0)

	var idx := 0
	for key in BuildingScript.DEFS:
		var def    := BuildingScript.DEFS[key] as Dictionary
		var col    := def["color"] as Color
		var bx     := o.x + BTN_PAD + idx * (BTN_W + BTN_PAD)
		var brect  := Rect2(bx, o.y + BTN_PAD, BTN_W, BTN_H)
		var active: bool = _placing and _active_type == key

		var bg := Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 0.9) if not active \
				else Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, 0.95)
		draw_rect(brect, bg)
		draw_rect(brect, col if active else Color(0.55, 0.55, 0.55, 0.7), false, 1.5)

		draw_string(font, Vector2(bx + 6.0, o.y + 27.0), def["label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.95))
		draw_string(font, Vector2(bx + 6.0, o.y + 42.0),
			"%.0f MJ  %.0fs" % [def["cost"], def["time"]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.8, 0.8, 0.75))
		idx += 1

	if _placing:
		draw_string(font, Vector2(o.x, o.y - 18.0),
			"Click to place  •  Right-click or ESC to cancel",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 1.0, 0.55, 0.9))
