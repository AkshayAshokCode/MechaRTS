extends Node2D

const DEFS: Dictionary = {
	"vehicle_factory": { "label": "Vehicle Factory", "cost": 200.0, "time": 15.0,
		"color": Color(0.72, 0.22, 0.22), "size": Vector2(100, 80), "hp": 600.0, "spawn_time": 20.0 },
	"defense_relay":   { "label": "Defense Relay",   "cost": 150.0, "time": 12.0,
		"color": Color(0.85, 0.28, 0.10), "size": Vector2(44,  44), "hp": 250.0 },
}

var building_type:  String  = ""
var build_cost:     float   = 0.0
var build_time:     float   = 15.0
var build_progress: float   = 0.0
var is_ghost:       bool    = false
var is_built:       bool    = false
var health:         float   = 0.0
var max_health:     float   = 0.0
var vision_range:   float   = 200.0

var _color: Color   = Color(0.72, 0.22, 0.22)
var _size:  Vector2 = Vector2(100, 80)
var _pulse: float   = 0.0

var _spawn_timer: float = 0.0
var _spawn_time:  float = 20.0
var _relay_timer: float = 0.0

var ai_player: Node = null

func setup(type: String, ai: Node) -> void:
	building_type = type
	ai_player     = ai
	var def       := DEFS[type]
	build_cost    = def["cost"]
	build_time    = def["time"]
	_color        = def["color"]
	_size         = def["size"]
	max_health    = def.get("hp", 0.0)
	health        = max_health
	_spawn_time   = def.get("spawn_time", 20.0)
	add_to_group("enemy_buildings")
	queue_redraw()

func get_collision_radius() -> float:
	return max(_size.x, _size.y) * 0.5 + 4.0

func contains_point(world_pos: Vector2) -> bool:
	var half := _size * 0.5
	return Rect2(global_position - half, _size).has_point(world_pos)

func take_damage(amount: float, _from: Vector2 = Vector2.ZERO) -> void:
	health = maxf(0.0, health - amount)
	queue_redraw()
	if health <= 0.0:
		queue_free()

func advance_build(delta: float) -> bool:
	build_progress = minf(build_progress + delta / build_time, 1.0)
	queue_redraw()
	if build_progress >= 1.0 and not is_built:
		is_built = true
		queue_redraw()
		return true
	return false

func _process(delta: float) -> void:
	if not is_built:
		return
	_pulse = fmod(_pulse + delta * 1.5, TAU)
	queue_redraw()

	if building_type == "vehicle_factory":
		_spawn_timer += delta
		if _spawn_timer >= _spawn_time:
			_spawn_timer = 0.0
			_spawn_enemy_unit()

	if building_type == "defense_relay":
		_relay_timer -= delta
		if _relay_timer <= 0.0:
			var target := _find_nearest_player(180.0)
			if target != null:
				_fire_at(target, 20.0)
				_relay_timer = 2.0
			else:
				_relay_timer = 0.4

func _spawn_enemy_unit() -> void:
	var eu: Node2D = load("res://scripts/EnemyUnit.gd").new()
	eu.position    = global_position + Vector2(_size.x * 0.5 + 30.0, 0.0)
	eu.z_index     = 50
	get_parent().add_child(eu)
	# Rally newly-spawned units to garrison point
	for ai in get_tree().get_nodes_in_group("ai_player"):
		var rally: Vector2 = ai.get("_garrison_rally")
		eu.set("move_target", rally if rally != Vector2.ZERO else eu.position)
		break

func _find_nearest_player(range_px: float) -> Node:
	var best_sq := range_px * range_px
	var nearest: Node = null
	for u in get_tree().get_nodes_in_group("units"):
		var d := global_position.distance_squared_to((u as Node2D).global_position)
		if d < best_sq:
			best_sq = d
			nearest = u
	return nearest

func _fire_at(target: Node, dmg: float) -> void:
	if get_parent() == null:
		return
	var proj: Node2D = load("res://scripts/Projectile.gd").new()
	proj.setup(global_position, (target as Node2D).global_position, dmg, 1)
	get_parent().add_child(proj)

func _draw() -> void:
	var half := _size / 2.0
	var rect := Rect2(-half, _size)

	if not is_built:
		draw_rect(rect, Color(_color.r, _color.g, _color.b, 0.45))
		draw_rect(rect, Color(_color.r, _color.g, _color.b, 0.90), false, 1.5)
		var bar_y := half.y + 5.0
		draw_rect(Rect2(-half.x, bar_y, _size.x,                     7.0), Color(0.08, 0.08, 0.08, 0.85))
		draw_rect(Rect2(-half.x, bar_y, _size.x * build_progress,    7.0), Color(1.0, 0.3, 0.3, 0.9))
		draw_rect(Rect2(-half.x, bar_y, _size.x,                     7.0), Color(1.0, 1.0, 1.0, 0.25), false, 1.0)
		return

	draw_rect(rect, _color)
	var glow_a := sin(_pulse) * 0.10 + 0.12
	draw_rect(rect, Color(1.0, 0.55, 0.55, glow_a), false, 3.0)
	draw_rect(rect, Color(1.0, 0.70, 0.70, 0.25),   false, 1.2)
	draw_string(ThemeDB.fallback_font, Vector2(-half.x + 4.0, half.y - 5.0),
		DEFS[building_type]["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.75, 0.75, 0.9))

	if building_type == "defense_relay":
		draw_rect(Rect2(half.x - 6.0, -5.0, 14.0, 10.0), _color.lightened(0.3))
		draw_rect(Rect2(half.x + 6.0, -2.5, 14.0,  5.0), _color.lightened(0.5))
		draw_arc(Vector2.ZERO, 180.0, 0.0, TAU, 24, Color(_color.r, _color.g, _color.b, 0.10), 1.0)

	if max_health > 0.0 and health < max_health:
		var bar_y := half.y + 8.0
		draw_rect(Rect2(-half.x, bar_y, _size.x,                            5.0), Color(0.08, 0.08, 0.08, 0.90))
		draw_rect(Rect2(-half.x, bar_y, _size.x * (health / max_health),    5.0), Color(1.0, 0.2, 0.1))
