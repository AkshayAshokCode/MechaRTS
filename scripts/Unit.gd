extends Node2D

const SPEED             := 120.0
const RADIUS            := 12.0
const SEPARATION_RADIUS := 52.0
const SEPARATION_FORCE  := 1.2
const AVOID_WEIGHT      := 2.0   # steering weight for obstacle avoidance

const STATE_IDLE   := 0   # responds to nearby attack alerts; combat units auto-engage
const STATE_TASKED := 1   # busy on a job; ignores alerts unless directly hit
const STATE_GUARD  := 2   # unused reserved
const STATE_PATROL := 3   # moves back and forth between patrol_points; auto-attacks en route
const ALERT_RADIUS := 350.0

var unit_state:    int   = STATE_IDLE
var patrol_points: Array = []   # [Vector2 A, Vector2 B, ...]
var _patrol_idx:   int   = 0    # index of the next patrol point to travel toward
var _patrol_target: Node = null # enemy being pursued during patrol; null = follow waypoints
var vision_range: float = 200.0
var _speed: float = SPEED   # override in subclasses via setup
var stability: float = 0.0  # 0 = knocked easily, 1 = immovable; set by Combot from parts

var _nav_agent: NavigationAgent2D = null

# Setter keeps the nav agent target in sync whenever move_target changes.
var move_target: Vector2 = Vector2.ZERO:
	set(v):
		move_target = v
		if _nav_agent != null:
			_nav_agent.target_position = v
var selected: bool = false:
	set(v): selected = v; queue_redraw()

var health: float      = 100.0
var max_health: float  = 100.0
var attack_range: float    = 0.0
var attack_damage: float   = 0.0
var attack_cooldown: float = 1.5
var _attack_timer: float   = 0.0
var faction: int = 0  # 0 = player, 1 = enemy

var _hit_flash:   float = 0.0
var _order_flash: float = 0.0

# Subclasses that should not walk through buildings/lava set this to true.
# HoverTruck leaves it false so it can approach lava and buildings to dock.
var has_obstacle_avoidance: bool = false

func _ready() -> void:
	add_to_group("units")
	_nav_agent = NavigationAgent2D.new()
	_nav_agent.path_desired_distance   = 12.0
	_nav_agent.target_desired_distance = 28.0
	_nav_agent.avoidance_enabled       = false   # we handle avoidance ourselves
	add_child(_nav_agent)
	move_target = global_position   # setter syncs agent target
	queue_redraw()
	GameState.attack_at.connect(_on_alert_received)

func set_patrol(from: Vector2, to: Vector2) -> void:
	if has_method("stop_harvesting"): call("stop_harvesting")
	if has_method("stop_building"):   call("stop_building")
	if has_method("stop_healing"):    call("stop_healing")
	patrol_points = [from, to]
	_patrol_idx   = 1
	unit_state    = STATE_PATROL
	move_target   = to
	flash_order()

func cancel_patrol() -> void:
	if unit_state != STATE_PATROL:
		return
	patrol_points.clear()
	_patrol_target = null
	unit_state     = STATE_IDLE
	move_target    = global_position

func flash_order() -> void:
	_order_flash = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta / 0.20)
		queue_redraw()
	if _order_flash > 0.0:
		_order_flash = maxf(0.0, _order_flash - delta / 0.35)
		queue_redraw()

func take_damage(amount: float, hit_from: Vector2 = Vector2.ZERO) -> void:
	health = maxf(0.0, health - amount)
	# Knockback: hits >25 push the unit away, reduced by stability
	if amount > 25.0 and hit_from != Vector2.ZERO:
		var kb := (1.0 - clampf(stability, 0.0, 1.0)) * 28.0
		if kb > 1.0:
			global_position += (global_position - hit_from).normalized() * kb
	_hit_flash = 1.0
	queue_redraw()
	if faction == 0:
		GameState.attack_at.emit(global_position)
	if health <= 0.0:
		_on_death()

func _on_death() -> void:
	if get_parent() != null:
		var exp: Node2D = load("res://scripts/DeathExplosion.gd").new()
		exp.global_position = global_position
		exp.z_index = z_index + 5
		get_parent().add_child(exp)
	GameState.selected_units.erase(self)
	queue_free()

