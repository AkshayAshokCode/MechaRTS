extends Node

# ── Map constants ─────────────────────────────────────────────────────────────
const GARRISON_RALLY := Vector2(5250, 900)
const PLAYER_HQ_AREA := Vector2(700,  4200)

# Mid-map lava strip — contested expansion territory
const CONTESTED_LAVA: Array = [
	Vector2(4500, 1700),
	Vector2(3200, 2400),
	Vector2(1900, 3100),
]

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

const SPAWN_POSITIONS: Array = [
	Vector2(5350, 860),
	Vector2(5450, 820),
	Vector2(5250, 900),
	Vector2(5480, 960),
]

# ── Difficulty ────────────────────────────────────────────────────────────────
const DIFFICULTY               := 1
const _WAVE_WAIT_BY_DIFF: Array = [50.0, 30.0, 18.0]
const _MAX_UNITS_BY_DIFF: Array = [8,    14,   20  ]
const _GRACE_BY_DIFF:     Array = [180.0, 120.0, 60.0]

const WAVE_MIN_SIZE := 4

# ── Economy ───────────────────────────────────────────────────────────────────
const AI_ENERGY_START   := 500.0
const AI_ENERGY_CAP     := 3000.0
const AI_MANPOWER_START := 12
const AI_MANPOWER_CAP   := 35
const AI_MANPOWER_REGEN := 1.0 / 20.0

# ── Strategy brain ────────────────────────────────────────────────────────────
# Evaluated every EVAL_INTERVAL seconds; influences build order, wave size, targets.
enum Strategy { BLITZ, RUSH, ECONOMY, DEFEND }

# 7 physical build slots in the AI base (positions never change)
const BUILD_POSITIONS: Array = [
	Vector2(5150, 750),
	Vector2(5455, 755),
	Vector2(5080, 470),
	Vector2(4950, 900),
	Vector2(5310, 985),
	Vector2(5570, 530),
	Vector2(4780, 760),
]

const BUILD_COSTS: Dictionary = {
	"vehicle_factory": 200.0,
	"combot_bay":      250.0,
	"defense_relay":   150.0,
}

# Which type to build at each slot per strategy
const STRATEGY_BUILD_ORDERS: Dictionary = {
	# BLITZ: two factories first → flood units while techin up with bays
	Strategy.BLITZ:   ["vehicle_factory", "vehicle_factory", "combot_bay",      "vehicle_factory", "combot_bay",      "defense_relay",   "defense_relay"],
	# RUSH: combot_bay first → strongest unit pressure before player expands
	Strategy.RUSH:    ["combot_bay",      "vehicle_factory", "defense_relay",   "combot_bay",      "vehicle_factory", "defense_relay",   "vehicle_factory"],
	# ECONOMY: factories for income, relays for midfield holding
	Strategy.ECONOMY: ["vehicle_factory", "defense_relay",   "vehicle_factory", "vehicle_factory", "combot_bay",      "defense_relay",   "combot_bay"],
	# DEFEND: relays first → stall player; counter when safe
	Strategy.DEFEND:  ["defense_relay",   "defense_relay",   "vehicle_factory", "defense_relay",   "combot_bay",      "vehicle_factory", "combot_bay"],
}

# Units held at garrison per strategy (rest are sent on waves)
const STRATEGY_HOLD: Dictionary = {
	Strategy.BLITZ:   2,
	Strategy.RUSH:    1,
	Strategy.ECONOMY: 4,
	Strategy.DEFEND:  6,
}

const EVAL_INTERVAL := 25.0

# ── State ─────────────────────────────────────────────────────────────────────
var _rng          := RandomNumberGenerator.new()
var _grace_timer  : float = 0.0
var _wave_timer   : float = 0.0
var _max_units    : int   = 14
var _game_time    : float = 0.0

var _ai_energy    : float = AI_ENERGY_START
var _ai_manpower  : int   = AI_MANPOWER_START
var _ai_mp_accum  : float = 0.0
var _trucks       : Array = []
var _build_idx    : int   = 0
var _building_now : Node  = null

var _strategy     : int   = Strategy.BLITZ
var _eval_timer   : float = 5.0   # first evaluation at 5 s

var _garrison_rally    : Vector2 = GARRISON_RALLY
var _player_discovered : bool    = false
var _player_last_seen  : Vector2 = PLAYER_HQ_AREA
var _search_idx        : int     = 0
var _vision_timer      : float   = 0.0
var _spotted_buildings : Array   = []   # Vector2 positions of known player buildings

func _ready() -> void:
	add_to_group("ai_player")
	_rng.randomize()
	_grace_timer = _GRACE_BY_DIFF[DIFFICULTY]
	_wave_timer  = _WAVE_WAIT_BY_DIFF[DIFFICULTY]
	_max_units   = _MAX_UNITS_BY_DIFF[DIFFICULTY]
	for _i in 3:
		_spawn_garrison_unit()

# ── Economy API ───────────────────────────────────────────────────────────────

