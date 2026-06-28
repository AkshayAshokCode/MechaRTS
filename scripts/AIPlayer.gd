extends Node

# ── Map constants ────────────────────────────────────────────────────────────────
const GARRISON_RALLY  := Vector2(5250, 900)
const PLAYER_HQ_AREA  := Vector2(700,  4200)   # fallback if player never spotted

# Search pattern — scouts sweep the map until they find the player
const SEARCH_WAYPOINTS: Array = [
	Vector2(4000, 1600),
	Vector2(2400, 1000),
	Vector2(3600, 3000),
	Vector2(1800, 2400),
	Vector2(1000, 1600),
	Vector2(2600, 4000),
	Vector2(900,  4000),
]
const ENEMY_DETECT_RANGE := 220.0

# Spawn positions for initial garrison units
const SPAWN_POSITIONS: Array = [
	Vector2(5350, 860),
	Vector2(5450, 820),
	Vector2(5250, 900),
	Vector2(5480, 960),
]

# ── Difficulty ────────────────────────────────────────────────────────────────────
const DIFFICULTY              := 1
const _WAVE_WAIT_BY_DIFF: Array = [50.0, 30.0, 18.0]
const _MAX_UNITS_BY_DIFF: Array = [8,    14,   20  ]
const _GRACE_BY_DIFF:     Array = [180.0, 120.0, 60.0]

const GARRISON_SIZE := 3
const WAVE_MIN_SIZE := 4

# ── Economy ───────────────────────────────────────────────────────────────────────
const AI_ENERGY_START := 300.0
const AI_ENERGY_CAP   := 2000.0

# ── Build plan — AI constructs these in order as it saves up energy ───────────────
# Positions chosen to not overlap the Command Post HQ at (5300, 580)
const AI_BUILD_PLAN: Array = [
	{ "type": "vehicle_factory", "pos": Vector2(5150, 740), "cost": 200.0 },
	{ "type": "vehicle_factory", "pos": Vector2(5500, 780), "cost": 200.0 },
	{ "type": "defense_relay",   "pos": Vector2(5080, 470), "cost": 150.0 },
	{ "type": "vehicle_factory", "pos": Vector2(4950, 900), "cost": 200.0 },
	{ "type": "defense_relay",   "pos": Vector2(5580, 530), "cost": 150.0 },
]

# ── State ─────────────────────────────────────────────────────────────────────────
var _rng         := RandomNumberGenerator.new()
var _grace_timer : float = 120.0
var _wave_timer  : float = 0.0
var _max_units:    int   = 14

var _ai_energy:   float = AI_ENERGY_START
var _trucks:      Array = []   # AIHoverTruck refs
var _build_idx:   int   = 0    # next AI_BUILD_PLAN slot to attempt
var _building_now: Node = null  # currently-under-construction AIBuilding

# Expose rally point so AIBuilding can query it
var _garrison_rally: Vector2 = GARRISON_RALLY

# Discovery state
var _player_discovered: bool    = false
var _player_last_seen:  Vector2 = PLAYER_HQ_AREA
var _search_idx:        int     = 0
var _vision_timer:      float   = 0.0

func _ready() -> void:
	add_to_group("ai_player")
	_rng.randomize()
	_grace_timer = _GRACE_BY_DIFF[DIFFICULTY]
	_wave_timer  = _WAVE_WAIT_BY_DIFF[DIFFICULTY]
	_max_units   = _MAX_UNITS_BY_DIFF[DIFFICULTY]
	# Seed a permanent starting garrison
	for _i in GARRISON_SIZE:
		_spawn_garrison_unit()

# ── Economy API (called by AIHoverTruck and AIBuilding) ───────────────────────────

func add_energy(amount: float) -> void:
	_ai_energy = minf(_ai_energy + amount, AI_ENERGY_CAP)

func spend_energy(amount: float) -> bool:
	if _ai_energy < amount:
		return false
	_ai_energy -= amount
	return true

# Called by AIHoverTruck when it self-registers on _ready
func register_truck(truck: Node) -> void:
	if truck not in _trucks:
		_trucks.append(truck)
	_assign_harvest(truck)

# Called by AIHoverTruck when it finishes building and wants a new job
func request_harvest(truck: Node) -> void:
	_assign_harvest(truck)

# ── Main loop ─────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if GameState.game_ended:
		return

	_update_trucks()
	_update_build_plan()

	if _grace_timer > 0.0:
		_grace_timer -= delta
		return

	_vision_timer -= delta
	if _vision_timer <= 0.0:
		_vision_timer = 0.5
		_update_discovery()

	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = _WAVE_WAIT_BY_DIFF[DIFFICULTY]
		_launch_wave()

