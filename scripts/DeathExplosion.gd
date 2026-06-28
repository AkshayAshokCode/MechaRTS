extends Node2D

const DURATION     := 0.55
const DEBRIS_COUNT := 8

var _time:   float = 0.0
var _debris: Array = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in DEBRIS_COUNT:
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(120.0, 190.0)
		_debris.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"r":   rng.randf_range(2.5, 5.0),
		})

func _process(delta: float) -> void:
	_time += delta
	var drag := exp(-4.0 * delta)
	for d in _debris:
		d["pos"] += (d["vel"] as Vector2) * delta
		d["vel"]  = (d["vel"] as Vector2) * drag
	queue_redraw()
	if _time >= DURATION:
		queue_free()

func _draw() -> void:
	var t := _time / DURATION

	# White-hot inner flash (first 28% of lifetime)
	if t < 0.28:
		var f := 1.0 - t / 0.28
		draw_circle(Vector2.ZERO, 20.0 * (t / 0.28 + 0.25), Color(1.0, 0.95, 0.7, f * 0.70))

	# Expanding fire ring
	var ring_r := 8.0 + t * 40.0
	var ring_a := (1.0 - t) * 0.90
	var ring_g := lerpf(0.15, 0.55, 1.0 - t)
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 28, Color(1.0, ring_g, 0.05, ring_a), 3.5)

	# Smoke ring (delayed start)
	if t > 0.25:
		var st := (t - 0.25) / 0.75
		var sm_r := ring_r * 0.65 + st * 24.0
		draw_arc(Vector2.ZERO, sm_r, 0.0, TAU, 20,
			Color(0.38, 0.35, 0.32, (1.0 - st) * 0.42), 6.5)

	# Debris embers
	for d in _debris:
		var da  := (1.0 - t) * 0.92
		var dr  := (d["r"] as float) * (1.0 - t * 0.55)
		var dg  := lerpf(0.20, 0.78, 1.0 - t)
		draw_circle(d["pos"] as Vector2, dr, Color(1.0, dg, 0.10, da))
