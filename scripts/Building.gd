extends Node2D

const DEFS: Dictionary = {
	"matter_converter":  { "label": "Matter Conv.",   "cost": 100.0, "time":  8.0, "color": Color(0.35, 0.75, 0.35), "size": Vector2( 80,  60), "hp": 800.0 },
	"energy_bank":       { "label": "Energy Bank",    "cost": 150.0, "time": 10.0, "color": Color(1.00, 0.70, 0.10), "size": Vector2( 64,  64), "cap_bonus": 500.0, "hp": 400.0 },
	"vehicle_factory":   { "label": "Vehicle Factory","cost": 200.0, "time": 15.0, "color": Color(0.40, 0.50, 0.90), "size": Vector2(100,  80), "hp": 600.0 },
	"bot_parts_factory": { "label": "Parts Factory",  "cost": 250.0, "time": 18.0, "color": Color(0.75, 0.35, 0.85), "size": Vector2( 90,  90), "hp": 500.0 },
	"assembly_bay":      { "label": "Assembly Bay",   "cost": 300.0, "time": 20.0, "color": Color(0.85, 0.50, 0.25), "size": Vector2(120, 100), "hp": 500.0 },
	"defense_relay":     { "label": "Defense Relay",  "cost": 150.0, "time": 12.0, "color": Color(0.85, 0.35, 0.12), "size": Vector2(44,   44), "hp": 250.0, "vision_range": 200.0 },
	"recon_pole":        { "label": "Recon Pole",     "cost":  80.0, "time":  8.0, "color": Color(0.20, 0.85, 0.90), "size": Vector2(20,   50), "hp": 120.0, "vision_range": 380.0 },
	"barracks":          { "label": "Barracks",       "cost": 150.0, "time": 12.0, "color": Color(0.60, 0.40, 0.20), "size": Vector2(80,   70), "hp": 400.0, "mp_cap_bonus": 5 },
}

const VEHICLE_DEFS: Dictionary = {
	"hover_truck":   { "label": "Hover Truck", "cost": 150.0, "time": 10.0, "col": Color(0.30, 0.60, 1.00) },
	"missile_truck": { "label": "Missile",     "cost": 250.0, "time": 18.0, "col": Color(0.90, 0.55, 0.15) },
	"hover_tank":    { "label": "Hover Tank",  "cost": 175.0, "time": 12.0, "col": Color(0.18, 0.85, 0.75) },
}
const VEHICLE_MANPOWER_COST: Dictionary = {
	"hover_truck":   1,
	"missile_truck": 2,
	"hover_tank":    2,
}
const PART_SET_COST := 170.0
const PART_SET_TIME := 25.0

const BPF_PART_DEFS: Dictionary = {
	"basic_torso":    { "cost":  60.0, "time":  8.0 },
	"armor_torso":    { "cost":  90.0, "time": 13.0 },
	"light_torso":    { "cost":  50.0, "time":  7.0 },
	"basic_legs":     { "cost":  55.0, "time":  8.0 },
	"speed_legs":     { "cost":  60.0, "time":  9.0 },
	"heavy_legs":     { "cost":  70.0, "time": 11.0 },
	"plasma_cannon":  { "cost":  70.0, "time": 10.0 },
	"energy_blaster": { "cost":  55.0, "time":  8.0 },
	"rocket_arm":     { "cost":  85.0, "time": 12.0 },
	"shield_arm":     { "cost":  65.0, "time":  9.0 },
	"micro_cannon":   { "cost":  45.0, "time":  6.0 },
	"siege_torso":    { "cost": 120.0, "time": 16.0 },
	"strength_legs":  { "cost":  80.0, "time": 12.0 },
	"gatling_arm":    { "cost":  70.0, "time": 10.0 },
	"heavy_shield":   { "cost":  80.0, "time": 12.0 },
	"recon_torso":    { "cost":  55.0, "time":  7.0 },
	"sonar_legs":     { "cost":  60.0, "time":  9.0 },
	"energy_shield":  { "cost":  70.0, "time": 10.0 },
	"cloak_arm":      { "cost":  70.0, "time": 10.0 },
}

