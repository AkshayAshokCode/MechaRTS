extends "res://scripts/Unit.gd"

# Assembled from part dicts; stats are computed from the equipped parts.
# Slots: torso, legs, arm_l, arm_r (null means empty).

var combot_parts: Dictionary = {}

func setup_from_draft(draft: Dictionary) -> void:
	for slot in draft:
		combot_parts[slot] = draft[slot]

	has_obstacle_avoidance = true
	add_to_group("combots")

	var base_hp  := 60.0
	var base_dmg := 0.0
	var spd_mult := 1.0

	for slot in combot_parts:
		var p = combot_parts[slot]
		if p == null:
			continue
		base_hp  += float((p as Dictionary).get("hp",  0))
		base_dmg += float((p as Dictionary).get("dmg", 0))
		spd_mult *= float((p as Dictionary).get("spd", 1.0))

	max_health      = base_hp
	health          = base_hp
	attack_damage   = base_dmg
	attack_range    = 160.0 if base_dmg > 0.0 else 0.0
	attack_cooldown = 1.8
	vision_range    = 210.0
	_speed          = SPEED * spd_mult

func _draw() -> void:
	var R := RADIUS

	# Torso color drives the overall look
	var torso_col := Color(0.40, 0.55, 0.80)
	var t = combot_parts.get("torso")
	if t != null:
		torso_col = (t as Dictionary).get("col", torso_col)

	# Selection ring
	if selected:
		draw_arc(Vector2.ZERO, R + 6.0, 0.0, TAU, 32,
			Color(torso_col.r, torso_col.g, torso_col.b, 0.72), 1.5)

	# Legs
	var leg_col := torso_col.darkened(0.45)
	var ld = combot_parts.get("legs")
	if ld != null:
		leg_col = (ld as Dictionary).get("col", leg_col)
	draw_rect(Rect2(-R * 0.55, R * 0.22, R * 1.10, R * 0.72), leg_col)

	# Torso body
	draw_rect(Rect2(-R * 0.78, -R * 0.32, R * 1.56, R * 0.72), torso_col)
	# Top highlight
	var hl := Color(minf(torso_col.r * 1.3, 1.0), minf(torso_col.g * 1.3, 1.0),
		minf(torso_col.b * 1.3, 1.0), 0.80)
	draw_rect(Rect2(-R * 0.72, -R * 0.32, R * 1.44, R * 0.22), hl)

	# Left arm
	var la = combot_parts.get("arm_l")
	if la != null:
		var ac: Color = (la as Dictionary).get("col", torso_col.darkened(0.30))
		draw_rect(Rect2(-R * 1.38, -R * 0.28, R * 0.55, R * 0.68), ac)

	# Right arm / weapon
	var ra = combot_parts.get("arm_r")
	if ra != null:
		var ac: Color = (ra as Dictionary).get("col", torso_col.darkened(0.30))
		draw_rect(Rect2(R * 0.82, -R * 0.28, R * 0.55, R * 0.68), ac)

	# Head
	draw_circle(Vector2(0.0, -R * 0.74), R * 0.32, torso_col.lightened(0.28))
	# Visor strip
	draw_rect(Rect2(-R * 0.18, -R * 0.86, R * 0.36, R * 0.11),
		Color(0.55, 0.90, 1.00, 0.90))

	_draw_health_bar()
