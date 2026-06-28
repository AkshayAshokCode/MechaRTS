extends Node2D

const DURATION := 0.09

var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _time >= DURATION:
		queue_free()

func _draw() -> void:
	var t     := _time / DURATION
	var alpha := 1.0 - t
	var r     := 5.0 + t * 6.0

	# Central burst
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.95, 0.65, alpha * 0.92))

	# Four directional spikes
	for i in 4:
		var angle := i * PI * 0.5
		var tip   := Vector2(cos(angle), sin(angle)) * (r * 2.5)
		var perp  := Vector2(-sin(angle), cos(angle)) * (r * 0.32)
		draw_colored_polygon(
			PackedVector2Array([perp, tip, -perp]),
			Color(1.0, 0.85, 0.40, alpha * 0.72))
