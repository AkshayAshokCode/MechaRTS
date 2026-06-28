extends Node2D

const MAP_W := 6400.0
const MAP_H := 4800.0

func _ready() -> void:
	z_index = -10
	queue_redraw()

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xDA7A5A1A   # fixed — terrain never changes between runs

	# ── 1. Base soil ──────────────────────────────────────────────────────
	draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_W, MAP_H)), Color(0.17, 0.13, 0.08))

	# ── 2. Diagonal highland ridge (SW → NE, matches choke-point layout) ─
	var spine: Array = [
		Vector2( 250, 4600), Vector2( 650, 4050), Vector2(1150, 3450),
		Vector2(1750, 2900), Vector2(2550, 2250), Vector2(3350, 1650),
		Vector2(4150, 1100), Vector2(4950,  630), Vector2(5700,  240),
	]
	_corridor(spine, 550, 370, Color(0.30, 0.23, 0.13, 0.40))   # wide base
	_corridor(spine, 240, 160, Color(0.44, 0.35, 0.21, 0.35))   # bright crest

	# ── 3. Biome blobs ────────────────────────────────────────────────────
	# Player SW — fertile, green
	_blob(Vector2( 900, 4200), 1500,  900, Color(0.20, 0.29, 0.10, 0.55))
	_blob(Vector2( 350, 3900),  900,  750, Color(0.22, 0.31, 0.11, 0.48))
	_blob(Vector2(1500, 4600), 1100,  680, Color(0.19, 0.27, 0.09, 0.42))
	_blob(Vector2( 150, 4650),  650,  430, Color(0.24, 0.33, 0.12, 0.50))

	# Enemy NE — rocky dust
	_blob(Vector2(5300,  700), 1350,  900, Color(0.37, 0.27, 0.16, 0.55))
	_blob(Vector2(5850,  320),  900,  650, Color(0.43, 0.32, 0.20, 0.50))
	_blob(Vector2(4850,  980),  950,  720, Color(0.34, 0.25, 0.15, 0.45))
	_blob(Vector2(6200,  650),  480,  380, Color(0.40, 0.30, 0.19, 0.40))

	# Centre — dry plains
	_blob(Vector2(3200, 2400), 1700, 1200, Color(0.27, 0.21, 0.12, 0.45))
	_blob(Vector2(2500, 3050), 1200,  900, Color(0.25, 0.19, 0.11, 0.40))
	_blob(Vector2(3950, 1950), 1100,  850, Color(0.29, 0.22, 0.13, 0.42))

	# North edge — cooler rock
	_blob(Vector2(1800,  400), 1600,  600, Color(0.22, 0.18, 0.12, 0.38))
	_blob(Vector2(3600,  300), 1400,  500, Color(0.20, 0.16, 0.11, 0.35))

	# South edge — dark lowland
	_blob(Vector2(3500, 4700), 2000,  500, Color(0.15, 0.18, 0.09, 0.40))
	_blob(Vector2(5000, 4700), 1400,  450, Color(0.16, 0.13, 0.08, 0.35))

	# ── 4. Scattered green patches (vegetation, clearings) ────────────────
	for _i in 72:
		var cx := rng.randf_range(100.0, MAP_W - 100.0)
		var cy := rng.randf_range(100.0, MAP_H - 100.0)
		_blob(Vector2(cx, cy),
			rng.randf_range(55.0, 310.0), rng.randf_range(40.0, 210.0),
			Color(rng.randf_range(0.13, 0.26),
				  rng.randf_range(0.19, 0.36),
				  rng.randf_range(0.05, 0.14),
				  rng.randf_range(0.16, 0.36)))

	# ── 5. Scattered earth / rock patches ─────────────────────────────────
	for _i in 65:
		var cx := rng.randf_range(100.0, MAP_W - 100.0)
		var cy := rng.randf_range(100.0, MAP_H - 100.0)
		_blob(Vector2(cx, cy),
			rng.randf_range(45.0, 270.0), rng.randf_range(30.0, 190.0),
			Color(rng.randf_range(0.23, 0.44),
				  rng.randf_range(0.16, 0.30),
				  rng.randf_range(0.08, 0.17),
				  rng.randf_range(0.15, 0.33)))

	# ── 6. Hilltop highlights (lighter = elevated) ────────────────────────
	for _i in 45:
		var cx := rng.randf_range(200.0, MAP_W - 200.0)
		var cy := rng.randf_range(200.0, MAP_H - 200.0)
		_blob(Vector2(cx, cy),
			rng.randf_range(25.0, 150.0), rng.randf_range(18.0, 105.0),
			Color(rng.randf_range(0.38, 0.56),
				  rng.randf_range(0.30, 0.46),
				  rng.randf_range(0.18, 0.30),
				  rng.randf_range(0.10, 0.22)))

	# ── 7. Dark lowland pockets (valleys / ravines) ───────────────────────
	for _i in 30:
		var cx := rng.randf_range(150.0, MAP_W - 150.0)
		var cy := rng.randf_range(150.0, MAP_H - 150.0)
		_blob(Vector2(cx, cy),
			rng.randf_range(60.0, 220.0), rng.randf_range(40.0, 140.0),
			Color(rng.randf_range(0.08, 0.14),
				  rng.randf_range(0.06, 0.12),
				  rng.randf_range(0.04, 0.08),
				  rng.randf_range(0.18, 0.38)))


func _corridor(spine: Array, half_w: float, half_h: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for p: Vector2 in spine:
		pts.append(Vector2(p.x - half_w, p.y - half_h))
	for i in range(spine.size() - 1, -1, -1):
		var p: Vector2 = spine[i]
		pts.append(Vector2(p.x + half_w, p.y + half_h))
	draw_colored_polygon(pts, col)


func _blob(center: Vector2, rx: float, ry: float, col: Color) -> void:
	const N := 20
	var pts := PackedVector2Array()
	for i in N:
		var a := float(i) / float(N) * TAU
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