func _tick_patrol() -> void:
	if unit_state != STATE_PATROL or patrol_points.size() < 2:
		return

	# ── Combat intercept (only for units that can shoot) ─────────────────────
	if attack_range > 0.0:
		# Drop stale / fled targets
		if _patrol_target != null:
			if not is_instance_valid(_patrol_target) or \
					global_position.distance_to((_patrol_target as Node2D).global_position) > vision_range * 1.8:
				_patrol_target = null

		# Scan for a new target within vision range
		if _patrol_target == null:
			var enemy_grps: Array = ["enemy_units", "enemy_buildings"] if faction == 0 \
			                        else ["units", "buildings"]
			var best_d := vision_range
			for grp in enemy_grps:
				for node in get_tree().get_nodes_in_group(grp):
					if not is_instance_valid(node):
						continue
					var d := global_position.distance_to((node as Node2D).global_position)
					if d < best_d:
						best_d = d
						_patrol_target = node

		# Chase — hold at attack range so _tick_attack can fire
		if _patrol_target != null:
			var epos := (_patrol_target as Node2D).global_position
			var to_e := epos - global_position
			var stop := maxf(attack_range * 0.70, 40.0)
			move_target = epos - to_e.normalized() * stop if to_e.length() > stop \
			              else global_position
			return   # skip waypoint logic while engaging

	# ── Normal waypoint advancement ───────────────────────────────────────────
	var target: Vector2 = patrol_points[_patrol_idx]
	if global_position.distance_to(target) < 24.0:
		_patrol_idx = (_patrol_idx + 1) % patrol_points.size()
		move_target = patrol_points[_patrol_idx]

func _physics_process(delta: float) -> void:
	var prev := global_position

	_tick_patrol()

	if attack_range > 0.0:
		_tick_attack(delta)

	# Separation from nearby same-faction units
	var group := "units" if faction == 0 else "enemy_units"
	var sep := Vector2.ZERO
	for other in get_tree().get_nodes_in_group(group):
		if other == self:
			continue
		var diff := global_position - (other as Node2D).global_position
		var dist := diff.length()
		if dist > 0.001 and dist < SEPARATION_RADIUS:
			sep += diff.normalized() * (1.0 - dist / SEPARATION_RADIUS)

	var to_target := move_target - global_position
	if to_target.length_squared() > 4.0:
		# Use the nav agent's A* path when it has one, else fall back to direct
		var move_dir: Vector2
		if _nav_agent != null and not _nav_agent.is_navigation_finished():
			move_dir = global_position.direction_to(_nav_agent.get_next_path_position())
		else:
			move_dir = to_target.normalized()
		if sep.length_squared() > 0.01:
			move_dir = (move_dir + sep * SEPARATION_FORCE).normalized()
		if has_obstacle_avoidance:
			var avoid := _compute_avoidance()
			if avoid.length_squared() > 0.01:
				move_dir = (move_dir + avoid * AVOID_WEIGHT).normalized()
			_move_with_slide(move_dir, delta)
		else:
			global_position += move_dir * _speed * delta
	elif sep.length_squared() > 0.01:
		var push := global_position + sep.normalized() * _speed * 0.25 * delta
		if not has_obstacle_avoidance or not _is_blocked(push):
			global_position = push

	var moved := global_position - prev
	if moved.length_squared() > 0.5:
		_update_facing(moved)

# Move in `dir`, sliding along obstacles when blocked head-on.
func _move_with_slide(dir: Vector2, delta: float) -> void:
	var step  := _speed * delta
	var next  := global_position + dir * step
	if not _is_blocked(next):
		global_position = next
		return
	# Try sliding on each axis independently
	var nx := global_position + Vector2(dir.x, 0.0) * step
	var ny := global_position + Vector2(0.0, dir.y) * step
	if not _is_blocked(nx):
		global_position = nx
	elif not _is_blocked(ny):
		global_position = ny
	# else: completely cornered — stay put this frame

func _is_blocked(pos: Vector2) -> bool:
	for grp in ["buildings", "enemy_buildings"]:
		for b in get_tree().get_nodes_in_group(grp):
			if b.get("is_ghost") == true:
				continue
			var r: float = b.get_collision_radius() if b.has_method("get_collision_radius") else 55.0
			if pos.distance_to((b as Node2D).global_position) < r + RADIUS:
				return true
	for node in get_tree().get_nodes_in_group("lava_nodes"):
		if pos.distance_to((node as Node2D).global_position) < 36.0 + RADIUS:
			return true
	return false

func _compute_avoidance() -> Vector2:
	var avoid := Vector2.ZERO
	for grp in ["buildings", "enemy_buildings"]:
		for b in get_tree().get_nodes_in_group(grp):
			if b.get("is_ghost") == true:
				continue
			var bpos := (b as Node2D).global_position
			var r: float = b.get_collision_radius() if b.has_method("get_collision_radius") else 55.0
			var threshold := r + RADIUS + 20.0
			var diff := global_position - bpos
			var dist := diff.length()
			if dist < threshold and dist > 0.001:
				avoid += diff.normalized() * (1.0 - dist / threshold)
	for node in get_tree().get_nodes_in_group("lava_nodes"):
		var threshold := 36.0 + RADIUS + 20.0
		var diff := global_position - (node as Node2D).global_position
		var dist := diff.length()
		if dist < threshold and dist > 0.001:
			avoid += diff.normalized() * (1.0 - dist / threshold)
	return avoid

