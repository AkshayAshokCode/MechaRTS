extends Control

const MAP_SIZE := Vector2(6400.0, 4800.0)
const PANEL_W  := 230.0
const PAD      := 8.0
const MM_W     := PANEL_W - PAD * 2.0           # 214
const MM_H     := MM_W * (4800.0 / 6400.0)      # ~160.5

# Building grid (3 columns)
const BCOLS   := 3
const BGAP    := 3.0
const BTN_W   := (MM_W - (BCOLS - 1) * BGAP) / BCOLS  # ~69.3
const BTN_H   := 76.0
const ICON_H  := 54.0

# Action grid (3 columns)
const ACOLS   := 3
const AGAP    := 3.0
const ACT_H   := 36.0

# Colours
const C_BG     := Color(0.09, 0.13, 0.24, 0.97)
const C_LBDR   := Color(0.22, 0.30, 0.50, 0.85)   # left border strip
const C_DIV    := Color(0.25, 0.35, 0.55, 0.60)
const C_HDR    := Color(0.48, 0.54, 0.72, 0.80)   # section-header text

# Building button
const C_BB_BG  := Color(0.28, 0.06, 0.06, 0.96)   # dark red body
const C_BB_LB  := Color(0.20, 0.04, 0.04, 0.96)   # label strip (darker)
const C_BB_BD  := Color(0.60, 0.60, 0.68, 0.90)   # silver border
const C_BB_DIM := Color(0.38, 0.38, 0.42, 0.70)   # dimmed border when can't afford

# Action button
const C_AB_BG  := Color(0.10, 0.15, 0.28, 0.95)
const C_AB_BD  := Color(0.38, 0.48, 0.62, 0.85)
const C_AB_ON  := Color(0.10, 0.32, 0.62, 0.95)
const C_AB_BD_ON := Color(0.28, 0.62, 1.00, 0.90)
const C_AB_DOT := Color(0.38, 0.48, 0.65, 0.70)   # dots under action label

const C_WHITE  := Color(1.00, 1.00, 1.00, 0.95)
const C_DIM    := Color(0.38, 0.38, 0.44, 0.75)

var _sel_units:    Array = []
var _sel_building: Node  = null
var _buttons:      Array = []
var _attack_alerts: Array = []   # [{pos: Vector2, timer: float}]

var _mm_dragging:   bool  = false
var _mm_hold_time:  float = 0.0
var _mm_pinged:     bool  = false   # ping already fired for this press
var _mm_hovered:    bool  = false   # mouse is over minimap
var _mm_vp_hovered: bool  = false   # mouse is over the viewport rect indicator

func _ready() -> void:
	add_to_group("right_panel")
	GameState.selection_changed.connect(func(u: Array) -> void:
		_sel_units    = u
		_sel_building = null
		queue_redraw())
	GameState.building_selected.connect(func(b: Node) -> void:
		_sel_building = b
		if b != null:
			_sel_units = []
		queue_redraw())
	GameState.inventory_changed.connect(func() -> void: queue_redraw())
	GameState.attack_at.connect(func(world_pos: Vector2) -> void:
		_attack_alerts.append({"pos": world_pos, "timer": 1.0}))

func _process(delta: float) -> void:
	if not _attack_alerts.is_empty():
		for i in range(_attack_alerts.size() - 1, -1, -1):
			_attack_alerts[i]["timer"] -= delta
			if _attack_alerts[i]["timer"] <= 0.0:
				_attack_alerts.remove_at(i)

	if _mm_dragging:
		_mm_hold_time += delta
		if not _mm_pinged and _mm_hold_time >= 0.5:
			_mm_pinged = true
			var mpos := get_viewport().get_mouse_position()
			var mm_orig := _mm_origin()
			var rel := (mpos - mm_orig) / Vector2(MM_W, MM_H)
			GameState.ping_at.emit(rel * MAP_SIZE)

	queue_redraw()

func _panel_x() -> float:
	return get_viewport().get_visible_rect().size.x - PANEL_W

