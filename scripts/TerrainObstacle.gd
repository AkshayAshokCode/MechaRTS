extends Node2D

var _polygon: PackedVector2Array
var _color:   Color

func setup(poly: PackedVector2Array, col: Color = Color(0.35, 0.32, 0.28)) -> void:
	_polygon = poly
	_color   = col
	queue_redraw()

func _draw() -> void:
	if _polygon.is_empty():
		return
	# Fill
	draw_colored_polygon(_polygon, _color)
	# Edge highlight (lighter top/left feel)
	var hi := Color(_color.r + 0.12, _color.g + 0.10, _color.b + 0.08, 0.80)
	draw_polyline(_polygon, hi, 2.0, true)
	# A second, darker inner stroke for depth
	var shadow := Color(_color.r * 0.55, _color.g * 0.50, _color.b * 0.45, 0.70)
	var shrunk := PackedVector2Array()
	var c := Vector2.ZERO
	for p in _polygon:
		c += p
	c /= _polygon.size()
	for p in _polygon:
		shrunk.append(p.lerp(c, 0.18))
	draw_polyline(shrunk, shadow, 1.5, true)

# Returns an axis-aligned bounding rect of the polygon (world space)
func bounding_rect() -> Rect2:
	if _polygon.is_empty():
		return Rect2(global_position, Vector2.ZERO)
	var r := Rect2(_polygon[0] + global_position, Vector2.ZERO)
	for p in _polygon:
		r = r.expand(p + global_position)
	return r
