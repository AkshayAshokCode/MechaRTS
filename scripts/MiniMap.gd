extends Control

const MAP_SIZE  := Vector2(6400.0, 4800.0)
const MM_SIZE   := Vector2(200.0, 150.0)
const MM_MARGIN := Vector2(10.0, 10.0)

func _process(_delta: float) -> void:
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var origin := _mm_origin()
			if Rect2(origin, MM_SIZE).has_point(mb.position):
				var rel      := (mb.position - origin) / MM_SIZE
				var world_pos := rel * MAP_SIZE
				var cam: Camera2D = get_tree().get_first_node_in_group("camera_rig")
				if cam:
					cam.global_position = world_pos
				get_viewport().set_input_as_handled()

func _mm_origin() -> Vector2:
	return get_viewport().get_visible_rect().size - MM_SIZE - MM_MARGIN

func _draw() -> void:
	var origin := _mm_origin()

	draw_rect(Rect2(origin, MM_SIZE), Color(0.05, 0.05, 0.08, 0.92))

	var fog: Node = get_tree().get_first_node_in_group("fog_of_war")
	if fog:
		_draw_fog(fog, origin)

	for unit in get_tree().get_nodes_in_group("units"):
		var rel := (unit as Node2D).global_position / MAP_SIZE
		var dot := origin + rel * MM_SIZE
		draw_circle(dot, 3.0, Color(0.4, 1.0, 0.5) if unit.selected else Color(0.2, 0.8, 0.3))

	var cam: Camera2D = get_tree().get_first_node_in_group("camera_rig")
	if cam:
		var vp_size  := get_viewport().get_visible_rect().size
		var cam_tl   := cam.global_position - vp_size * 0.5 / cam.zoom
		var cam_sz   := vp_size / cam.zoom
		var tl       := origin + (cam_tl / MAP_SIZE) * MM_SIZE
		var sz       := (cam_sz / MAP_SIZE) * MM_SIZE
		draw_rect(Rect2(tl, sz), Color(1.0, 1.0, 1.0, 0.35), false, 1.0)

	draw_rect(Rect2(origin, MM_SIZE), Color(0.6, 0.6, 0.6, 0.9), false, 1.0)

func _draw_fog(fog: Node, origin: Vector2) -> void:
	const SCOLS := 50
	const SROWS := 38
	var cw := MM_SIZE.x / SCOLS
	var ch := MM_SIZE.y / SROWS
	for sy in SROWS:
		for sx in SCOLS:
			var world_pos := Vector2(
				(sx + 0.5) / SCOLS * MAP_SIZE.x,
				(sy + 0.5) / SROWS * MAP_SIZE.y
			)
			var state: int = fog.get_cell_state(world_pos)
			if state == 0:
				draw_rect(Rect2(origin + Vector2(sx * cw, sy * ch), Vector2(cw + 0.5, ch + 0.5)),
					Color(0.0, 0.0, 0.0, 0.9))
			elif state == 1:
				draw_rect(Rect2(origin + Vector2(sx * cw, sy * ch), Vector2(cw + 0.5, ch + 0.5)),
					Color(0.0, 0.0, 0.0, 0.5))