func _mm_origin() -> Vector2:
	return Vector2(_panel_x() + PAD, PAD)

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	var mm_orig := _mm_origin()
	var mm_rect := Rect2(mm_orig, Vector2(MM_W, MM_H))

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_mm_hovered = mm_rect.has_point(mm.position)
		_mm_vp_hovered = _mm_hovered and _viewport_mm_rect(mm_orig).has_point(mm.position)
		# Continuous drag
		if _mm_dragging and mm_rect.has_point(mm.position):
			_jump_camera(mm.position, mm_orig)
		# Cursor shape — only modify when mouse is in the panel
		if mm.position.x >= _panel_x():
			if _mm_dragging or _mm_vp_hovered:
				DisplayServer.cursor_set_shape(DisplayServer.CURSOR_MOVE)
			else:
				DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
			get_viewport().set_input_as_handled()
		return

	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.position.x < _panel_x():
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_mm_dragging   = false
			_mm_hold_time  = 0.0
			_mm_pinged     = false
		return

	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			if mm_rect.has_point(mb.position):
				_mm_dragging  = true
				_mm_hold_time = 0.0
				_mm_pinged    = false
				_jump_camera(mb.position, mm_orig)
			else:
				for btn in _buttons:
					if (btn["rect"] as Rect2).has_point(mb.position):
						_execute(btn["action"])
						break
		else:
			_mm_dragging  = false
			_mm_hold_time = 0.0
			_mm_pinged    = false
	get_viewport().set_input_as_handled()

func _jump_camera(screen_pos: Vector2, mm_orig: Vector2) -> void:
	var rel := (screen_pos - mm_orig) / Vector2(MM_W, MM_H)
	var cam: Camera2D = get_tree().get_first_node_in_group("camera_rig")
	if cam:
		cam.global_position = rel * MAP_SIZE

func _viewport_mm_rect(mm_orig: Vector2) -> Rect2:
	var cam: Camera2D = get_tree().get_first_node_in_group("camera_rig")
	if cam == null:
		return Rect2()
	var vp_sz  := get_viewport().get_visible_rect().size
	var cam_tl := cam.global_position - vp_sz * 0.5 / cam.zoom
	var tl     := mm_orig + (cam_tl / MAP_SIZE) * Vector2(MM_W, MM_H)
	var sz     := (vp_sz / cam.zoom / MAP_SIZE) * Vector2(MM_W, MM_H)
	return Rect2(tl, sz)

func _execute(action: String) -> void:
	if action.begins_with("place:"):
		var bm := get_tree().get_first_node_in_group("build_menu")
		if bm and bm.has_method("start_placement"):
			bm.start_placement(action.substr(6))
		return
	if action.begins_with("draft_part:"):
		var idx_s := action.substr(11)
		if idx_s.is_valid_int():
			GameState.draft_part(int(idx_s))
		return
	if action.begins_with("undraft:"):
		GameState.undraft_part(action.substr(8))
		return
	if action.begins_with("queue_vehicle:"):
		var vtype := action.substr(14)
		var sb := GameState.selected_building
		if sb != null and is_instance_valid(sb) and sb.has_method("queue_vehicle"):
			sb.queue_vehicle(vtype)
		return
	if action.begins_with("queue_part:"):
		var pid := action.substr(11)
		var sb := GameState.selected_building
		if sb != null and is_instance_valid(sb) and sb.has_method("queue_part"):
			sb.queue_part(pid)
		return
	match action:
		"toggle_build":
			var bm := get_tree().get_first_node_in_group("build_menu")
			if bm and bm.has_method("toggle_menu"):
				bm.toggle_menu()
		"queue_part_set":
			var sb := GameState.selected_building
			if sb != null and is_instance_valid(sb) and sb.has_method("queue_part_set"):
				sb.queue_part_set()
		"assemble_combot":
			_do_assemble_combot()
		"unit_stop":
			for unit in _sel_units:
				if is_instance_valid(unit):
					unit.move_target = (unit as Node2D).global_position

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	_buttons.clear()
	var font := ThemeDB.fallback_font
	var vp   := get_viewport().get_visible_rect().size
	var px   := _panel_x()

	# Background
	draw_rect(Rect2(px, 0.0, PANEL_W, vp.y), C_BG)
	# Left border accent strip
	draw_rect(Rect2(px, 0.0, 2.0, vp.y), C_LBDR)

	# Minimap
	var mm_orig := _mm_origin()
	_draw_minimap(mm_orig, font)

	# Divider
	var div_y := mm_orig.y + MM_H + PAD
	draw_line(Vector2(px + 4.0, div_y), Vector2(px + PANEL_W - 4.0, div_y), C_DIV, 1.0)

	var gx := px + PAD           # grid origin x
	var gw := MM_W               # grid usable width
	var y  := div_y + 6.0

	if _sel_building != null and is_instance_valid(_sel_building):
		_draw_building_ops(gx, gw, y, font)
	elif _sel_units.size() > 0:
		_draw_unit_ops(gx, gw, y, font)
	else:
		draw_string(font, Vector2(gx, y + 14.0), "Nothing selected",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_DIM)

# ── Minimap ───────────────────────────────────────────────────────────────────