var building_type:  String  = ""
var build_cost:     float   = 0.0
var build_time:     float   = 10.0
var build_progress: float   = 0.0
var is_ghost:       bool    = true
var is_built:       bool    = false
var is_hq:          bool    = false
var health:         float   = 0.0
var max_health:     float   = 0.0

var _color:     Color   = Color.WHITE
var _size:      Vector2 = Vector2(80, 60)
var _cap_bonus: float   = 0.0

var _prod_queue:    Array = []   # FIFO of String (vehicle type keys)
var _prod_progress: float = 0.0

var vision_range:   float = 200.0
var _relay_timer:   float = 0.0
var _bpf_queue:     Array = []
var _bpf_progress:  float = 0.0
var _mp_cap_bonus:  int   = 0

var _pulse:         float = 0.0
var _builder_count: int   = 0
var placement_valid: bool = true   # set by BuildMenu while ghost; red tint when false

func add_builder() -> void:
	_builder_count += 1

func remove_builder() -> void:
	_builder_count = maxi(0, _builder_count - 1)

func setup(type: String) -> void:
	building_type = type
	var def: Dictionary = DEFS[type]
	build_cost  = def["cost"]
	build_time  = def["time"]
	_color      = def["color"]
	_size       = def["size"]
	_cap_bonus    = def.get("cap_bonus", 0.0)
	_mp_cap_bonus = int(def.get("mp_cap_bonus", 0))
	max_health    = def.get("hp", 0.0)
	health        = max_health
	vision_range  = def.get("vision_range", 200.0)
	is_hq         = (type == "matter_converter")
	add_to_group("buildings")
	queue_redraw()

func take_damage(amount: float, _hit_from: Vector2 = Vector2.ZERO) -> void:
	if max_health <= 0.0 or not is_built:
		return
	health = maxf(0.0, health - amount)
	GameState.attack_at.emit(global_position)
	queue_redraw()
	if health <= 0.0:
		if is_hq:
			GameState.end_game(false)
		if _mp_cap_bonus > 0:
			GameState.manpower_cap = maxi(GameState.manpower_cap - _mp_cap_bonus, 10)
			GameState.manpower = mini(GameState.manpower, GameState.manpower_cap)
			GameState.manpower_changed.emit(GameState.manpower)
		queue_free()

func place() -> void:
	is_ghost = false
	queue_redraw()
	# Notify nav manager to rebake so units route around this building
	if get_tree() != null:
		for nm in get_tree().get_nodes_in_group("nav_manager"):
			if nm.has_method("on_building_placed"):
				nm.on_building_placed(self)

func advance_build(delta: float) -> bool:
	build_progress = minf(build_progress + delta / build_time, 1.0)
	queue_redraw()
	if build_progress >= 1.0 and not is_built:
		is_built = true
		if _cap_bonus > 0.0:
			GameState.energy_cap += _cap_bonus
		if _mp_cap_bonus > 0:
			GameState.manpower_cap += _mp_cap_bonus
			GameState.manpower_changed.emit(GameState.manpower)
		queue_redraw()
		return true
	return false

func queue_vehicle(type: String) -> bool:
	if not is_built or building_type != "vehicle_factory":
		return false
	if not VEHICLE_DEFS.has(type):
		return false
	var mp_cost: int = VEHICLE_MANPOWER_COST.get(type, 1)
	if not GameState.spend_manpower(mp_cost):
		return false
	if not GameState.spend_energy(VEHICLE_DEFS[type]["cost"]):
		GameState.add_manpower(mp_cost)   # refund manpower if can't afford MJ
		return false
	_prod_queue.append(type)
	return true

func dequeue_vehicle(type: String) -> bool:
	if not is_built or building_type != "vehicle_factory":
		return false
	# Remove the last occurrence so we cancel the most recently queued item first
	for i in range(_prod_queue.size() - 1, -1, -1):
		if _prod_queue[i] == type:
			_prod_queue.remove_at(i)
			if i == 0:
				_prod_progress = 0.0   # reset progress if cancelling the active build
			GameState.add_manpower(VEHICLE_MANPOWER_COST.get(type, 1))
			GameState.add_energy(VEHICLE_DEFS[type]["cost"])
			queue_redraw()
			return true
	return false

