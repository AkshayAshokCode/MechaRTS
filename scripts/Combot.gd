extends "res://scripts/Unit.gd"

# Base structural HP for each limb slot (before part HP bonus is added).
const BASE_LIMB_HP: Dictionary = { "torso": 80.0, "legs": 50.0, "arm_l": 40.0, "arm_r": 40.0 }

# Limb hit weights for random damage distribution (must sum to 1.0).
const HIT_WEIGHTS: Array = [
	["torso", 0.40],
	["legs",  0.25],
	["arm_l", 0.175],
	["arm_r", 0.175],
]

# Weight divisor for speed penalty: speed *= 60 / (60 + total_weight)
const WEIGHT_BASE := 60.0

var combot_parts: Dictionary = {}    # slot → part dict (null = empty/amputated)
var limb_hp:      Dictionary = {}    # slot → current structural HP

func setup_from_draft(draft: Dictionary) -> void:
	for slot in draft:
		combot_parts[slot] = draft[slot]

	has_obstacle_avoidance = true
	add_to_group("combots")

	_init_limb_hp()
	_recalc_stats()
	health = max_health

# ── Stat calculation ───────────────────────────────────────────────────────────

func _recalc_stats() -> void:
	var base_hp    := 60.0
	var total_dmg  := 0.0
	var spd_mult   := 1.0
	var total_wt   := 0.0
	var total_stab := 0.0

	for slot in combot_parts:
		var p = combot_parts[slot]
		if p == null:
			continue
		base_hp    += float((p as Dictionary).get("hp",        0))
		total_dmg  += float((p as Dictionary).get("dmg",       0))
		spd_mult   *= float((p as Dictionary).get("spd",     1.0))
		total_wt   += float((p as Dictionary).get("weight",    0))
		total_stab += float((p as Dictionary).get("stability", 0))

	max_health    = base_hp
	attack_damage = total_dmg
	attack_range  = 160.0 if total_dmg > 0.0 else 0.0
	attack_cooldown = 1.8
	vision_range  = 210.0
	stability     = clampf(total_stab, 0.0, 1.0)

	if combot_parts.get("legs") != null:
		_speed = SPEED * spd_mult * (WEIGHT_BASE / (WEIGHT_BASE + total_wt))
	else:
		_speed = 0.0   # legs amputated

func _init_limb_hp() -> void:
	for slot in BASE_LIMB_HP:
		var p = combot_parts.get(slot)
		var bonus := float((p as Dictionary).get("hp", 0)) if p != null else 0.0
		limb_hp[slot] = BASE_LIMB_HP[slot] + bonus

# ── Damage + amputation ────────────────────────────────────────────────────────

func take_damage(amount: float, hit_from: Vector2 = Vector2.ZERO) -> void:
	# Distribute damage to a random limb (weighted by exposure)
	var slot := _pick_hit_limb()
	if slot != "":
		limb_hp[slot] = maxf(0.0, limb_hp[slot] - amount)
		if limb_hp[slot] <= 0.0:
			_amputate(slot)
			if not is_instance_valid(self):
				return

	# Also apply to total HP (normal death path)
	super.take_damage(amount, hit_from)

func _pick_hit_limb() -> String:
	# Build list of available limbs
	var available: Array = []
	var total_w := 0.0
	for pair in HIT_WEIGHTS:
		var slot: String = pair[0]
		var w: float     = pair[1]
		if limb_hp.get(slot, 0.0) > 0.0:
			available.append([slot, w])
			total_w += w
	if available.is_empty():
		return ""
	# Weighted random pick
	var roll := randf() * total_w
	var acc  := 0.0
	for pair in available:
		acc += pair[1]
		if roll <= acc:
			return pair[0]
	return available[-1][0]

func _amputate(slot: String) -> void:
	var p = combot_parts.get(slot)
	if p == null:
		return

	# Drop the part as a pickup in the world
	if get_parent() != null:
		var pickup: Node2D = load("res://scripts/PartPickup.gd").new()
		var scatter := Vector2(randf_range(-24.0, 24.0), randf_range(-24.0, 24.0))
		pickup.setup(p as Dictionary, global_position + scatter)
		get_parent().add_child(pickup)

	combot_parts[slot] = null
	limb_hp[slot]      = 0.0

	if slot == "torso":
		_on_death()
		return

	_recalc_stats()
	queue_redraw()

# ── Visual ─────────────────────────────────────────────────────────────────────

func _draw() -> void:
	var R := RADIUS

	var torso_col := Color(0.40, 0.55, 0.80)
	var t = combot_parts.get("torso")
	if t != null:
		torso_col = (t as Dictionary).get("col", torso_col)

	if selected:
		draw_arc(Vector2.ZERO, R + 6.0, 0.0, TAU, 32,
			Color(torso_col.r, torso_col.g, torso_col.b, 0.72), 1.5)

	# Legs (omit if amputated)
	var ld = combot_parts.get("legs")
	if ld != null:
		var leg_col: Color = (ld as Dictionary).get("col", torso_col.darkened(0.45))
		draw_rect(Rect2(-R * 0.55, R * 0.22, R * 1.10, R * 0.72), leg_col)

	# Torso body
	draw_rect(Rect2(-R * 0.78, -R * 0.32, R * 1.56, R * 0.72), torso_col)
	var hl := Color(minf(torso_col.r * 1.3, 1.0), minf(torso_col.g * 1.3, 1.0),
		minf(torso_col.b * 1.3, 1.0), 0.80)
	draw_rect(Rect2(-R * 0.72, -R * 0.32, R * 1.44, R * 0.22), hl)

	# Left arm (omit if amputated)
	var la = combot_parts.get("arm_l")
	if la != null:
		var ac: Color = (la as Dictionary).get("col", torso_col.darkened(0.30))
		draw_rect(Rect2(-R * 1.38, -R * 0.28, R * 0.55, R * 0.68), ac)

	# Right arm (omit if amputated)
	var ra = combot_parts.get("arm_r")
	if ra != null:
		var ac: Color = (ra as Dictionary).get("col", torso_col.darkened(0.30))
		draw_rect(Rect2(R * 0.82, -R * 0.28, R * 0.55, R * 0.68), ac)

	# Head
	draw_circle(Vector2(0.0, -R * 0.74), R * 0.32, torso_col.lightened(0.28))
	draw_rect(Rect2(-R * 0.18, -R * 0.86, R * 0.36, R * 0.11),
		Color(0.55, 0.90, 1.00, 0.90))

	_draw_health_bar()
