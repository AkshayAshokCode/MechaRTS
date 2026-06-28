extends Control

var _buttons: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Unpause automatically if the match ends so the GameOver overlay can work
	GameState.game_over.connect(func(_won: bool) -> void:
		if get_tree().paused:
			_set_paused(false))

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
			if GameState.game_ended:
				return
			get_viewport().set_input_as_handled()
			_toggle()
			return

	if not get_tree().paused:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			for btn in _buttons:
				if (btn["rect"] as Rect2).has_point(mb.position):
					get_viewport().set_input_as_handled()
					_execute(btn["action"])
					return

func _toggle() -> void:
	_set_paused(not get_tree().paused)

func _set_paused(pause: bool) -> void:
	get_tree().paused = pause
	mouse_filter      = Control.MOUSE_FILTER_STOP if pause else Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _execute(action: String) -> void:
	match action:
		"resume":
			_set_paused(false)
		"save_close":
			var world: Node = get_tree().get_first_node_in_group("world_root")
			if world != null:
				SaveSystem.save_game(world as Node2D)
			_set_paused(false)
			GameState.reset()
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _draw() -> void:
	_buttons.clear()
	if not get_tree().paused:
		return

	var vp   := get_viewport().get_visible_rect().size
	var font := ThemeDB.fallback_font

	# Full-screen dim
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.70))

	# Panel
	var pw := 280.0
	var ph := 230.0
	var px := (vp.x - pw) * 0.5
	var py := (vp.y - ph) * 0.5

	draw_rect(Rect2(px, py, pw, ph), Color(0.07, 0.11, 0.20, 0.97))
	draw_rect(Rect2(px, py, pw, ph), Color(0.28, 0.42, 0.68, 0.90), false, 2.0)
	# Top accent
	draw_rect(Rect2(px, py, pw, 4.0), Color(0.38, 0.62, 1.00, 0.85))

	# Title
	draw_string(font, Vector2(px, py + 50.0), "PAUSED",
		HORIZONTAL_ALIGNMENT_CENTER, pw, 26, Color(0.82, 0.92, 1.00, 0.95))

	var bw := 200.0
	var bx := px + (pw - bw) * 0.5

	_draw_btn(bx, py + 82.0,  bw, 38.0, "resume",
		"RESUME",        Color(0.14, 0.26, 0.48), font)
	_draw_btn(bx, py + 134.0, bw, 38.0, "save_close",
		"SAVE & CLOSE",  Color(0.26, 0.13, 0.09), font)

func _draw_btn(bx: float, by: float, bw: float, bh: float,
		action: String, label: String, bg: Color, font: Font) -> void:
	draw_rect(Rect2(bx, by, bw, bh), bg)
	draw_rect(Rect2(bx + 1.0, by + 1.0, bw - 2.0, bh * 0.40), Color(1.0, 1.0, 1.0, 0.08))
	draw_rect(Rect2(bx, by, bw, bh), Color(0.44, 0.58, 0.82, 0.80), false, 1.5)
	draw_string(font, Vector2(bx, by + bh * 0.5 + 7.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, bw, 14, Color(0.92, 0.96, 1.00))
	_buttons.append({"rect": Rect2(bx, by, bw, bh), "action": action})