func dequeue_part(part_id: String) -> bool:
	if not is_built or building_type != "bot_parts_factory":
		return false
	for i in range(_bpf_queue.size() - 1, -1, -1):
		if _bpf_queue[i] == part_id:
			_bpf_queue.remove_at(i)
			if i == 0:
				_bpf_progress = 0.0
			GameState.add_energy(BPF_PART_DEFS[part_id]["cost"])
			queue_redraw()
			return true
	return false

func get_production_info() -> Dictionary:
	if building_type != "vehicle_factory" or not is_built:
		return {}
	return {
		"queue":        _prod_queue.duplicate(),
		"progress":     _prod_progress,
		"vehicle_defs": VEHICLE_DEFS,
	}

func queue_part_set() -> bool:
	if not is_built or building_type != "bot_parts_factory":
		return false
	if not GameState.spend_energy(PART_SET_COST):
		return false
	_bpf_queue.append("basic_torso")
	_bpf_queue.append("basic_legs")
	_bpf_queue.append("plasma_cannon")
	return true

func queue_part(part_id: String) -> bool:
	if not is_built or building_type != "bot_parts_factory":
		return false
	if not BPF_PART_DEFS.has(part_id):
		return false
	var cost: float = BPF_PART_DEFS[part_id]["cost"]
	if not GameState.spend_energy(cost):
		return false
	_bpf_queue.append(part_id)
	return true

func get_bpf_info() -> Dictionary:
	if building_type != "bot_parts_factory" or not is_built:
		return {}
	var cur_time := 0.0
	if not _bpf_queue.is_empty():
		cur_time = BPF_PART_DEFS.get(_bpf_queue[0], {"time": 8.0}).get("time", 8.0)
	return {
		"queue":    _bpf_queue.duplicate(),
		"progress": _bpf_progress,
		"cur_time": cur_time,
	}

func get_collision_radius() -> float:
	return max(_size.x, _size.y) * 0.5 + 4.0

func contains_point(world_pos: Vector2) -> bool:
	var half := _size * 0.5
	return Rect2(global_position - half, _size).has_point(world_pos)

func _process(delta: float) -> void:
	if is_built:
		_pulse = fmod(_pulse + delta * 1.5, TAU)
		queue_redraw()

	if is_built and building_type == "vehicle_factory" and not _prod_queue.is_empty():
		var cur_type: String = _prod_queue[0]
		_prod_progress += delta / VEHICLE_DEFS[cur_type]["time"]
		if _prod_progress >= 1.0:
			_prod_progress = 0.0
			_prod_queue.pop_front()
			_spawn_vehicle(cur_type)
		queue_redraw()

	if is_built and building_type == "bot_parts_factory" and not _bpf_queue.is_empty():
		var cur_id: String = _bpf_queue[0]
		var cur_time: float = BPF_PART_DEFS.get(cur_id, {"time": 8.0}).get("time", 8.0)
		_bpf_progress += delta / cur_time
		if _bpf_progress >= 1.0:
			_bpf_progress = 0.0
			_bpf_queue.pop_front()
			_deliver_part(cur_id)
		queue_redraw()

	if is_built and building_type == "defense_relay":
		_relay_timer -= delta
		if _relay_timer <= 0.0:
			var enemy := _find_nearest_enemy(180.0)
			if enemy != null:
				_fire_at_enemy(enemy, 20.0)
				_relay_timer = 2.0
			else:
				_relay_timer = 0.4
		queue_redraw()

func _spawn_vehicle(type: String) -> void:
	var script_path: String
	match type:
		"hover_truck":   script_path = "res://scripts/HoverTruck.gd"
		"missile_truck": script_path = "res://scripts/MissileTruck.gd"
		"hover_tank":    script_path = "res://scripts/HoverTank.gd"
		_:               script_path = "res://scripts/HoverTruck.gd"
	var v: Node2D = load(script_path).new()
	v.position = _find_clear_spawn()
	v.z_index  = 50
	get_parent().add_child(v)

const _SPAWN_R := 30.0   # minimum centre-to-centre clearance