func add_energy(amount: float) -> void:
	_ai_energy = minf(_ai_energy + amount, AI_ENERGY_CAP)

func spend_energy(amount: float) -> bool:
	if _ai_energy < amount:
		return false
	_ai_energy -= amount
	return true

func spend_ai_manpower(amount: int) -> bool:
	if _ai_manpower < amount:
		return false
	_ai_manpower -= amount
	return true

func return_manpower(amount: int) -> void:
	_ai_manpower = mini(_ai_manpower + amount, AI_MANPOWER_CAP)

func register_truck(truck: Node) -> void:
	if truck not in _trucks:
		_trucks.append(truck)
	_assign_harvest(truck)

func request_harvest(truck: Node) -> void:
	_assign_harvest(truck)

# ── Main loop ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if GameState.game_ended:
		return

	_game_time   += delta
	_ai_mp_accum += delta * AI_MANPOWER_REGEN
	if _ai_mp_accum >= 1.0:
		_ai_mp_accum -= 1.0
		_ai_manpower  = mini(_ai_manpower + 1, AI_MANPOWER_CAP)

	_eval_timer -= delta
	if _eval_timer <= 0.0:
		_eval_timer = EVAL_INTERVAL
		_strategy   = _evaluate_strategy()

	_update_build_plan()
	_update_trucks()

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

# ── Strategy evaluation ───────────────────────────────────────────────────────

func _evaluate_strategy() -> int:
	var p_units := get_tree().get_nodes_in_group("units").size()

	var p_buildings := 0
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.get("is_ghost") != true and b.get("is_built") == true:
			p_buildings += 1

	var ai_combat := 0
	for u in get_tree().get_nodes_in_group("enemy_units"):
		if u.get("is_ai_truck") != true:
			ai_combat += 1

	# Is the player pushing into the contested midfield lava strip?
	var player_contesting := false
	for cp in CONTESTED_LAVA:
		for pu in get_tree().get_nodes_in_group("units"):
			if (pu as Node2D).global_position.distance_to(cp) < 350.0:
				player_contesting = true
				break
		if player_contesting:
			break

	# DEFEND: player army is significantly larger — turtle and stall
	if p_units > ai_combat * 1.4 and p_units >= 5:
		return Strategy.DEFEND

	# RUSH: early game, player hasn't expanded yet — strike before they can
	if _game_time < 90.0 and p_buildings <= 2:
		return Strategy.RUSH

	# ECONOMY: player pushing midfield — contest lava and out-resource them
	if player_contesting:
		return Strategy.ECONOMY

	# BLITZ: default — flood with units and overwhelm
	return Strategy.BLITZ

# ── Truck management ──────────────────────────────────────────────────────────

func _update_trucks() -> void:
	_trucks = _trucks.filter(func(t): return is_instance_valid(t))
	for t in _trucks:
		if t.is_idle():
			_assign_harvest(t)

func _assign_harvest(truck: Node) -> void:
	# ECONOMY: contest midfield lava when we have enough defenders at home
	if _strategy == Strategy.ECONOMY:
		var ai_count := 0
		for u in get_tree().get_nodes_in_group("enemy_units"):
			if u.get("is_ai_truck") != true:
				ai_count += 1
		if ai_count >= 6:
			var cl := _nearest_contested_lava(truck)
			if cl != null:
				truck.assign_harvest(cl)
				return

	# Default: nearest AI-side lava with capacity
	var best   : Node  = null
	var best_sq: float = INF
	for ln in get_tree().get_nodes_in_group("lava_nodes"):
		if not ln.has_capacity():
			continue
		var sq := (truck as Node2D).global_position.distance_squared_to(
				(ln as Node2D).global_position)
		if sq < best_sq:
			best_sq = sq
			best    = ln
	if best != null:
		truck.assign_harvest(best)

func _nearest_contested_lava(truck: Node) -> Node:
	var best   : Node  = null
	var best_sq: float = INF
	for ln in get_tree().get_nodes_in_group("lava_nodes"):
		if ln.get("_depleted") == true or not ln.has_capacity():
			continue
		var lpos := (ln as Node2D).global_position
		for cp in CONTESTED_LAVA:
			if lpos.distance_to(cp) < 50.0:
				var sq := (truck as Node2D).global_position.distance_squared_to(lpos)
				if sq < best_sq:
					best_sq = sq
					best    = ln
				break
	return best

# ── Build plan ────────────────────────────────────────────────────────────────