func _draw_minimap(origin: Vector2, font: Font) -> void:
	var mm_rect := Rect2(origin, Vector2(MM_W, MM_H))
	draw_rect(mm_rect, Color(0.04, 0.05, 0.08, 0.95))

	var fog := get_tree().get_first_node_in_group("fog_of_war")
	if fog:
		_draw_fog(fog, origin)

	# Lava nodes — orange dots (discovered = visible or explored)
	for lava in get_tree().get_nodes_in_group("lava_nodes"):
		var wp  := (lava as Node2D).global_position
		if fog and fog.get_cell_state(wp) == 0:
			continue
		var dot := origin + wp / MAP_SIZE * Vector2(MM_W, MM_H)
		draw_circle(dot, 2.5, Color(1.00, 0.55, 0.10, 0.85))

	# Enemy buildings — visible on minimap only once spotted (stays after explored)
	for eb in get_tree().get_nodes_in_group("enemy_buildings"):
		var wp := (eb as Node2D).global_position
		if fog != null and fog.get_cell_state(wp) < 1:
			continue
		var dot := origin + wp / MAP_SIZE * Vector2(MM_W, MM_H)
		draw_rect(Rect2(dot - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(0.85, 0.2, 0.2, 0.9))

	# Player buildings — dark amber
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.get("is_ghost") == true:
			continue
		var dot := origin + (b as Node2D).global_position / MAP_SIZE * Vector2(MM_W, MM_H)
		draw_rect(Rect2(dot - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), Color(0.75, 0.45, 0.05, 0.95))

	# Enemy units — only visible when currently in player vision
	for eu in get_tree().get_nodes_in_group("enemy_units"):
		var wp := (eu as Node2D).global_position
		if fog != null and fog.get_cell_state(wp) < 2:
			continue
		var dot := origin + wp / MAP_SIZE * Vector2(MM_W, MM_H)
		draw_circle(dot, 2.5, Color(1.0, 0.3, 0.2))

	# Player units — amber (brighter when selected)
	for unit in get_tree().get_nodes_in_group("units"):
		var dot := origin + (unit as Node2D).global_position / MAP_SIZE * Vector2(MM_W, MM_H)
		draw_circle(dot, 2.5, Color(1.00, 0.75, 0.10) if unit.selected else Color(0.85, 0.55, 0.05))

	# Attack alerts — red flashes where player assets are being hit
	for alert in _attack_alerts:
		var t   := alert["timer"] as float
		var dot := origin + (alert["pos"] as Vector2) / MAP_SIZE * Vector2(MM_W, MM_H)
		draw_circle(dot, 4.0 + (1.0 - t) * 3.0, Color(1.0, 0.10, 0.05, t * 0.85))

	# Viewport rect — teal, brighter when hovered or dragging
	var vp_rect := _viewport_mm_rect(origin)
	if vp_rect.size.length() > 0.0:
		var vp_alpha := 0.85 if (_mm_vp_hovered or _mm_dragging) else 0.55
		var vp_width := 1.8  if (_mm_vp_hovered or _mm_dragging) else 1.2
		draw_rect(vp_rect, Color(0.15, 0.85, 0.90, vp_alpha), false, vp_width)

	draw_string(font, Vector2(origin.x + 4.0, origin.y + 11.0), "MAP",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.65, 0.65, 0.85, 0.6))
	var bdr_col := Color(0.60, 0.70, 1.00, 0.90) if _mm_hovered else Color(0.38, 0.44, 0.65, 0.70)
	draw_rect(mm_rect, bdr_col, false, 1.0)

func _draw_fog(fog: Node, origin: Vector2) -> void:
	const SCOLS := 50
	const SROWS := 38
	var cw := MM_W / SCOLS
	var ch := MM_H / SROWS
	for sy in SROWS:
		for sx in SCOLS:
			var wp := Vector2((sx + 0.5) / SCOLS * MAP_SIZE.x, (sy + 0.5) / SROWS * MAP_SIZE.y)
			var s: int = fog.get_cell_state(wp)
			if s == 0:
				draw_rect(Rect2(origin + Vector2(sx * cw, sy * ch), Vector2(cw + 0.5, ch + 0.5)),
					Color(0.0, 0.0, 0.0, 0.9))
			elif s == 1:
				draw_rect(Rect2(origin + Vector2(sx * cw, sy * ch), Vector2(cw + 0.5, ch + 0.5)),
					Color(0.0, 0.0, 0.0, 0.5))

# ── Operations: building selected ─────────────────────────────────────────────

