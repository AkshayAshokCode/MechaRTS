extends Node2D

# ── Constants ─────────────────────────────────────────────────────────────────
const MAP_SIZE    := Vector2(6400.0, 4800.0)
const PAN_SPEED   := 550.0
const EDGE_MARGIN := 20
const ZOOM_STEP   := 0.08
const ZOOM_MIN    := 0.12
const ZOOM_MAX    := 2.5

# Plan-oblique projection (Metal Fatigue / StarCraft style):
#   world +X → screen right         (1,  0.0) — horizontal
#   world +Y → screen down×0.55     (0,  0.55) — compressed vertical
# Map stays axis-aligned; height shows as straight-up shift on screen.
const ISO    := Transform2D(Vector2(1.0, 0.0), Vector2(0.0, 0.55), Vector2.ZERO)
const ISO_Y  := 0.55  # Y scale factor — used by building/unit code to invert the offset

# ── State ─────────────────────────────────────────────────────────────────────
var camera_pos  : Vector2 = Vector2.ZERO
var camera_zoom : float   = 2.0    # zoomed-in default — clamp prevents black borders

var _drag_active      := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_cam   := Vector2.ZERO

func _ready() -> void:
	add_to_group("camera_rig")
	camera_pos = position
	# Defer so the in-game viewport size is known before the first clamp.
	# _ready() runs during scene-tree setup when get_visible_rect() may still
	# report the full display resolution instead of the actual game window.
	call_deferred("_apply_transform")

# ── Canvas transform ──────────────────────────────────────────────────────────
# screen_pos = T_center * S_zoom * ISO * T_neg_cam * world_pos
func _apply_transform() -> void:
	camera_pos = _clamp(camera_pos)
	var vp := get_viewport().get_visible_rect().size
	get_viewport().canvas_transform = (
		Transform2D.IDENTITY.translated(vp * 0.5) *
		Transform2D(Vector2(camera_zoom, 0.0), Vector2(0.0, camera_zoom), Vector2.ZERO) *
		ISO *
		Transform2D.IDENTITY.translated(-camera_pos)
	)

# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_drag_active      = true
				_drag_start_mouse = mb.position
				_drag_start_cam   = camera_pos
			else:
				_drag_active = false

		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera_zoom = clampf(camera_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
				_apply_transform()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera_zoom = clampf(camera_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
				_apply_transform()

	if event is InputEventMouseMotion and _drag_active:
		# Convert screen drag delta to world delta via the iso inverse
		var screen_delta := (event as InputEventMouseMotion).position - _drag_start_mouse
		var world_delta  := ISO.affine_inverse().basis_xform(screen_delta) / camera_zoom
		camera_pos = _clamp((_drag_start_cam - world_delta))
		_apply_transform()

	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_SPACE:
			_snap_to_hq()
			get_viewport().set_input_as_handled()

func _snap_to_hq() -> void:
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.get("is_hq") == true and b.get("is_built") == true:
			camera_pos = (b as Node2D).global_position
			_apply_transform()
			return

# ── Process (edge scroll + arrow keys) ───────────────────────────────────────
func _process(delta: float) -> void:
	if not _drag_active:
		var vp_size := get_viewport().get_visible_rect().size
		var mp      := get_viewport().get_mouse_position()
		var move    := Vector2.ZERO

		if mp.x < EDGE_MARGIN:               move.x -= 1.0
		elif mp.x > vp_size.x - EDGE_MARGIN: move.x += 1.0
		if mp.y < EDGE_MARGIN:               move.y -= 1.0
		elif mp.y > vp_size.y - EDGE_MARGIN: move.y += 1.0

		move.x += float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT))
		move.y += float(Input.is_key_pressed(KEY_DOWN))  - float(Input.is_key_pressed(KEY_UP))

		if move != Vector2.ZERO:
			# Convert screen-space direction to world-space direction, then normalize
			var world_dir := ISO.affine_inverse().basis_xform(move.normalized()).normalized()
			camera_pos = _clamp(camera_pos + world_dir * PAN_SPEED * delta / camera_zoom)

	_apply_transform()

func _clamp(pos: Vector2) -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var hw  := vp.x * 0.5 / camera_zoom
	var hh  := vp.y * 0.5 / (camera_zoom * ISO_Y)
	var lo_x := minf(hw, MAP_SIZE.x * 0.5)
	var hi_x := maxf(MAP_SIZE.x - hw, lo_x)
	var lo_y := minf(hh, MAP_SIZE.y * 0.5)
	var hi_y := maxf(MAP_SIZE.y - hh, lo_y)
	return Vector2(clampf(pos.x, lo_x, hi_x), clampf(pos.y, lo_y, hi_y))