func _update_build_plan() -> void:
	if _build_idx >= BUILD_POSITIONS.size():
		return

	if _building_now != null:
		if not is_instance_valid(_building_now):
			_building_now = null
			_build_idx   += 1
		elif _building_now.get("is_built") == true:
			_building_now = null
			_build_idx   += 1
		else:
			return   # still under construction

	if _build_idx >= BUILD_POSITIONS.size():
		return

	var order: Array = STRATEGY_BUILD_ORDERS[_strategy]
	var type : String = order[_build_idx]
	var cost : float  = BUILD_COSTS[type]
	if _ai_energy < cost:
		return

	# Prefer idle truck; fall back to stealing a harvesting truck (keep ≥1 harvesting)
	var builder: Node = null
	for t in _trucks:
		if is_instance_valid(t) and t.is_idle():
			builder = t
			break
	if builder == null:
		var available: Array = []
		for t in _trucks:
			if is_instance_valid(t) and t.has_method("is_available_for_build") \
					and (t as Object).call("is_available_for_build"):
				available.append(t)
		if available.size() > 1:
			builder = available[-1]
	if builder == null:
		return

	spend_energy(cost)

	var ab: Node2D = load("res://scripts/AIBuilding.gd").new()
	ab.position    = BUILD_POSITIONS[_build_idx]
	ab.z_index     = 30
	get_parent().add_child(ab)
	ab.call("setup", type, self)

	builder.assign_build(ab)
	_building_now = ab

# ── Combat ────────────────────────────────────────────────────────────────────

func _spawn_garrison_unit() -> void:
	var pos: Vector2 = SPAWN_POSITIONS[_rng.randi() % SPAWN_POSITIONS.size()]
	pos += Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-20.0, 20.0))
	var eu: Node2D = load("res://scripts/EnemyUnit.gd").new()
	eu.position    = pos
	eu.z_index     = 50
	get_parent().add_child(eu)
	eu.set("move_target", GARRISON_RALLY)

func _pick_wave_target() -> Vector2:
	match _strategy:
		Strategy.RUSH:
			# Beeline straight for the player — even before discovery
			return _player_last_seen

		Strategy.BLITZ:
			# Rotate through spotted player buildings to destroy infrastructure
			if _spotted_buildings.size() > 0:
				return _spotted_buildings[_rng.randi() % _spotted_buildings.size()]
			return _player_last_seen

		Strategy.ECONOMY:
			# Raid the contested lava nearest to the player's last position
			# — disrupts their expansion push
			var best_cp  := _player_last_seen
			var best_sq  := INF
			for cp in CONTESTED_LAVA:
				var sq := (cp as Vector2).distance_squared_to(_player_last_seen)
				if sq < best_sq:
					best_sq = sq
					best_cp = cp
			return best_cp

		Strategy.DEFEND:
			# Counter-attack only when we've actually spotted the threat
			return _player_last_seen

	return _player_last_seen

func _launch_wave() -> void:
	var all_enemy := get_tree().get_nodes_in_group("enemy_units")
	all_enemy = all_enemy.filter(func(u): return u.get("is_ai_truck") != true)

	if all_enemy.is_empty():
		return

	# Sort closest-to-garrison first — rested units form the vanguard
	all_enemy.sort_custom(func(a, b):
		var da := (a as Node2D).global_position.distance_squared_to(GARRISON_RALLY)
		var db := (b as Node2D).global_position.distance_squared_to(GARRISON_RALLY)
		return da < db
	)

	# DEFEND: only counter-attack when we outnumber the player 1.5:1
	if _strategy == Strategy.DEFEND:
		var ai_count := all_enemy.size()
		var p_count  := get_tree().get_nodes_in_group("units").size()
		if ai_count < p_count * 1.5:
			for u in all_enemy:
				u.set("move_target", GARRISON_RALLY)
			_wave_timer = minf(_WAVE_WAIT_BY_DIFF[DIFFICULTY], 15.0)
			return

	var hold_size  : int     = STRATEGY_HOLD.get(_strategy, 3)
	var target     : Vector2 = _pick_wave_target()
	var wave_count : int     = 0

	for i in all_enemy.size():
		if i < hold_size:
			all_enemy[i].set("move_target", GARRISON_RALLY)
		else:
			# Slight scatter so units don't path-stack on the same tile
			var sc := Vector2(_rng.randf_range(-50.0, 50.0), _rng.randf_range(-50.0, 50.0))
			all_enemy[i].set("move_target", target + sc)
			wave_count += 1

	if wave_count < WAVE_MIN_SIZE:
		_wave_timer = minf(_WAVE_WAIT_BY_DIFF[DIFFICULTY], 12.0)

func grace_remaining() -> float:
	return maxf(_grace_timer, 0.0)

func _update_discovery() -> void:
	for eu in get_tree().get_nodes_in_group("enemy_units"):
		var ep := (eu as Node2D).global_position
		for pu in get_tree().get_nodes_in_group("units"):
			if ep.distance_to((pu as Node2D).global_position) <= ENEMY_DETECT_RANGE:
				_player_discovered = true
				_player_last_seen  = (pu as Node2D).global_position
				return
		for pb in get_tree().get_nodes_in_group("buildings"):
			if pb.get("is_ghost") == true or pb.get("is_built") != true:
				continue
			var bp := (pb as Node2D).global_position
			if ep.distance_to(bp) <= ENEMY_DETECT_RANGE:
				_player_discovered = true
				_player_last_seen  = bp
				if bp not in _spotted_buildings:
					_spotted_buildings.append(bp)
				return