# Spiral outward from the factory exit until a clear slot is found.
func _find_clear_spawn() -> Vector2:
	var exit := global_position + Vector2(_size.x * 0.5 + _SPAWN_R, 0.0)
	for ring in range(7):
		if ring == 0:
			if _spawn_clear(exit):
				return exit
		else:
			var r     := ring * _SPAWN_R
			var count := ring * 8
			for i in count:
				var angle := float(i) / float(count) * TAU
				var c := exit + Vector2(cos(angle), sin(angle)) * r
				if _spawn_clear(c):
					return c
	return exit

func _spawn_clear(pos: Vector2) -> bool:
	if get_tree() == null:
		return true
	var min_sq := _SPAWN_R * _SPAWN_R
	for u in get_tree().get_nodes_in_group("units"):
		if (u as Node2D).global_position.distance_squared_to(pos) < min_sq:
			return false
	for b in get_tree().get_nodes_in_group("buildings"):
		if b == self:
			continue
		var bpos := (b as Node2D).global_position
		var bsz: Variant = (b as Object).get("_size")
		if not bsz is Vector2:
			continue
		var half := (bsz as Vector2) * 0.5 + Vector2(14.0, 14.0)
		if absf(pos.x - bpos.x) < half.x and absf(pos.y - bpos.y) < half.y:
			return false
	return true

func _deliver_part(part_id: String) -> void:
	var cat: Array = load("res://scripts/PartCatalog.gd").ALL
	for p in cat:
		if (p as Dictionary).get("id", "") == part_id:
			GameState.add_part((p as Dictionary).duplicate())
			return

func _find_nearest_enemy(range_px: float) -> Node:
	var nearest: Node = null
	var best_sq := range_px * range_px
	for e in get_tree().get_nodes_in_group("enemy_units"):
		var d := global_position.distance_squared_to((e as Node2D).global_position)
		if d < best_sq:
			best_sq = d
			nearest = e
	return nearest

func _fire_at_enemy(target: Node, dmg: float) -> void:
	if get_parent() == null:
		return
	var proj: Node2D = load("res://scripts/Projectile.gd").new()
	proj.setup(global_position, (target as Node2D).global_position, dmg, 0)
	get_parent().add_child(proj)