# Override in subclasses to match the unit's drawn front direction.
# Default: +X is front (matches any +X-facing sprite).
func _update_facing(moved: Vector2) -> void:
	rotation = moved.angle()

func _tick_attack(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	var enemy_groups: Array = ["enemy_units", "enemy_buildings"] if faction == 0 else ["units", "buildings"]
	var nearest: Node = null
	var nearest_dist := attack_range
	for grp in enemy_groups:
		for node in get_tree().get_nodes_in_group(grp):
			if not is_instance_valid(node):
				continue
			var d := (node as Node2D).global_position.distance_to(global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = node
	if nearest != null:
		_fire_at(nearest)
		_attack_timer = attack_cooldown

func _fire_at(target: Node) -> void:
	if get_parent() != null:
		var flash: Node2D = load("res://scripts/MuzzleFlash.gd").new()
		flash.global_position = global_position
		flash.z_index = z_index + 3
		get_parent().add_child(flash)
	var proj: Node2D = load("res://scripts/Projectile.gd").new()
	proj.setup(global_position, (target as Node2D).global_position, attack_damage, faction)
	get_parent().add_child(proj)

func _on_alert_received(attack_pos: Vector2) -> void:
	if unit_state == STATE_TASKED or unit_state == STATE_PATROL:
		return
	var dist := global_position.distance_to(attack_pos)
	# Ignore self-alerts (we ARE the unit being hit) and out-of-range alerts
	if dist < 10.0 or dist > ALERT_RADIUS:
		return
	# Non-combat units (HoverTruck) hold — only combat units rally
	if attack_range <= 0.0:
		return
	# Position the unit at firing range from the attack origin
	var stop_dist := maxf(attack_range * 0.65, 60.0)
	if dist <= stop_dist:
		return  # already within engagement range
	move_target = attack_pos - (attack_pos - global_position).normalized() * stop_dist

# Plan-oblique elevation: to appear H_screen px straight up, local offset = (0, -H/ISO_Y).
# Rotated by -rotation so it always points screen-up regardless of vehicle facing.
func _iso_up() -> Vector2:
	const H_SCREEN := RADIUS * 0.85
	const ISO_Y    := 0.55
	return Vector2(0.0, -H_SCREEN / ISO_Y).rotated(-rotation)

func _draw_shadow() -> void:
	const H_SCREEN := RADIUS * 0.85
	const ISO_Y    := 0.55
	var down := Vector2(0.0, H_SCREEN / ISO_Y).rotated(-rotation)
	draw_circle(down, RADIUS * 0.92, Color(0.0, 0.0, 0.0, 0.35))

func _draw() -> void:
	var u     := _iso_up()
	var color := Color(0.2, 0.8, 0.3) if not selected else Color(0.4, 1.0, 0.5)
	_draw_shadow()
	draw_circle(u, RADIUS, color)
	draw_arc(u, RADIUS + 1.5, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.5), 1.5)
	if selected:
		draw_arc(u, RADIUS + 5.0, 0.0, TAU, 32, Color(0.4, 1.0, 0.5, 0.7), 1.5)
	_draw_health_bar()

func _draw_health_bar() -> void:
	var u := _iso_up()
	# Order-received flash — teal expanding ring
	if _order_flash > 0.0:
		var t := 1.0 - _order_flash
		draw_arc(u, RADIUS + t * 14.0, 0.0, TAU, 24,
			Color(0.20, 0.90, 0.85, _order_flash * 0.70), 2.0)
	# Hit flash overlay
	if _hit_flash > 0.0:
		draw_circle(u, RADIUS * 2.2, Color(1.0, 0.12, 0.04, _hit_flash * 0.44))

	if health >= max_health:
		return
	var bar_w := RADIUS * 2.5
	var bar_x := -bar_w * 0.5 + u.x
	var bar_y := RADIUS + 5.0 + u.y
	var ratio := health / max_health
	draw_rect(Rect2(bar_x, bar_y, bar_w, 4.0), Color(0.1, 0.1, 0.1, 0.85))
	var fill_col: Color
	if ratio > 0.5:
		fill_col = Color(0.2, 1.0, 0.2)
	elif ratio > 0.25:
		fill_col = Color(1.0, 0.55, 0.0)
	else:
		fill_col = Color(1.0, 0.1, 0.1)
	draw_rect(Rect2(bar_x, bar_y, bar_w * ratio, 4.0), fill_col)
