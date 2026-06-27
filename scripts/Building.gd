extends Node2D

const DEFS: Dictionary = {
	"matter_converter":  { "label": "Matter Conv.",   "cost": 100.0, "time":  8.0, "color": Color(0.35, 0.75, 0.35), "size": Vector2( 80,  60) },
	"energy_bank":       { "label": "Energy Bank",    "cost": 150.0, "time": 10.0, "color": Color(1.00, 0.70, 0.10), "size": Vector2( 64,  64), "cap_bonus": 500.0 },
	"vehicle_factory":   { "label": "Vehicle Factory","cost": 200.0, "time": 15.0, "color": Color(0.40, 0.50, 0.90), "size": Vector2(100,  80) },
	"bot_parts_factory": { "label": "Parts Factory",  "cost": 250.0, "time": 18.0, "color": Color(0.75, 0.35, 0.85), "size": Vector2( 90,  90) },
	"assembly_bay":      { "label": "Assembly Bay",   "cost": 300.0, "time": 20.0, "color": Color(0.85, 0.50, 0.25), "size": Vector2(120, 100) },
}

var building_type:  String  = ""
var build_cost:     float   = 0.0
var build_time:     float   = 10.0
var build_progress: float   = 0.0
var is_ghost:       bool    = true
var is_built:       bool    = false

var _color:     Color   = Color.WHITE
var _size:      Vector2 = Vector2(80, 60)
var _cap_bonus: float   = 0.0

func setup(type: String) -> void:
	building_type = type
	var def: Dictionary = DEFS[type]
	build_cost  = def["cost"]
	build_time  = def["time"]
	_color      = def["color"]
	_size       = def["size"]
	_cap_bonus  = def.get("cap_bonus", 0.0)
	add_to_group("buildings")
	queue_redraw()

func place() -> void:
	is_ghost = false
	queue_redraw()

func advance_build(delta: float) -> bool:
	build_progress = minf(build_progress + delta / build_time, 1.0)
	queue_redraw()
	if build_progress >= 1.0 and not is_built:
		is_built = true
		if _cap_bonus > 0.0:
			GameState.energy_cap += _cap_bonus
		queue_redraw()
		return true
	return false

func _draw() -> void:
	var half := _size / 2.0
	var rect := Rect2(-half, _size)

	if is_ghost:
		draw_rect(rect, Color(_color.r, _color.g, _color.b, 0.22))
		draw_rect(rect, Color(_color.r, _color.g, _color.b, 0.75), false, 1.5)
		return

	if not is_built:
		draw_rect(rect, Color(_color.r, _color.g, _color.b, 0.45))
		draw_rect(rect, Color(_color.r, _color.g, _color.b, 0.90), false, 1.5)
		var bar_y := half.y + 5.0
		draw_rect(Rect2(-half.x, bar_y, _size.x, 7.0), Color(0.08, 0.08, 0.08, 0.85))
		draw_rect(Rect2(-half.x, bar_y, _size.x * build_progress, 7.0), Color(0.2, 1.0, 0.45, 0.9))
		draw_rect(Rect2(-half.x, bar_y, _size.x, 7.0), Color(1, 1, 1, 0.25), false, 1.0)
	else:
		draw_rect(rect, _color)
		draw_rect(rect, Color(1, 1, 1, 0.25), false, 1.5)
		var label: String = DEFS[building_type]["label"]
		draw_string(ThemeDB.fallback_font, Vector2(-half.x + 4.0, half.y - 5.0),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.9))