func _draw_building_ops(gx: float, gw: float, y: float, font: Font) -> void:
	var sb     := _sel_building
	var btype: String  = sb.get("building_type") if sb.get("building_type") != null else ""
	var is_built: bool = sb.get("is_built") if sb.get("is_built") != null else false
	var defs: Dictionary = load("res://scripts/Building.gd").DEFS
	var blabel: String = defs[btype]["label"] if defs.has(btype) else btype.capitalize()

	draw_string(font, Vector2(gx, y + 14.0), blabel,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.90, 1.00))
	y += 28.0

	if not is_built:
		var prog: float = sb.get("build_progress") if sb.get("build_progress") != null else 0.0
		draw_string(font, Vector2(gx, y), "Under construction",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.70, 0.88, 0.70))
		y += 16.0
		draw_rect(Rect2(gx, y, gw, 6.0), Color(0.10, 0.10, 0.10, 0.85))
		draw_rect(Rect2(gx, y, gw * prog, 6.0), Color(0.20, 1.00, 0.45))
		return

	if btype == "vehicle_factory" and sb.has_method("get_production_info"):
		var info: Dictionary = sb.get_production_info()
		if info.is_empty():
			return
		var queue: Array     = info["queue"]
		var prog: float      = info["progress"]
		var vdefs: Dictionary = info["vehicle_defs"]

		if not queue.is_empty():
			var cur_type: String  = queue[0]
			var cur_def: Dictionary = vdefs[cur_type]
			var prod_col: Color   = cur_def["col"]
			draw_string(font, Vector2(gx, y),
				"Building: %s  (q:%d)" % [cur_def["label"], queue.size()],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.60, 0.80, 1.00))
			y += 14.0
			draw_rect(Rect2(gx, y, gw, 6.0), Color(0.10, 0.10, 0.10, 0.85))
			draw_rect(Rect2(gx, y, gw * prog, 6.0),
				Color(prod_col.r, prod_col.g, prod_col.b, 0.90))
			y += 16.0

		draw_string(font, Vector2(gx, y + 11.0), "QUEUE VEHICLE",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_HDR)
		y += 18.0

		var col_i := 0
		for vtype in ["hover_truck", "missile_truck", "hover_tank"]:
			var vdef: Dictionary = vdefs[vtype]
			var vcost: float = vdef["cost"]
			var can_afford := GameState.energy >= vcost
			var bx := gx + col_i * (BTN_W + BGAP)
			_draw_act_btn(bx, y, BTN_W, 50.0, "queue_vehicle:" + vtype,
				vdef["label"], false, can_afford, font)
			draw_string(font, Vector2(bx, y + 48.0), "%.0f" % vcost,
				HORIZONTAL_ALIGNMENT_CENTER, BTN_W, 9,
				Color(0.65, 0.80, 0.65, 0.80) if can_afford else C_DIM)
			col_i += 1

	elif btype == "bot_parts_factory" and sb.has_method("get_bpf_info"):
		_draw_bpf_ops(gx, gw, y, font)

	elif btype == "assembly_bay":
		_draw_assembly_bay_ops(gx, gw, y, font)

# ── Operations: unit(s) selected ─────────────────────────────────────────────

func _draw_unit_ops(gx: float, gw: float, y: float, font: Font) -> void:
	if _sel_units.size() > 1:
		draw_string(font, Vector2(gx, y + 16.0), "%d units selected" % _sel_units.size(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.90, 0.90, 0.90))
		y += 30.0
		_draw_action_grid(gx, y, _multi_actions(), font)
		return

	var unit := _sel_units[0] as Node
	if not is_instance_valid(unit):
		return

	# Unit name
	var uname: String = unit.get_script().get_path().get_file().get_basename() \
		.capitalize().replace("_", " ")
	draw_string(font, Vector2(gx, y + 16.0), uname,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 1.00, 0.88))
	y += 28.0

	# Build section (HoverTruck)
	if unit.has_method("build"):
		var bm := get_tree().get_first_node_in_group("build_menu")
		if bm != null and bm.is_placing():
			y = _draw_placing_status(gx, gw, y, bm, font)
		else:
			y = _draw_build_grid(gx, y, font)
			y = _draw_nav_pills(gx, gw, y)
		_draw_action_grid(gx, y, _constructor_actions(unit, bm), font)
	else:
		_draw_action_grid(gx, y, _vehicle_actions(unit), font)

# ── Build: ghost placement status ─────────────────────────────────────────────

func _draw_placing_status(gx: float, gw: float, y: float, bm: Node, font: Font) -> float:
	var atype: String = bm.get_active_type()
	var defs: Dictionary = load("res://scripts/Building.gd").DEFS
	var blabel: String = defs[atype]["label"] if defs.has(atype) else atype
	var bc: Color = defs[atype]["color"] if defs.has(atype) else Color.WHITE

	draw_rect(Rect2(gx, y, gw, 28.0),
		Color(bc.r * 0.20, bc.g * 0.20, bc.b * 0.20, 0.92))
	draw_rect(Rect2(gx, y, gw, 28.0),
		Color(bc.r * 0.70, bc.g * 0.70, bc.b * 0.70, 0.55), false, 1.0)
	draw_string(font, Vector2(gx + 6.0, y + 19.0), "Placing:  " + blabel,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(bc.r + 0.25, bc.g + 0.25, bc.b + 0.25, 1.0))
	y += 36.0
	draw_string(font, Vector2(gx, y), "Click map to place",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 1.0, 0.55, 0.9))
	y += 16.0
	draw_string(font, Vector2(gx, y), "Right-click / ESC — cancel",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.75, 0.45, 0.8))
	return y + 22.0

