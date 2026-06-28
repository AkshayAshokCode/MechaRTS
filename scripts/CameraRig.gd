extends Camera2D

const MAP_SIZE    := Vector2(6400.0, 4800.0)
const PAN_SPEED   := 400.0
const EDGE_MARGIN := 20
const ZOOM_STEP   := 0.1
const ZOOM_MIN    := 0.5
const ZOOM_MAX    := 2.0

var _drag_active      := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_cam   := Vector2.ZERO

func _ready() -> void:
	add_to_group("camera_rig")
	limit_left   = 0
	limit_top    = 0
	limit_right  = int(MAP_SIZE.x)
	limit_bottom = int(MAP_SIZE.y)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_drag_active = true
				_drag_start_mouse = mb.position
				_drag_start_cam   = global_position
			else:
				_drag_active = false

		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom = Vector2.ONE * clampf(zoom.x + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom = Vector2.ONE * clampf(zoom.x - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)

	if event is InputEventMouseMotion and _drag_active:
		var delta := (event as InputEventMouseMotion).position - _drag_start_mouse
		global_position = _drag_start_cam - delta / zoom.x

	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_SPACE:
			_snap_to_hq()
			get_viewport().set_input_as_handled()

func _snap_to_hq() -> void:
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.get("is_hq") == true and b.get("is_built") == true:
			global_position = (b as Node2D).global_position
			return

func _process(delta: float) -> void:
	if _drag_active:
		return

	var vp_size := get_viewport().get_visible_rect().size
	var mp      := get_viewport().get_mouse_position()
	var move    := Vector2.ZERO

	if mp.x < EDGE_MARGIN:                move.x -= 1.0
	elif mp.x > vp_size.x - EDGE_MARGIN:  move.x += 1.0
	if mp.y < EDGE_MARGIN:                move.y -= 1.0
	elif mp.y > vp_size.y - EDGE_MARGIN:  move.y += 1.0

	# Arrow keys only for camera pan — WASD is reserved for unit commands
	move.x += float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT))
	move.y += float(Input.is_key_pressed(KEY_DOWN))  - float(Input.is_key_pressed(KEY_UP))

	if move != Vector2.ZERO:
		global_position += move.normalized() * PAN_SPEED * delta / zoom.x
