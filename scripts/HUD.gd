extends Control

const BAR_RECT  := Rect2(10.0, 10.0, 220.0, 22.0)
const PAD       := Vector2(6.0, 3.0)

func _ready() -> void:
	GameState.energy_changed.connect(func(_v: float) -> void: queue_redraw())
	queue_redraw()

func _draw() -> void:
	var energy := GameState.energy
	var cap    := GameState.energy_cap

	# Bar background
	draw_rect(BAR_RECT, Color(0.04, 0.04, 0.08, 0.88))

	# Energy fill
	var fill_w := (BAR_RECT.size.x - 2.0) * clampf(energy / cap, 0.0, 1.0)
	if fill_w > 0.0:
		var fill_color := Color(1.0, 0.55, 0.08) if energy < cap * 0.25 else Color(1.0, 0.65, 0.10)
		draw_rect(Rect2(BAR_RECT.position + Vector2(1.0, 1.0), Vector2(fill_w, BAR_RECT.size.y - 2.0)),
			fill_color)

	# Border
	draw_rect(BAR_RECT, Color(0.75, 0.50, 0.15, 0.90), false, 1.0)

	# Label inside bar
	var font    := ThemeDB.fallback_font
	var fs      := 12
	var label   := "MJ  %.0f / %.0f" % [energy, cap]
	var baseline := BAR_RECT.position + Vector2(PAD.x, BAR_RECT.size.y - PAD.y)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.92, 0.75))
