extends Control

const PANEL_W  := 230.0
const BOT_H    := 60.0

# Fixed section x-starts (left-to-right)
const SX_NAME   :=  10.0
const SX_HP     := 210.0
const SX_DMG    := 390.0
const SX_RNG    := 470.0
const SX_STATUS := 560.0

const C_BG    := Color(0.06, 0.09, 0.18, 0.96)
const C_GRID  := Color(0.22, 0.32, 0.52, 0.11)
const C_BORD  := Color(0.26, 0.36, 0.56, 0.78)
const C_SEP   := Color(0.28, 0.38, 0.58, 0.55)
const C_HEAD  := Color(0.52, 0.62, 0.82, 0.85)
const C_VAL   := Color(0.92, 0.96, 1.00, 0.95)
const C_NAME  := Color(0.70, 1.00, 0.78, 0.95)
const C_HP_G  := Color(0.20, 0.90, 0.30)
const C_HP_Y  := Color(1.00, 0.65, 0.05)
const C_HP_R  := Color(1.00, 0.12, 0.08)

func _ready() -> void:
	GameState.selection_changed.connect(func(_u: Array) -> void: queue_redraw())
	GameState.building_selected.connect(func(_b: Node) -> void: queue_redraw())
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.position.y >= get_viewport().get_visible_rect().size.y - BOT_H:
			get_viewport().set_input_as_handled()

func _draw() -> void:
	var vp   := get_viewport().get_visible_rect().size
	var pw   := vp.x - PANEL_W
	var y0   := vp.y - BOT_H
	var font := ThemeDB.fallback_font

	# Background
	draw_rect(Rect2(0.0, y0, pw, BOT_H), C_BG)

	# Subtle vertical grid lines
	var gx := 0.0
	while gx < pw:
		draw_rect(Rect2(gx, y0, 1.0, BOT_H), C_GRID)
		gx += 16.0
	# Mid-horizontal scanline
	draw_rect(Rect2(0.0, y0 + BOT_H * 0.5 - 0.5, pw, 1.0),
			  Color(C_GRID.r, C_GRID.g, C_GRID.b, C_GRID.a * 0.7))

	# Top border
	draw_line(Vector2(0.0, y0), Vector2(pw, y0), C_BORD, 1.0)

	# Two text rows
	var ry1 := y0 + 16.0   # header / label row
	var ry2 := y0 + 44.0   # value row

	var sel_b := GameState.selected_building
	var sel_u := GameState.selected_units

	var hovered_lava := _get_hovered_lava()
	var hovered_unit := _get_hovered_unit()
	var hovered_bldg := _get_hovered_building()

	if hovered_lava != null:
		_draw_lava_hover(y0, ry1, ry2, hovered_lava, font)
	elif hovered_bldg != null:
		if hovered_bldg.is_in_group("enemy_buildings"):
			_draw_enemy_building_hover(y0, ry1, ry2, hovered_bldg, font)
		else:
			_draw_building(y0, ry1, ry2, hovered_bldg, font)
	elif hovered_unit != null:
		_draw_units(y0, ry1, ry2, [hovered_unit], font)
	elif sel_b != null and is_instance_valid(sel_b):
		_draw_building(y0, ry1, ry2, sel_b, font)
	elif sel_u.size() > 0:
		_draw_units(y0, ry1, ry2, sel_u, font)
	else:
		draw_string(font, Vector2(SX_NAME, ry2), "No selection",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(0.35, 0.40, 0.55, 0.65))

# ── vertical separator ─────────────────────────────────────────────────────────

func _vsep(x: float, y0: float) -> void:
	draw_line(Vector2(x, y0 + 4.0), Vector2(x, y0 + BOT_H - 4.0), C_SEP, 1.0)

# ── unit(s) ────────────────────────────────────────────────────────────────────