# ── Build: 3×N building button grid ──────────────────────────────────────────

func _draw_build_grid(gx: float, y: float, font: Font) -> float:
	draw_string(font, Vector2(gx, y + 12.0), "BUILD",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_HDR)
	y += 18.0

	var defs: Dictionary = load("res://scripts/Building.gd").DEFS
	var keys  := defs.keys()
	var col_i := 0
	var row_y := y

	for i in keys.size():
		var key: String = keys[i]
		var def: Dictionary = defs[key]
		var bc: Color  = def["color"]
		var cost: float = def["cost"]
		var can_afford := GameState.energy >= cost

		var bx := gx + col_i * (BTN_W + BGAP)
		_draw_build_btn(bx, row_y, key, bc, def["label"], cost, can_afford, font)

		col_i += 1
		if col_i >= BCOLS:
			col_i  = 0
			row_y += BTN_H + BGAP

	# Advance y past the last partial row
	if col_i > 0:
		row_y += BTN_H + BGAP

	return row_y

func _draw_build_btn(bx: float, by: float, key: String, bc: Color,
		label: String, cost: float, can_afford: bool, font: Font) -> void:
	var w := BTN_W
	var h := BTN_H

	# Body background (dark red)
	draw_rect(Rect2(bx, by, w, h), C_BB_BG)

	# Icon area
	_draw_bicon(bx, by, w, bc, can_afford)

	# Label strip
	draw_rect(Rect2(bx, by + ICON_H, w, h - ICON_H), C_BB_LB)

	var short := _short_label(label)
	var tc := C_WHITE if can_afford else C_DIM
	draw_string(font, Vector2(bx, by + ICON_H + 13.0), short,
		HORIZONTAL_ALIGNMENT_CENTER, w, 11, tc)

	# Cost hint
	if can_afford:
		draw_string(font, Vector2(bx, by + h - 2.0),
			"%.0f MJ" % cost, HORIZONTAL_ALIGNMENT_CENTER, w, 9,
			Color(0.65, 0.80, 0.65, 0.75))

	# Border
	var brd := C_BB_BD if can_afford else C_BB_DIM
	draw_rect(Rect2(bx, by, w, h), brd, false, 1.0)

	if can_afford:
		_buttons.append({"rect": Rect2(bx, by, w, h), "action": "place:" + key})

func _draw_bicon(bx: float, by: float, w: float, bc: Color, can_afford: bool) -> void:
	var alpha := 1.0 if can_afford else 0.35

	# Icon bg: tinted with building colour
	draw_rect(Rect2(bx, by, w, ICON_H),
		Color(bc.r * 0.22, bc.g * 0.22, bc.b * 0.22, 0.97))

	if not can_afford:
		draw_rect(Rect2(bx, by, w, ICON_H), Color(0.0, 0.0, 0.0, 0.55))
		return

	# Building silhouette using the building colour
	var mw := w * 0.58
	var mh := ICON_H * 0.50
	var mx := bx + (w - mw) * 0.5
	var my := by + ICON_H - mh - 3.0

	# Drop shadow
	draw_rect(Rect2(mx + 2.0, my + 2.0, mw, mh),
		Color(0.0, 0.0, 0.0, 0.55 * alpha))
	# Main body
	draw_rect(Rect2(mx, my, mw, mh),
		Color(bc.r * 0.65, bc.g * 0.65, bc.b * 0.65, alpha))
	# Top face (lighter)
	draw_rect(Rect2(mx, my, mw, mh * 0.28),
		Color(bc.r * 0.88, bc.g * 0.88, bc.b * 0.88, alpha))
	# Left face (highlight)
	draw_rect(Rect2(mx, my, mw * 0.22, mh),
		Color(bc.r * 0.82, bc.g * 0.82, bc.b * 0.82, alpha * 0.85))
	# Antenna / tower
	draw_rect(Rect2(mx + mw * 0.42, my - ICON_H * 0.18, mw * 0.12, ICON_H * 0.20),
		Color(bc.r * 0.92, bc.g * 0.92, bc.b * 0.92, alpha))

# ── Nav pills (between build grid and action buttons) ─────────────────────────

