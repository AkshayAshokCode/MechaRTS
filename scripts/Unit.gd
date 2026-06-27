extends Node2D

const SPEED             := 120.0
const RADIUS            := 12.0
const SEPARATION_RADIUS := 52.0
const SEPARATION_FORCE  := 1.2
const AVOID_WEIGHT      := 2.0   # steering weight for obstacle avoidance

var vision_range: float = 200.0
var move_target: Vector2 = Vector2.ZERO
var selected: bool = false:
	set(v): selected = v; queue_redraw()

var health: float      = 100.0
var max_health: float  = 100.0
var attack_range: float    = 0.0
var attack_damage: float   = 0.0
var attack_cooldown: float = 1.5
var _attack_timer: float   = 0.0
var faction: int = 0  # 0 = player, 1 = enemy

# Subclasses that should not walk through buildings/lava set this to true.
# HoverTruck leaves it false so it can approach lava and buildings to dock.
var has_obstacle_avoidance: bool = false

func _ready() -> void:
	add_to_group("units")
	move_target = global_position
	queue_redraw()

func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	queue_redraw()
	if health <= 0.0:
		_on_death()

func _on_death() -> void:
	GameState.selected_units.erase(self)
	queue_free()

func _physics_process(delta: float) -> void:
	var prev := global_position

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
		var move_dir := to_target.normalized()
		if sep.length_squared() > 0.01:
			move_dir = (move_dir + sep * SEPARATION_FORCE).normalized()
		if has_obstacle_avoidance:
			var avoid := _compute_avoidance()
			if avoid.length_squared() > 0.01:
				move_dir = (move_dir + avoid * AVOID_WEIGHT).normalized()
			_move_with_slide(move_dir, delta)
		else:
			global_position += move_dir * SPEED * delta
	elif sep.length_squared() > 0.01:
		var push := global_position + sep.normalized() * SPEED * 0.25 * delta
		if not has_obstacle_avoidance or not _is_blocked(push):
			global_position = push

	var moved := global_position - prev
	if moved.length_squared() > 0.5:
		_update_facing(moved)

# Move in `dir`, sliding along obstacles when blocked head-on.
func _move_with_slide(dir: Vector2, delta: float) -> void:
	var step  := SPEED * delta
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
	var enemy_groups: Array = ["enemy_units", "enemy_buildings"] if faction == 0 else ["units"]
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
	var proj: Node2D = load("res://scripts/Projectile.gd").new()
	proj.setup(global_position, (target as Node2D).global_position, attack_damage, faction)
	get_parent().add_child(proj)

func _draw() -> void:
	var color := Color(0.2, 0.8, 0.3) if not selected else Color(0.4, 1.0, 0.5)
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_arc(Vector2.ZERO, RADIUS + 1.5, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.5), 1.5)
	if selected:
		draw_arc(Vector2.ZERO, RADIUS + 5.0, 0.0, TAU, 32, Color(0.4, 1.0, 0.5, 0.7), 1.5)
	_draw_health_bar()

func _draw_health_bar() -> void:
	if health >= max_health:
		return
	var bar_w := RADIUS * 2.5
	var bar_x := -bar_w * 0.5
	var bar_y := RADIUS + 5.0
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