func _draw_units(y0: float, ry1: float, ry2: float, sel: Array, font: Font) -> void:
	var valid: Array = []
	for u in sel:
		if is_instance_valid(u):
			valid.append(u)
	if valid.is_empty():
		return

	var first := valid[0] as Node
	var count := valid.size()

	# ── Name + count ─────────────────────────────────────────────────────────
	var uname: String = first.get_script().get_path().get_file() \
		.get_basename().capitalize().replace("_", " ")
	var name_str := "%s (%d)" % [uname, count] if count > 1 else uname
	draw_string(font, Vector2(SX_NAME, ry1), name_str,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_NAME)

	var is_constructor := first.has_method("build")
	draw_string(font, Vector2(SX_NAME, ry2),
			"Constructor" if is_constructor else "Combat Unit",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_HEAD)

	# ── HP bar + value ────────────────────────────────────────────────────────
	_vsep(SX_HP - 6.0, y0)
	var total_hp  := 0.0
	var total_mhp := 0.0
	for u in valid:
		total_hp  += _fget(u, "health",     100.0)
		total_mhp += _fget(u, "max_health", 100.0)
	_draw_hp(SX_HP, y0, ry1, ry2, total_hp, total_mhp, font)

	# ── Damage ───────────────────────────────────────────────────────────────
	var dmg := _fget(first, "attack_damage", 0.0)
	if dmg > 0.0:
		_vsep(SX_DMG - 6.0, y0)
		draw_string(font, Vector2(SX_DMG, ry1), "Damage",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_HEAD)
		draw_string(font, Vector2(SX_DMG, ry2), "%.0f" % dmg,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_VAL)

	# ── Range ─────────────────────────────────────────────────────────────────
	var rng := _fget(first, "attack_range", 0.0)
	if rng > 0.0:
		_vsep(SX_RNG - 6.0, y0)
		draw_string(font, Vector2(SX_RNG, ry1), "Range",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_HEAD)
		draw_string(font, Vector2(SX_RNG, ry2), "%.0f" % rng,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_VAL)

	# ── Status ────────────────────────────────────────────────────────────────
	_vsep(SX_STATUS - 6.0, y0)
	var status := _unit_status(first)
	draw_string(font, Vector2(SX_STATUS, ry1), "Status",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_HEAD)
	var sc := Color(0.72, 1.00, 0.72) if status == "Idle" else Color(1.00, 0.90, 0.50)
	draw_string(font, Vector2(SX_STATUS, ry2), status,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, sc)

# ── building ───────────────────────────────────────────────────────────────────

func _draw_building(y0: float, ry1: float, ry2: float, sb: Node, font: Font) -> void:
	var btype: String = sb.get("building_type") if sb.get("building_type") != null else ""
	var defs: Dictionary = load("res://scripts/Building.gd").DEFS
	var blabel: String = defs[btype]["label"] if defs.has(btype) else btype.capitalize()

	draw_string(font, Vector2(SX_NAME, ry1), blabel,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.90, 1.00))

	var is_built: bool = sb.get("is_built") if sb.get("is_built") != null else false
	draw_string(font, Vector2(SX_NAME, ry2),
			"Operational" if is_built else "Under construction",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_HEAD)

	# HP (player buildings currently don't have HP — skip if none)
	var hp  := _fget(sb, "health",     -1.0)
	var mhp := _fget(sb, "max_health", -1.0)
	if hp >= 0.0 and mhp > 0.0:
		_vsep(SX_HP - 6.0, y0)
		_draw_hp(SX_HP, y0, ry1, ry2, hp, mhp, font)

	# Build progress
	if not is_built:
		var prog := _fget(sb, "build_progress", 0.0)
		_vsep(SX_DMG - 6.0, y0)
		draw_string(font, Vector2(SX_DMG, ry1), "Build",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_HEAD)
		draw_string(font, Vector2(SX_DMG, ry2), "%.0f%%" % (prog * 100.0),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_VAL)

# ── shared helpers ──────────────────────────────────────────────────────────────

