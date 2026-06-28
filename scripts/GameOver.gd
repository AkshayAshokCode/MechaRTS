extends Control

var _won: bool = false

func _ready() -> void:
	GameState.game_over.connect(_on_game_over)
	visible        = false
	mouse_filter   = Control.MOUSE_FILTER_STOP
	set_process_input(false)

func _on_game_over(won: bool) -> void:
	_won    = won
	visible = true
	set_process_input(true)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_R:
			GameState.reset()
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _draw() -> void:
	var vp   := get_viewport_rect().size
	var font := ThemeDB.fallback_font

	# Dim backdrop
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.74))

	# Title
	var title     := "VICTORY" if _won else "DEFEAT"
	var title_col := Color(0.30, 1.00, 0.42) if _won else Color(1.00, 0.20, 0.15)
	draw_string(font, Vector2(0.0, vp.y * 0.42), title,
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 72, title_col)

	# Subtitle
	var sub := "Enemy base destroyed." if _won else "Your base has been overrun."
	var sub_col := Color(0.75, 1.00, 0.78) if _won else Color(1.00, 0.65, 0.60)
	draw_string(font, Vector2(0.0, vp.y * 0.42 + 60.0), sub,
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 20, sub_col)

	# Restart hint
	draw_string(font, Vector2(0.0, vp.y * 0.42 + 96.0), "Press  R  to return to main menu",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 16, Color(1.0, 1.0, 1.0, 0.60))
