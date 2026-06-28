extends Node2D

const SPEED            := 140.0
const RADIUS           := 12.0
const HARVEST_DIST     := 95.0
const HARVEST_APPROACH := 72.0
const BUILD_DOCK_DIST  := 65.0

var is_ai_truck:  bool  = true   # flag so _launch_wave skips trucks
var vision_range: float = 0.0    # trucks don't reveal player fog

var health:     float = 80.0
var max_health: float = 80.0

var _harvest_target: Node = null
var _harvesting:     bool = false

var _build_target: Node = null
var _constructing: bool = false

var _move_target: Vector2 = Vector2.ZERO
var _pulse:       float   = 0.0

var ai_player: Node = null

func _ready() -> void:
	add_to_group("enemy_units")
	_move_target = global_position
	call_deferred("_register_with_ai")

func _register_with_ai() -> void:
	for ai in get_tree().get_nodes_in_group("ai_player"):
		(ai as Object).call("register_truck", self)
		break

func is_idle() -> bool:
	return not _harvesting and not _constructing and _harvest_target == null and _build_target == null

func take_damage(amount: float, _from: Vector2 = Vector2.ZERO) -> void:
	health = maxf(0.0, health - amount)
	queue_redraw()
	if health <= 0.0:
		if _harvest_target != null and is_instance_valid(_harvest_target):
			_harvest_target.release_harvester(self)
		queue_free()

func assign_harvest(lava_node: Node) -> void:
	_stop_build()
	if _harvest_target != null and is_instance_valid(_harvest_target):
		_harvest_target.release_harvester(self)
	_harvest_target = lava_node
	_harvesting     = false
	_move_target    = _approach_pos((lava_node as Node2D).global_position, HARVEST_APPROACH)

func assign_build(building: Node) -> void:
	if _harvest_target != null and is_instance_valid(_harvest_target):
		_harvest_target.release_harvester(self)
	_harvest_target = null
	_harvesting     = false
	_build_target   = building
	_constructing   = false
	_move_target    = _approach_pos((building as Node2D).global_position, BUILD_DOCK_DIST)

func _stop_build() -> void:
	_build_target = null
	_constructing = false

func _approach_pos(target: Vector2, dist: float) -> Vector2:
	var to := target - global_position
	if to.length() <= dist:
		return global_position
	return target - to.normalized() * dist

func _physics_process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 2.0, TAU)
	queue_redraw()

	if _harvesting:
		if not is_instance_valid(_harvest_target):
			_harvest_target = null
			_harvesting     = false
		else:
			if ai_player != null and is_instance_valid(ai_player):
				ai_player.add_energy(_harvest_target.harvest_rate * delta)
		return

	if _constructing:
		if not is_instance_valid(_build_target) or _build_target.get("is_built") == true:
			_build_target = null
			_constructing = false
			if ai_player != null and is_instance_valid(ai_player):
				ai_player.request_harvest(self)
		else:
			if ai_player != null and is_instance_valid(ai_player):
				var rate: float = _build_target.get("build_cost") / _build_target.get("build_time")
				if ai_player.spend_energy(rate * delta):
					if _build_target.has_method("advance_build"):
						_build_target.advance_build(delta)
		return

	if _harvest_target != null:
		if not is_instance_valid(_harvest_target):
			_harvest_target = null
		else:
			var dist := global_position.distance_to((_harvest_target as Node2D).global_position)
			if dist <= HARVEST_DIST:
				if _harvest_target.assign_harvester(self):
					_harvesting  = true
					_move_target = global_position
					return
				else:
					_harvest_target = null
					if ai_player != null and is_instance_valid(ai_player):
						ai_player.request_harvest(self)

	if _build_target != null:
		if not is_instance_valid(_build_target):
			_build_target = null
		else:
			var dist := global_position.distance_to((_build_target as Node2D).global_position)
			if dist <= BUILD_DOCK_DIST:
				_constructing = true
				_move_target  = global_position
				return

	var d := global_position.distance_to(_move_target)
	if d > 2.0:
		var dir := (_move_target - global_position).normalized()
		global_position += dir * SPEED * delta
		rotation         = dir.angle() + PI / 2.0

func _draw() -> void:
	var col := Color(0.85, 0.30, 0.30)
	if _constructing:
		col = Color(0.95, 0.80, 0.25)
	elif _harvesting:
		col = Color(1.00, 0.55, 0.15)

	draw_rect(Rect2(-RADIUS, -RADIUS * 0.55, RADIUS * 2.0, RADIUS * 1.1), col)
	draw_rect(Rect2(-RADIUS * 0.5, -RADIUS, RADIUS, RADIUS * 0.55), col.darkened(0.25))
	draw_arc(Vector2.ZERO, RADIUS + 2.0, 0.0, TAU, 24, Color(1.0, 0.55, 0.55, 0.35), 1.0)

	if _harvesting:
		draw_arc(Vector2.ZERO, RADIUS + 9.0, 0.0, TAU, 32, Color(1.0, 0.65, 0.10, 0.60), 2.0)
	elif _constructing:
		draw_arc(Vector2.ZERO, RADIUS + 9.0, 0.0, TAU, 32, Color(0.90, 0.90, 0.20, 0.60), 2.0)

	if health < max_health:
		var ratio := health / max_health
		draw_rect(Rect2(-RADIUS, RADIUS + 3.0, RADIUS * 2.0,         4.0), Color(0.08, 0.08, 0.08, 0.85))
		draw_rect(Rect2(-RADIUS, RADIUS + 3.0, RADIUS * 2.0 * ratio, 4.0), Color(1.0, 0.2, 0.1))