func _draw_hp(sx: float, y0: float, ry1: float, ry2: float,
		hp: float, mhp: float, font: Font) -> void:
	var ratio := clampf(hp / mhp, 0.0, 1.0) if mhp > 0.0 else 0.0
	draw_string(font, Vector2(sx, ry1), "HP",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_HEAD)

	# Mini bar
	var bw  := 90.0
	var bh  :=  7.0
	var bx  := sx + 26.0
	var bar_y := ry1 + 3.0
	draw_rect(Rect2(bx, bar_y, bw, bh), Color(0.08, 0.08, 0.10, 0.90))
	var hc := C_HP_G if ratio > 0.5 else (C_HP_Y if ratio > 0.25 else C_HP_R)
	draw_rect(Rect2(bx, bar_y, bw * ratio, bh), hc)
	draw_rect(Rect2(bx, bar_y, bw, bh), Color(hc.r * 0.5, hc.g * 0.5, hc.b * 0.5, 0.6),
			false, 1.0)

	draw_string(font, Vector2(sx, ry2), "%.0f / %.0f" % [hp, mhp],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_VAL)

func _unit_status(unit: Node) -> String:
	if unit.get("_constructing") == true: return "Constructing"
	if unit.get("_harvesting")   == true: return "Harvesting"
	var mt: Variant = unit.get("move_target")
	if mt is Vector2:
		if (mt as Vector2).distance_squared_to((unit as Node2D).global_position) > 16.0:
			return "Moving"
	return "Idle"

func _fget(node: Node, prop: String, default: float) -> float:
	var v: Variant = node.get(prop)
	return (v as float) if v != null else default

# ── lava node hover ────────────────────────────────────────────────────────────

func _get_hovered_lava() -> Node:
	var vp        := get_viewport().get_visible_rect().size
	var screen_mp := get_viewport().get_mouse_position()
	# Ignore cursor inside top HUD, bottom bar, or right panel
	if screen_mp.y <= 74.0 or screen_mp.y >= vp.y - BOT_H or screen_mp.x >= vp.x - PANEL_W:
		return null
	# get_canvas_transform() maps world → viewport pixels (includes camera offset + zoom)
	var canvas_xf := get_viewport().get_canvas_transform()
	var zoom      := maxf(abs(canvas_xf.get_scale().x), 0.25)
	var hit_r     := 38.0 * zoom   # world RADIUS=32, slightly generous hit zone
	for ln in get_tree().get_nodes_in_group("lava_nodes"):
		var sp := canvas_xf * (ln as Node2D).global_position
		if sp.distance_to(screen_mp) <= hit_r:
			return ln
	return null

func _get_hovered_unit() -> Node:
	var vp        := get_viewport().get_visible_rect().size
	var screen_mp := get_viewport().get_mouse_position()
	if screen_mp.y <= 74.0 or screen_mp.y >= vp.y - BOT_H or screen_mp.x >= vp.x - PANEL_W:
		return null
	var canvas_xf := get_viewport().get_canvas_transform()
	var zoom      := maxf(abs(canvas_xf.get_scale().x), 0.25)
	var hit_r     := 22.0 * zoom
	for grp in [get_tree().get_nodes_in_group("units"), get_tree().get_nodes_in_group("enemy_units")]:
		for unit in grp:
			var sp := canvas_xf * (unit as Node2D).global_position
			if sp.distance_to(screen_mp) <= hit_r:
				return unit
	return null

func _get_hovered_building() -> Node:
	var vp        := get_viewport().get_visible_rect().size
	var screen_mp := get_viewport().get_mouse_position()
	if screen_mp.y <= 74.0 or screen_mp.y >= vp.y - BOT_H or screen_mp.x >= vp.x - PANEL_W:
		return null
	var canvas_xf := get_viewport().get_canvas_transform()
	var zoom      := maxf(abs(canvas_xf.get_scale().x), 0.25)
	var hit_r     := 55.0 * zoom
	for grp in [get_tree().get_nodes_in_group("buildings"), get_tree().get_nodes_in_group("enemy_buildings")]:
		for b in grp:
			if b.get("is_ghost") == true:
				continue
			var sp := canvas_xf * (b as Node2D).global_position
			if sp.distance_to(screen_mp) <= hit_r:
				return b
	return null

