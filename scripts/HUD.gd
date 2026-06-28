extends Control

# Must match RightPanel.PANEL_W, SelectionManager.TOP_H, BuildMenu.TOP_H
const PANEL_W   := 230.0
const TOP_H     := 74.0

# Single-row layout: label | bar | current/cap fraction
const LOGO_W    := 116.0
const BAR_H     :=  26.0   # tall enough to read at a glance
const BAR_W_MJ  := 180.0
const BAR_W_MP  := 140.0
const LABEL_W   :=  30.0   # "MJ" / "MP" label column
const NUM_RSVD  :=  70.0   # x-space for "200/500" text after each bar
const SEC_GAP   :=  20.0   # horizontal gap between MJ and MP sections

# Palette
const C_BG      := Color(0.07, 0.11, 0.20, 0.96)
const C_LOGO_BG := Color(0.05, 0.08, 0.16, 0.97)
const C_LABEL   := Color(0.88, 0.92, 1.00, 0.95)
const C_BAR_MJ  := Color(0.85, 0.08, 0.08)
const C_BAR_MP  := Color(1.00, 0.60, 0.08)
const C_NUM     := Color(0.88, 0.92, 1.00, 0.95)
const C_DIV     := Color(0.22, 0.35, 0.58, 0.70)

var _toasts: Array = []   # [{text, timer}]

func _ready() -> void:
	GameState.energy_changed.connect(func(_v: float) -> void: queue_redraw())
	GameState.manpower_changed.connect(func(_v: int) -> void: queue_redraw())
	GameState.lava_depleted.connect(_on_lava_depleted)
	queue_redraw()

func _on_lava_depleted() -> void:
	var active := 0
	for ln in get_tree().get_nodes_in_group("lava_nodes"):
		if not ln.get("_depleted"):
			active += 1
	_toasts.append({
		"text":  "LAVA NODE DEPLETED  ·  %d ACTIVE" % active,
		"timer": 4.5,
	})
	queue_redraw()

const MANPOWER_REGEN_BASE := 1.0 / 45.0   # 1 recruit per 45 s at base rate
var _manpower_accum: float = 0.0

func _process(delta: float) -> void:
	GameState.elapsed_time += delta
	queue_redraw()
	if not GameState.game_ended:
		_regen_manpower(delta)
	for i in range(_toasts.size() - 1, -1, -1):
		_toasts[i]["timer"] -= delta
		if _toasts[i]["timer"] <= 0.0:
			_toasts.remove_at(i)

func _regen_manpower(delta: float) -> void:
	var rate := MANPOWER_REGEN_BASE
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.get("building_type") == "barracks" and b.get("is_built") == true:
			rate += 1.0 / 30.0   # each barracks: +1 recruit per 30 s
	_manpower_accum += rate * delta
	if _manpower_accum >= 1.0:
		_manpower_accum -= 1.0
		GameState.add_manpower(1)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if (event as InputEventMouseButton).position.y <= TOP_H:
			get_viewport().set_input_as_handled()

func _draw() -> void:
	var vp_w    := get_viewport().get_visible_rect().size.x
	var panel_w := vp_w - PANEL_W
	var font    := ThemeDB.fallback_font

	draw_rect(Rect2(0.0, 0.0, panel_w, TOP_H), C_BG)
	draw_line(Vector2(0.0, TOP_H - 0.5), Vector2(panel_w, TOP_H - 0.5), C_DIV, 1.0)

	_draw_logo(font)

	var x := LOGO_W + 10.0
	x = _draw_mj(x, font)
	_draw_mp(x + SEC_GAP, font)

	_draw_toasts(font)


func _draw_logo(font: Font) -> void:
	draw_rect(Rect2(0.0, 0.0, LOGO_W, TOP_H), C_LOGO_BG)
	draw_line(Vector2(LOGO_W, 4.0), Vector2(LOGO_W, TOP_H - 4.0), C_DIV, 1.0)

	# Diamond icon
	var cx := 18.0
	var cy := TOP_H * 0.5
	var d   := PackedVector2Array([
		Vector2(cx,        cy - 13.0),
		Vector2(cx + 11.0, cy),
		Vector2(cx,        cy + 13.0),
		Vector2(cx - 11.0, cy)
	])
	draw_colored_polygon(d, Color(0.20, 0.45, 0.75, 0.85))
	draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]),
				  Color(0.45, 0.70, 1.00), 1.5)

	# Game timer
	var mins := int(GameState.elapsed_time / 60.0)
	var secs := int(GameState.elapsed_time) % 60
	draw_string(font, Vector2(38.0, TOP_H * 0.5 + 7.0),
				"%d:%02d" % [mins, secs],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.78, 0.90, 1.00))