# ── Truck management ──────────────────────────────────────────────────────────────

func _update_trucks() -> void:
	_trucks = _trucks.filter(func(t): return is_instance_valid(t))
	for t in _trucks:
		if t.is_idle():
			_assign_harvest(t)

func _assign_harvest(truck: Node) -> void:
	var best: Node   = null
	var best_sq: float = INF
	for ln in get_tree().get_nodes_in_group("lava_nodes"):
		if not ln.has_capacity():
			continue
		var sq := (truck as Node2D).global_position.distance_squared_to((ln as Node2D).global_position)
		if sq < best_sq:
			best_sq = sq
			best    = ln
	if best != null:
		truck.assign_harvest(best)

# ── Build plan ────────────────────────────────────────────────────────────────────

func _update_build_plan() -> void:
	if _build_idx >= AI_BUILD_PLAN.size():
		return

	# Track the building we dispatched
	if _building_now != null:
		if not is_instance_valid(_building_now):
			# Destroyed before completion — skip to next slot
			_building_now = null
			_build_idx   += 1
		elif _building_now.get("is_built") == true:
			_building_now = null
			_build_idx   += 1
		else:
			return   # still under construction

	if _build_idx >= AI_BUILD_PLAN.size():
		return

	var slot := AI_BUILD_PLAN[_build_idx] as Dictionary
	var cost: float = slot["cost"]
	if _ai_energy < cost:
		return

	# Find an idle truck
	var idle_truck: Node = null
	for t in _trucks:
		if is_instance_valid(t) and t.is_idle():
			idle_truck = t
			break
	if idle_truck == null:
		return

	spend_energy(cost)

	var ab: Node2D = load("res://scripts/AIBuilding.gd").new()
	ab.position    = slot["pos"]
	ab.z_index     = 30
	get_parent().add_child(ab)
	ab.call("setup", slot["type"], self)

	idle_truck.assign_build(ab)
	_building_now = ab

# ── Combat ────────────────────────────────────────────────────────────────────────

func _spawn_garrison_unit() -> void:
	var pos: Vector2 = SPAWN_POSITIONS[_rng.randi() % SPAWN_POSITIONS.size()]
	pos += Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-20.0, 20.0))
	var eu: Node2D = load("res://scripts/EnemyUnit.gd").new()
	eu.position    = pos
	eu.z_index     = 50
	get_parent().add_child(eu)
	eu.set("move_target", GARRISON_RALLY)

func _launch_wave() -> void:
	var all_enemy := get_tree().get_nodes_in_group("enemy_units")
	# Exclude AI hover trucks — they don't attack
	all_enemy = all_enemy.filter(func(u): return u.get("is_ai_truck") != true)

	if all_enemy.is_empty():
		return

	all_enemy.sort_custom(func(a, b):
		var da := (a as Node2D).global_position.distance_squared_to(GARRISON_RALLY)
		var db := (b as Node2D).global_position.distance_squared_to(GARRISON_RALLY)
		return da < db
	)

	var wave_count := 0
	for i in all_enemy.size():
		if i < GARRISON_SIZE:
			all_enemy[i].set("move_target", GARRISON_RALLY)
		else:
			var target: Vector2
			if _player_discovered:
				target = _player_last_seen
			else:
				target = SEARCH_WAYPOINTS[_search_idx % SEARCH_WAYPOINTS.size()]
				_search_idx += 1
			all_enemy[i].set("move_target", target)
			wave_count += 1

	if wave_count < WAVE_MIN_SIZE:
		_wave_timer = minf(_WAVE_WAIT_BY_DIFF[DIFFICULTY], 12.0)

func grace_remaining() -> float:
	return maxf(_grace_timer, 0.0)

func _update_discovery() -> void:
	var player_units     := get_tree().get_nodes_in_group("units")
	var player_buildings := get_tree().get_nodes_in_group("buildings")
	for eu in get_tree().get_nodes_in_group("enemy_units"):
		var ep := (eu as Node2D).global_position
		for pu in player_units:
			if ep.distance_to((pu as Node2D).global_position) <= ENEMY_DETECT_RANGE:
				_player_discovered = true
				_player_last_seen  = (pu as Node2D).global_position
				return
		for pb in player_buildings:
			if pb.get("is_ghost") == true or pb.get("is_built") != true:
				continue
			if ep.distance_to((pb as Node2D).global_position) <= ENEMY_DETECT_RANGE:
				_player_discovered = true
				_player_last_seen  = (pb as Node2D).global_position
				return