func _draw_nav_pills(gx: float, gw: float, y: float) -> float:
	y += 4.0
	var pw := 60.0
	var ph := 18.0
	var gap := 8.0
	var total := pw * 2.0 + gap
	var ox := gx + (gw - total) * 0.5

	for i in 2:
		var px2 := ox + i * (pw + gap)
		draw_rect(Rect2(px2, y, pw, ph), Color(0.13, 0.20, 0.38, 0.90))
		draw_rect(Rect2(px2 + 1.0, y + 1.0, pw - 2.0, ph * 0.5),
			Color(0.20, 0.30, 0.50, 0.70))   # top highlight
		draw_rect(Rect2(px2, y, pw, ph), Color(0.35, 0.45, 0.62, 0.80), false, 1.0)

	return y + ph + 8.0

# ── Action button grid ────────────────────────────────────────────────────────

func _draw_action_grid(gx: float, y: float, actions: Array, font: Font) -> void:
	if actions.is_empty():
		return
	draw_string(font, Vector2(gx, y + 12.0), "ACTIONS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_HDR)
	y += 18.0

	var col_i := 0
	var row_y := y
	for act in actions:
		var label: String  = act["label"]
		var action: String = act["action"]
		var active: bool   = act.get("active", false)
		var enabled: bool  = act.get("enabled", true)

		var ax := gx + col_i * (BTN_W + AGAP)
		_draw_act_btn(ax, row_y, BTN_W, ACT_H, action, label, active, enabled, font)

		col_i += 1
		if col_i >= ACOLS:
			col_i  = 0
			row_y += ACT_H + AGAP

func _draw_act_btn(ax: float, ay: float, w: float, h: float,
		action: String, label: String, active: bool, enabled: bool, font: Font,
		font_size: int = 13) -> void:
	var bg  := C_AB_ON if active  else C_AB_BG
	var brd := C_AB_BD_ON if active else C_AB_BD
	var tc  := C_WHITE if enabled else C_DIM

	if not enabled:
		bg  = Color(0.07, 0.10, 0.18, 0.90)
		brd = Color(0.22, 0.28, 0.38, 0.60)

	draw_rect(Rect2(ax, ay, w, h), bg)
	draw_rect(Rect2(ax + 1.0, ay + 1.0, w - 2.0, h * 0.35),
		Color(1.0, 1.0, 1.0, 0.05 if active else 0.08))
	draw_rect(Rect2(ax, ay, w, h), brd, false, 1.0)

	var ty := ay + h * 0.5 + 6.0
	draw_string(font, Vector2(ax, ty), label,
		HORIZONTAL_ALIGNMENT_CENTER, w, font_size, tc)

	if h >= 36.0:
		var dot_y := ty + 4.0
		var dot_x := ax + 4.0
		while dot_x < ax + w - 4.0:
			draw_rect(Rect2(dot_x, dot_y, 2.0, 1.0), C_AB_DOT)
			dot_x += 4.0

	if enabled and action != "":
		_buttons.append({"rect": Rect2(ax, ay, w, h), "action": action})

func _constructor_actions(unit: Node, bm: Node) -> Array:
	var harvesting: bool = unit.get("_harvesting") == true
	var build_open: bool = bm != null and bm.is_menu_open()
	return [
		{"label": "BUILD",   "action": "toggle_build",    "active": build_open, "enabled": true},
		{"label": "HARVEST", "action": "",                 "active": harvesting, "enabled": false},
		{"label": "STOP",    "action": "unit_stop",        "active": false,      "enabled": true},
	]

func _vehicle_actions(_unit: Node) -> Array:
	return [
		{"label": "MOVE",   "action": "",         "active": false, "enabled": false},
		{"label": "STOP",   "action": "unit_stop","active": false, "enabled": true},
		{"label": "ATTACK", "action": "",         "active": false, "enabled": false},
	]

func _multi_actions() -> Array:
	return [
		{"label": "MOVE",   "action": "",          "active": false, "enabled": false},
		{"label": "STOP",   "action": "unit_stop", "active": false, "enabled": true},
		{"label": "ATTACK", "action": "",          "active": false, "enabled": false},
	]

func _action_btn(gx: float, y: float, gw: float, h: float, action: String,
		label: String, active: bool, enabled: bool, font: Font) -> void:
	_draw_act_btn(gx, y, gw, h, action, label, active, enabled, font)

# ── Bot Parts Factory ops ─────────────────────────────────────────────────────

func _draw_bpf_ops(gx: float, gw: float, y: float, font: Font) -> void:
	var sb := _sel_building
	if not sb.has_method("get_bpf_info"):
		return
	var info: Dictionary = sb.get_bpf_info()
	if info.is_empty():
		return

	var queue: Array = info["queue"]
	var prog: float  = info["progress"]

	# Current production status
	if not queue.is_empty():
		var cur_id: String = queue[0]
		var cur_name: String = cur_id.replace("_", " ").capitalize()
		var pcat: Array = load("res://scripts/PartCatalog.gd").ALL
		for p in pcat:
			if (p as Dictionary).get("id", "") == cur_id:
				cur_name = (p as Dictionary).get("name", cur_name)
				break
		draw_string(font, Vector2(gx, y),
			"Building: %s  (q:%d)" % [cur_name, queue.size()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.80, 0.50, 1.00))
		y += 14.0
		draw_rect(Rect2(gx, y, gw, 5.0), Color(0.10, 0.10, 0.10, 0.85))
		draw_rect(Rect2(gx, y, gw * prog, 5.0), Color(0.75, 0.35, 0.90))
		y += 12.0

	# Individual part buttons grouped by slot
	var part_defs: Dictionary = load("res://scripts/Building.gd").BPF_PART_DEFS
	var cat: Array = load("res://scripts/PartCatalog.gd").ALL

	# Build slot groups preserving catalog order
	var by_slot: Dictionary = {"torso": [], "legs": [], "arm": []}
	for p in cat:
		var pid: String   = (p as Dictionary).get("id", "")
		var slot: String  = (p as Dictionary).get("slot", "")
		var pname: String = (p as Dictionary).get("name", pid)
		if part_defs.has(pid) and by_slot.has(slot):
			by_slot[slot].append({"id": pid, "name": pname})

	for slot_entry in [["torso", "TORSO"], ["legs", "LEGS"], ["arm", "ARM"]]:
		var slot_key: String = slot_entry[0]
		var slot_hdr: String = slot_entry[1]
		var parts: Array = by_slot[slot_key]
		if parts.is_empty():
			continue

		draw_string(font, Vector2(gx, y + 10.0), slot_hdr,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_HDR)
		y += 13.0

		var col_i := 0
		var row_y := y
		for pentry in parts:
			var pid: String  = pentry["id"]
			var cost: float  = part_defs[pid]["cost"]
			var can_afford   := GameState.energy >= cost
			var words        := pid.split("_")
			var short        := words[0].substr(0, 5).capitalize() + " " + str(int(cost))
			var bx           := gx + col_i * (BTN_W + BGAP)
			_draw_act_btn(bx, row_y, BTN_W, 28.0, "queue_part:" + pid,
				short, false, can_afford, font, 10)
			col_i += 1
			if col_i >= BCOLS:
				col_i  = 0
				row_y += 28.0 + BGAP
		if col_i > 0:
			row_y += 28.0 + BGAP
		y = row_y + 2.0

	y += 4.0
	draw_line(Vector2(gx, y), Vector2(gx + gw, y), C_DIV, 0.8)
	y += 6.0

	var set_cost: float = load("res://scripts/Building.gd").PART_SET_COST
	var can_afford_set  := GameState.energy >= set_cost
	_action_btn(gx, y, gw, 34.0, "queue_part_set",
		"Queue Set  (%.0f MJ)" % set_cost, false, can_afford_set, font)

# ── Assembly Bay ops ──────────────────────────────────────────────────────────

func _draw_assembly_bay_ops(gx: float, gw: float, y: float, font: Font) -> void:
	var draft := GameState.combot_draft

	draw_string(font, Vector2(gx, y + 12.0), "COMBOT DRAFT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_HDR)
	y += 18.0

	# Slot rows: click to undraft
	var slots: Array = [["torso", "Torso"], ["legs", "Legs"], ["arm_l", "Arm L"], ["arm_r", "Arm R"]]
	for pair in slots:
		var slot: String   = pair[0]
		var slabel: String = pair[1]
		var p = draft.get(slot)
		var filled := p != null

		var row_bg  := Color(0.10, 0.28, 0.12, 0.90) if filled else Color(0.10, 0.12, 0.20, 0.88)
		var row_brd := Color(0.30, 0.70, 0.35, 0.85) if filled else Color(0.24, 0.28, 0.40, 0.65)

		draw_rect(Rect2(gx, y, gw, 22.0), row_bg)
		draw_rect(Rect2(gx, y, gw, 22.0), row_brd, false, 1.0)

		draw_string(font, Vector2(gx + 4.0, y + 15.0), slabel + ":",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_HDR)

		var val_str: String
		var vc: Color
		if filled:
			val_str = (p as Dictionary).get("name", "—")
			vc = C_WHITE
			# Color swatch at right edge
			var pcol: Color = (p as Dictionary).get("col", Color.WHITE)
			draw_rect(Rect2(gx + gw - 10.0, y + 6.0, 6.0, 10.0), pcol)
			_buttons.append({"rect": Rect2(gx, y, gw, 22.0), "action": "undraft:" + slot})
		else:
			val_str = "empty"
			vc = C_DIM

		draw_string(font, Vector2(gx + 52.0, y + 15.0), val_str,
			HORIZONTAL_ALIGNMENT_LEFT, gw - 62.0, 10, vc)

		y += 25.0

	y += 2.0

	# Combined stats preview
	if GameState.can_assemble():
		var total_hp   := 60.0
		var total_dmg  := 0.0
		var spd_mult   := 1.0
		var total_wt   := 0.0
		var total_stab := 0.0
		for slot in draft:
			var p2 = draft[slot]
			if p2 != null:
				total_hp   += float((p2 as Dictionary).get("hp",        0))
				total_dmg  += float((p2 as Dictionary).get("dmg",       0))
				spd_mult   *= float((p2 as Dictionary).get("spd",     1.0))
				total_wt   += float((p2 as Dictionary).get("weight",    0))
				total_stab += float((p2 as Dictionary).get("stability", 0))
		var eff_spd := spd_mult * (60.0 / (60.0 + total_wt)) * 100.0
		var stab_pct := clampf(total_stab, 0.0, 1.0) * 100.0
		draw_string(font, Vector2(gx, y + 11.0),
			"HP:%.0f  DMG:%.0f  SPD:%.0f%%" % [total_hp, total_dmg, eff_spd],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.70, 0.95, 0.75))
		y += 14.0
		draw_string(font, Vector2(gx, y + 11.0),
			"WT:%.0f  STAB:%.0f%%" % [total_wt, stab_pct],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.80, 0.95))
		y += 14.0

	_action_btn(gx, y, gw, 38.0, "assemble_combot",
		"ASSEMBLE", false, GameState.can_assemble(), font)
	y += 46.0

	# Parts inventory list
	draw_line(Vector2(gx, y), Vector2(gx + gw, y), C_DIV, 1.0)
	y += 6.0
	draw_string(font, Vector2(gx, y + 11.0), "PARTS INVENTORY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_HDR)
	y += 18.0

	var inv := GameState.part_inventory
	if inv.is_empty():
		draw_string(font, Vector2(gx, y + 13.0), "No parts",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_DIM)
		return

	for i in inv.size():
		var p: Dictionary = inv[i]
		var pname: String = p.get("name", "?")
		var pcol: Color   = p.get("col", Color.WHITE)
		var abbr: String  = (p.get("slot", "?") as String).substr(0, 1).to_upper()

		draw_rect(Rect2(gx, y, gw, 22.0), Color(0.08, 0.10, 0.20, 0.90))
		draw_rect(Rect2(gx, y, 4.0, 22.0), pcol)
		draw_rect(Rect2(gx, y, gw, 22.0), Color(0.26, 0.32, 0.52, 0.65), false, 1.0)

		draw_string(font, Vector2(gx + 8.0, y + 15.0), pname,
			HORIZONTAL_ALIGNMENT_LEFT, gw - 26.0, 10, C_WHITE)
		draw_string(font, Vector2(gx + gw - 14.0, y + 15.0), abbr,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, pcol)

		_buttons.append({"rect": Rect2(gx, y, gw, 22.0), "action": "draft_part:" + str(i)})
		y += 25.0

# ── Combot assembly ────────────────────────────────────────────────────────────

func _do_assemble_combot() -> void:
	if not GameState.can_assemble():
		return
	var sb := GameState.selected_building
	if sb == null or not is_instance_valid(sb):
		return

	# Snapshot draft before clearing
	var draft: Dictionary = {}
	for slot in GameState.combot_draft:
		draft[slot] = GameState.combot_draft[slot]

	# Clear draft
	for slot in GameState.combot_draft:
		GameState.combot_draft[slot] = null
	GameState.inventory_changed.emit()

	# Spawn combot beside the Assembly Bay
	var c: Node2D = load("res://scripts/Combot.gd").new()
	var sz: Variant = sb.get("_size")
	var offset := 80.0
	if sz is Vector2:
		offset = (sz as Vector2).x * 0.5 + 40.0
	c.position = (sb as Node2D).global_position + Vector2(offset, 0.0)
	c.z_index  = 50
	c.setup_from_draft(draft)

	var world_root: Node = get_tree().get_first_node_in_group("world_root")
	if world_root != null:
		world_root.add_child(c)

func _short_label(label: String) -> String:
	if label.length() <= 9:
		return label
	var parts := label.split(" ")
	if parts.size() == 1:
		return label.substr(0, 9)
	var a := parts[0].substr(0, 6)
	var b := parts[1].substr(0, max(3, 9 - a.length()))
	return a + b