func _draw() -> void:
	var half := _size / 2.0
	var rect := Rect2(-half, _size)

	if is_ghost:
		var gc := _color if placement_valid else Color(1.0, 0.15, 0.10)
		draw_rect(rect, Color(gc.r, gc.g, gc.b, 0.22))
		draw_rect(rect, Color(gc.r, gc.g, gc.b, 0.75), false, 1.5)
		if not placement_valid:
			draw_string(ThemeDB.fallback_font, Vector2(-22.0, 5.0), "BLOCKED",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.25, 0.15, 0.90))
		return

	# ── Plan-oblique 3D box (Metal Fatigue style) ─────────────────────────────
	# ISO Y scale = 0.55: to appear H_screen px up, local offset = (0, -H_screen/0.55).
	# Only south face (horizontal band) is visible; no east wall in plan-oblique.
	const ISO_Y  := 0.55
	var H_screen := minf(_size.x, _size.y) * 0.30 * (build_progress if not is_built else 1.0)
	var H_local  := H_screen / ISO_Y
	var hw := half.x
	var hh := half.y
	var top_off := Vector2(0.0, -H_local)

	if H_local > 1.0:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-hw, hh), Vector2(hw, hh),
			Vector2(hw, hh - H_local), Vector2(-hw, hh - H_local),
		]), _color.darkened(0.45))

	if not is_built:
		var top_col := Color(_color.r, _color.g, _color.b, 0.45)
		if H_local > 1.0:
			draw_colored_polygon(PackedVector2Array([
				Vector2(-hw, -hh) + top_off, Vector2(hw, -hh) + top_off,
				Vector2(hw,  hh)  + top_off, Vector2(-hw, hh) + top_off,
			]), top_col)
		else:
			draw_rect(rect, top_col)
		draw_rect(rect, Color(_color.r, _color.g, _color.b, 0.90), false, 1.5)
		var bar_y := hh + 5.0
		var bar_col := Color(0.2, 1.0, 0.45, 0.9) if _builder_count <= 1 else Color(0.25, 0.75, 1.0, 0.95)
		draw_rect(Rect2(-hw, bar_y, _size.x, 7.0), Color(0.08, 0.08, 0.08, 0.85))
		draw_rect(Rect2(-hw, bar_y, _size.x * build_progress, 7.0), bar_col)
		draw_rect(Rect2(-hw, bar_y, _size.x, 7.0), Color(1, 1, 1, 0.25), false, 1.0)
		if _builder_count > 1:
			draw_string(ThemeDB.fallback_font, Vector2(-hw + 2.0, bar_y - 2.0),
				"×%d" % _builder_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.25, 0.85, 1.0, 0.95))
	else:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-hw, -hh) + top_off, Vector2(hw, -hh) + top_off,
			Vector2(hw,  hh)  + top_off, Vector2(-hw, hh) + top_off,
		]), _color)

		var glow_a  := sin(_pulse) * 0.12 + 0.14
		var gc2     := Color(minf(_color.r * 1.3, 1.0), minf(_color.g * 1.3, 1.0), minf(_color.b * 1.3, 1.0), glow_a)
		var top_rect := Rect2(-hw, -hh + top_off.y, _size.x, _size.y)
		draw_rect(top_rect, gc2, false, 3.5)
		draw_rect(top_rect, Color(1, 1, 1, 0.20), false, 1.2)

		var label: String = DEFS[building_type]["label"]
		draw_string(ThemeDB.fallback_font,
			Vector2(-hw + 4.0, top_off.y + hh - 5.0),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.9))

		if is_hq:
			draw_string(ThemeDB.fallback_font,
				Vector2(-hw + 4.0, top_off.y - hh + 12.0),
				"HQ", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 1.0, 0.3, 0.95))

		if building_type == "defense_relay":
			draw_rect(Rect2(hw - 6.0, top_off.y - 5.0, 14.0, 10.0), _color.lightened(0.3))
			draw_rect(Rect2(hw + 6.0, top_off.y - 2.5, 14.0,  5.0), _color.lightened(0.5))
			draw_arc(Vector2(0.0, top_off.y), 180.0, 0.0, TAU, 24, Color(_color.r, _color.g, _color.b, 0.12), 1.0)
		elif building_type == "recon_pole":
			var ant_base := Vector2(0.0, -hh + top_off.y)
			draw_line(ant_base, ant_base + Vector2(0.0, -18.0), _color.lightened(0.5), 2.0)
			draw_line(ant_base + Vector2(-8.0, -12.0), ant_base + Vector2(8.0, -12.0), _color.lightened(0.3), 1.5)
			var pr := 8.0 + sin(_pulse) * 4.0
			draw_arc(ant_base + Vector2(0.0, -18.0), pr, 0.0, TAU, 8,
				Color(_color.r, _color.g, _color.b, 0.5 + sin(_pulse) * 0.2), 1.5)

		if max_health > 0.0 and health < max_health:
			var bar_y := hh + 8.0
			draw_rect(Rect2(-hw, bar_y, _size.x, 5.0), Color(0.08, 0.08, 0.08, 0.90))
			var ratio := health / max_health
			var hcol := Color(0.2, 1.0, 0.2) if ratio > 0.5 else (Color(1.0, 0.55, 0.0) if ratio > 0.25 else Color(1.0, 0.1, 0.1))
			draw_rect(Rect2(-hw, bar_y, _size.x * ratio, 5.0), hcol)
		if building_type == "vehicle_factory" and not _prod_queue.is_empty():
			var bar_y := hh + 16.0
			var prod_col: Color = VEHICLE_DEFS[_prod_queue[0]]["col"]
			draw_rect(Rect2(-hw, bar_y, _size.x, 5.0), Color(0.08, 0.08, 0.08, 0.85))
			draw_rect(Rect2(-hw, bar_y, _size.x * _prod_progress, 5.0),
				Color(prod_col.r, prod_col.g, prod_col.b, 0.9))
		if building_type == "bot_parts_factory" and not _bpf_queue.is_empty():
			var bar_y := hh + 5.0
			draw_rect(Rect2(-hw, bar_y, _size.x, 5.0), Color(0.08, 0.08, 0.08, 0.85))
			draw_rect(Rect2(-hw, bar_y, _size.x * _bpf_progress, 5.0),
				Color(0.75, 0.35, 0.90, 0.9))
