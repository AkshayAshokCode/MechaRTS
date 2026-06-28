extends Control

# Must match RightPanel.PANEL_W, SelectionManager.TOP_H, BuildMenu.TOP_H
const PANEL_W   := 230.0
const TOP_H     := 74.0

# Two-row layout inside the panel
const PAD_TOP   :=  7.0
const ROW1_H    := 22.0   # label + value-box row
const ROW_GAP   :=  6.0
const ROW2_H    := 22.0   # pill + bar + number row

# Logo / timer section
const LOGO_W    := 116.0

# Resource section geometry
const PILL_W    :=  28.0
const PILL_H    :=  20.0
const BAR_H     :=  20.0
const BAR_W_MJ  := 190.0
const BAR_W_MP  := 150.0
const VBOX_W_MJ :=  68.0
const VBOX_W_MP :=  60.0
const NUM_RSVD  :=  58.0   # x-space reserved after each bar for the number
const SEC_GAP   :=  18.0   # horizontal gap between MJ and MP sections

# Palette
const C_BG      := Color(0.07, 0.11, 0.20, 0.96)
const C_LOGO_BG := Color(0.05, 0.08, 0.16, 0.97)
const C_LABEL   := Color(0.88, 0.92, 1.00, 0.95)
const C_VBOX_BG := Color(0.04, 0.18, 0.06, 0.95)
const C_VBOX_BD := Color(0.18, 0.60, 0.22, 0.90)
const C_VBOX_TX := Color(0.40, 1.00, 0.50)
const C_BAR_MJ  := Color(0.85, 0.08, 0.08)
const C_BAR_MP  := Color(1.00, 0.60, 0.08)
const C_NUM     := Color(0.88, 0.92, 1.00, 0.95)
const C_DIV     := Color(0.22, 0.35, 0.58, 0.70)

func _ready() -> void:
	GameState.energy_changed.connect(func(_v: float) -> void: queue_redraw())
	GameState.manpower_changed.connect(func(_v: int) -> void: queue_redraw())
	queue_redraw()

func _process(delta: float) -> void:
	GameState.elapsed_time += delta
	queue_redraw()

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

	# First-wave grace countdown
	var ai: Node = get_tree().get_first_node_in_group("ai_player")
	if ai != null and ai.has_method("grace_remaining"):
		var grace: float = ai.grace_remaining()
		if grace > 0.0:
			var gm := int(grace / 60.0)
			var gs := int(grace) % 60
			var label := "ATTACK IN  %d:%02d" % [gm, gs]
			var pulse := 0.70 + sin(GameState.elapsed_time * 3.0) * 0.30
			draw_string(font, Vector2(38.0, TOP_H - 6.0), label,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
						Color(1.00, 0.55, 0.15, pulse))


func _draw_mj(x: float, font: Font) -> float:
	var energy := GameState.energy
	var cap    := GameState.energy_cap
	var r1y    := PAD_TOP
	var r2y    := PAD_TOP + ROW1_H + ROW_GAP

	# Row 1 — label + current-value box
	draw_string(font, Vector2(x, r1y + 16.0), "MetaJoules",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_LABEL)
	_value_box(x + 120.0, r1y, VBOX_W_MJ, "%.0f" % energy, font)

	# Row 2 — pill | bar | cap
	_pill(x, r2y)
	var bx := x + PILL_W + 4.0
	_bar(bx, r2y, BAR_W_MJ, energy / cap if cap > 0.0 else 0.0, C_BAR_MJ)
	draw_string(font, Vector2(bx + BAR_W_MJ + 6.0, r2y + 16.0),
				"%.0f" % cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_NUM)

	return bx + BAR_W_MJ + 6.0 + NUM_RSVD


func _draw_mp(x: float, font: Font) -> void:
	var mp  := float(GameState.manpower)
	var mpc := float(GameState.manpower_cap)
	var r1y := PAD_TOP
	var r2y := PAD_TOP + ROW1_H + ROW_GAP

	# Row 1 — label + current-value box
	draw_string(font, Vector2(x, r1y + 16.0), "ManPower",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_LABEL)
	_value_box(x + 100.0, r1y, VBOX_W_MP, "%d" % int(mp), font)

	# Row 2 — pill | bar | cap
	_pill(x, r2y)
	var bx := x + PILL_W + 4.0
	_bar(bx, r2y, BAR_W_MP, mp / mpc if mpc > 0.0 else 0.0, C_BAR_MP)
	draw_string(font, Vector2(bx + BAR_W_MP + 6.0, r2y + 16.0),
				"%d" % int(mpc), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_NUM)


func _value_box(x: float, y: float, w: float, text: String, font: Font) -> void:
	draw_rect(Rect2(x, y, w, ROW1_H), C_VBOX_BG)
	draw_rect(Rect2(x, y, w, ROW1_H), C_VBOX_BD, false, 1.0)
	draw_string(font, Vector2(x + w * 0.5, y + 16.0), text,
				HORIZONTAL_ALIGNMENT_CENTER, w, 14, C_VBOX_TX)


func _pill(x: float, y: float) -> void:
	# 3-D capacitor-button appearance
	draw_rect(Rect2(x, y + 1.0, PILL_W, PILL_H),         Color(0.28, 0.33, 0.40))   # shadow
	draw_rect(Rect2(x, y,       PILL_W, PILL_H),          Color(0.75, 0.80, 0.88))   # body
	draw_rect(Rect2(x + 1.0, y + 1.0, PILL_W - 2.0, PILL_H * 0.48),
			  Color(0.92, 0.95, 1.00))                                                 # top highlight
	draw_rect(Rect2(x + 1.0, y + PILL_H * 0.55, PILL_W - 2.0, PILL_H * 0.40),
			  Color(0.56, 0.62, 0.70))                                                 # bottom shade


func _bar(x: float, y: float, w: float, ratio: float, col: Color) -> void:
	draw_rect(Rect2(x, y, w, BAR_H), Color(0.04, 0.04, 0.08, 0.90))
	var fill := clampf(ratio, 0.0, 1.0)
	if fill > 0.0:
		draw_rect(Rect2(x + 1.0, y + 1.0, (w - 2.0) * fill, BAR_H - 2.0), col)
	draw_rect(Rect2(x, y, w, BAR_H),
			  Color(col.r * 0.45, col.g * 0.45, col.b * 0.45, 0.65), false, 1.0)
