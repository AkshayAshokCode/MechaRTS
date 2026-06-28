extends Node2D

var _dir:       Vector2 = Vector2.RIGHT
var _damage:    float   = 10.0
var _faction:   int     = 0
var _speed:     float   = 480.0
var _max_range: float   = 400.0
var _traveled:  float   = 0.0

func setup(from: Vector2, to: Vector2, damage: float, faction: int) -> void:
	global_position = from
	_damage         = damage
	_faction        = faction
	_dir            = (to - from).normalized()
	_max_range      = (to - from).length() + 40.0

func _process(delta: float) -> void:
	var step := _dir * _speed * delta
	global_position += step
	_traveled       += step.length()

	var target_groups: Array = ["enemy_units", "enemy_buildings"] if _faction == 0 else ["units", "buildings"]
	for grp in target_groups:
		for node in get_tree().get_nodes_in_group(grp):
			if not is_instance_valid(node):
				continue
			if (node as Node2D).global_position.distance_to(global_position) < 18.0:
				if node.has_method("take_damage"):
					node.take_damage(_damage, global_position)
				queue_free()
				return

	if _traveled >= _max_range:
		queue_free()

func _draw() -> void:
	if _faction == 0:
		# Player — yellow-gold
		draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.95, 0.35))
		draw_line(Vector2.ZERO, -_dir * 12.0, Color(1.0, 0.60, 0.12, 0.58), 2.5)
	else:
		# Enemy — red-orange
		draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.20, 0.08))
		draw_line(Vector2.ZERO, -_dir * 12.0, Color(0.85, 0.12, 0.04, 0.58), 2.5)