func _draw_lava_hover(y0: float, ry1: float, ry2: float, ln: Node, font: Font) -> void:
	var remaining     : float = _fget(ln, "_remaining", 0.0)
	const RESERVE_TOTAL := 8000.0
	var ratio := clampf(remaining / RESERVE_TOTAL, 0.0, 1.0)

	var harvesters: Variant = ln.get("_harvesters")
	var hcount := 0
	if harvesters is Array:
		hcount = (harvesters as Array).size()
	var rate : float = _fget(ln, "harvest_rate", 40.0)

	# ── Name + status ───────────────────────────────────────────────────────────
	draw_string(font, Vector2(SX_NAME, ry1), "Lava Reserve",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.55, 0.10, 0.95))

	var is_depleted: bool = ln.get("_depleted") == true
	var status_str : String
	var status_col : Color
	if is_depleted:
		status_str = "Depleted — Regenerating"
		status_col = Color(0.75, 0.55, 0.30)
	elif hcount > 0:
		status_str = "%d Truck%s harvesting" % [hcount, "s" if hcount > 1 else ""]
		status_col = Color(1.0, 0.80, 0.30)
	elif remaining < RESERVE_TOTAL:
		status_str = "Replenishing"
		status_col = Color(0.45, 1.00, 0.55)
	else:
		status_str = "Full"
		status_col = Color(0.55, 0.85, 1.00)
	draw_string(font, Vector2(SX_NAME, ry2), status_str,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, status_col)

	# ── Reserve bar ─────────────────────────────────────────────────────────────
	_vsep(SX_HP - 6.0, y0)
	draw_string(font, Vector2(SX_HP, ry1), "Reserve",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_HEAD)

	var bw    := 110.0
	var bh    :=   7.0
	var bx    := SX_HP + 58.0
	var bar_y := ry1 + 3.0
	var lc    := Color(1.0, 0.35, 0.0) if ratio > 0.5 else \
				 (Color(1.0, 0.65, 0.0) if ratio > 0.25 else Color(1.0, 0.10, 0.0))
	draw_rect(Rect2(bx, bar_y, bw,         bh), Color(0.08, 0.08, 0.10, 0.90))
	draw_rect(Rect2(bx, bar_y, bw * ratio, bh), lc)
	draw_rect(Rect2(bx, bar_y, bw,         bh), Color(lc.r * 0.4, lc.g * 0.4, 0.0, 0.55),
			false, 1.0)

	draw_string(font, Vector2(SX_HP, ry2),
			"%.0f / %.0f MJ" % [remaining, RESERVE_TOTAL],
			HORIZONTAL_ALIGNMENT_LEFT, 180, 14, C_VAL)

	# ── Rate column ─────────────────────────────────────────────────────────────
	_vsep(SX_DMG - 6.0, y0)
	if hcount > 0:
		draw_string(font, Vector2(SX_DMG, ry1), "Drain Rate",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_HEAD)
		draw_string(font, Vector2(SX_DMG, ry2), "%.0f MJ/s" % (rate * hcount),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.70, 0.20))
	elif remaining < RESERVE_TOTAL:
		draw_string(font, Vector2(SX_DMG, ry1), "Regen Rate",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_HEAD)
		draw_string(font, Vector2(SX_DMG, ry2), "+8 MJ/s",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.45, 1.00, 0.55))

# ── enemy building hover ────────────────────────────────────────────────────────

func _draw_enemy_building_hover(y0: float, ry1: float, ry2: float, eb: Node, font: Font) -> void:
	var label  : String = eb.get("_label") if eb.get("_label") != null else "Enemy Structure"
	var is_hq  : bool   = eb.get("is_hq")  if eb.get("is_hq")  != null else false
	var nc := Color(1.00, 0.85, 0.20, 0.95) if is_hq else Color(1.00, 0.50, 0.50, 0.95)
	draw_string(font, Vector2(SX_NAME, ry1), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, nc)
	draw_string(font, Vector2(SX_NAME, ry2), "Enemy HQ" if is_hq else "Enemy Structure",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_HEAD)

	var hp  := _fget(eb, "health",     0.0)
	var mhp := _fget(eb, "max_health", 1.0)
	if mhp > 0.0:
		_vsep(SX_HP - 6.0, y0)
		_draw_hp(SX_HP, y0, ry1, ry2, hp, mhp, font)

	_vsep(SX_DMG - 6.0, y0)
	draw_string(font, Vector2(SX_DMG, ry1), "Faction",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_HEAD)
	draw_string(font, Vector2(SX_DMG, ry2), "Enemy",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.00, 0.35, 0.35))
