extends Control

var _has_save: bool = false
var _hovered: int = -1   # 0=new, 1=continue, 2=quit

func _ready() -> void:
	_has_save = SaveSystem.has_save()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var prev := _hovered
		_hovered = _hit_button((event as InputEventMouseMotion).position)
		if _hovered != prev:
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_click_button(_hit_button(mb.position))

func _hit_button(mouse: Vector2) -> int:
	var vp := get_viewport_rect().size
	var cx  := vp.x * 0.5
	var by  := vp.y * 0.56
	var bw  := 260.0
	var bh  := 44.0
	var gap := 58.0
	for i in _button_count():
		var r := Rect2(cx - bw * 0.5, by + i * gap - bh * 0.5, bw, bh)
		if r.has_point(mouse):
			return i
	return -1

func _button_count() -> int:
	return 3 if _has_save else 2

func _click_button(idx: int) -> void:
	if idx < 0:
		return
	if _has_save:
		match idx:
			0:
				SaveSystem.delete_save()
				GameState.reset()
				GameState.load_save_on_start = false
				get_tree().change_scene_to_file("res://scenes/Match.tscn")
			1:
				GameState.reset()
				GameState.load_save_on_start = true
				get_tree().change_scene_to_file("res://scenes/Match.tscn")
			2:
				get_tree().quit()
	else:
		match idx:
			0:
				GameState.reset()
				GameState.load_save_on_start = false
				get_tree().change_scene_to_file("res://scenes/Match.tscn")
			1:
				get_tree().quit()

func _draw() -> void:
	var vp  := get_viewport_rect().size
	var font := ThemeDB.fallback_font

	# Background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.07, 0.06, 0.04))

	# Subtle grid lines
	var grid_col := Color(0.16, 0.14, 0.10, 0.45)
	var step := 80.0
	var x := 0.0
	while x <= vp.x:
		draw_line(Vector2(x, 0), Vector2(x, vp.y), grid_col, 1.0)
		x += step
	var y := 0.0
	while y <= vp.y:
		draw_line(Vector2(0, y), Vector2(vp.x, y), grid_col, 1.0)
		y += step

	# Title
	var title := "SALVAGE ARENA"
	draw_string(font, Vector2(0.0, vp.y * 0.32),
		title, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 64, Color(0.95, 0.78, 0.20))

	# Subtitle
	draw_string(font, Vector2(0.0, vp.y * 0.32 + 56.0),
		"MechaRTS", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 22, Color(0.65, 0.60, 0.45, 0.80))

	# Buttons
	var cx  := vp.x * 0.5
	var by  := vp.y * 0.56
	var bw  := 260.0
	var bh  := 44.0
	var gap := 58.0
	var labels: Array
	if _has_save:
		labels = ["NEW GAME", "CONTINUE", "QUIT"]
	else:
		labels = ["NEW GAME", "QUIT"]

	for i in labels.size():
		var r := Rect2(cx - bw * 0.5, by + i * gap - bh * 0.5, bw, bh)
		var hot := (i == _hovered)
		var bg_col  := Color(0.28, 0.22, 0.10) if hot else Color(0.14, 0.12, 0.08)
		var bdr_col := Color(0.90, 0.72, 0.20) if hot else Color(0.40, 0.35, 0.20)
		var txt_col := Color(1.00, 0.90, 0.40) if hot else Color(0.75, 0.68, 0.40)
		draw_rect(r, bg_col)
		draw_rect(r, bdr_col, false, 1.5)
		draw_string(font, Vector2(0.0, r.position.y + bh * 0.5 + 7.0),
			labels[i], HORIZONTAL_ALIGNMENT_CENTER, vp.x, 18, txt_col)

	# Footer
	draw_string(font, Vector2(0.0, vp.y - 22.0),
		"Phase 0–11  •  Godot 4", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 12,
		Color(0.40, 0.38, 0.30, 0.55))