func _draw_mj(x: float, font: Font) -> float:
	var energy := GameState.energy
	var cap    := GameState.energy_cap
	var cy     := TOP_H * 0.5
	var bary   := cy - BAR_H * 0.5

	draw_string(font, Vector2(x, cy + 7.0), "MJ",
				HORIZONTAL_ALIGNMENT_LEFT, LABEL_W, 13, C_LABEL)
	var bx := x + LABEL_W + 6.0
	_bar(bx, bary, BAR_W_MJ, energy / cap if cap > 0.0 else 0.0, C_BAR_MJ)
	var val_x := bx + BAR_W_MJ + 6.0
	draw_string(font, Vector2(val_x, cy + 7.0),
				"%.0f/%.0f" % [energy, cap],
				HORIZONTAL_ALIGNMENT_LEFT, NUM_RSVD, 13, C_NUM)
	return val_x + NUM_RSVD


func _draw_mp(x: float, font: Font) -> float:
	var mp  := float(GameState.manpower)
	var mpc := float(GameState.manpower_cap)
	var cy   := TOP_H * 0.5
	var bary := cy - BAR_H * 0.5

	draw_string(font, Vector2(x, cy + 7.0), "MP",
				HORIZONTAL_ALIGNMENT_LEFT, LABEL_W, 13, C_LABEL)
	var bx := x + LABEL_W + 6.0
	_bar(bx, bary, BAR_W_MP, mp / mpc if mpc > 0.0 else 0.0, C_BAR_MP)
	var val_x := bx + BAR_W_MP + 6.0
	draw_string(font, Vector2(val_x, cy + 7.0),
				"%d/%d" % [int(mp), int(mpc)],
				HORIZONTAL_ALIGNMENT_LEFT, NUM_RSVD, 13, C_NUM)
	return val_x + NUM_RSVD



func _bar(x: float, y: float, w: float, ratio: float, col: Color) -> void:
	draw_rect(Rect2(x, y, w, BAR_H), Color(0.04, 0.04, 0.08, 0.90))
	var fill := clampf(ratio, 0.0, 1.0)
	if fill > 0.0:
		draw_rect(Rect2(x + 1.0, y + 1.0, (w - 2.0) * fill, BAR_H - 2.0), col)
	draw_rect(Rect2(x, y, w, BAR_H),
			  Color(col.r * 0.45, col.g * 0.45, col.b * 0.45, 0.65), false, 1.0)



func _draw_toasts(font: Font) -> void:
	if _toasts.is_empty():
		return
	var vp_w    := get_viewport().get_visible_rect().size.x
	var panel_x := vp_w - PANEL_W
	var tw      := 360.0
	var th      := 30.0
	var tx0     := (panel_x - tw) * 0.5

	for i in _toasts.size():
		var t     : float = _toasts[i]["timer"]
		# Fade in over first 0.3 s, fade out over last 0.6 s
		var alpha : float = clampf(t / 0.6, 0.0, 1.0) * clampf((4.5 - t) / 0.3, 0.0, 1.0)
		var ty    := TOP_H + 10.0 + i * (th + 5.0)
		draw_rect(Rect2(tx0, ty, tw, th),       Color(0.50, 0.08, 0.01, 0.88 * alpha))
		draw_rect(Rect2(tx0, ty, tw, th),       Color(1.00, 0.40, 0.08, 0.70 * alpha), false, 1.5)
		draw_string(font,
			Vector2(tx0 + tw * 0.5, ty + th - 8.0),
			_toasts[i]["text"],
			HORIZONTAL_ALIGNMENT_CENTER, tw, 12,
			Color(1.0, 0.88, 0.65, alpha))
