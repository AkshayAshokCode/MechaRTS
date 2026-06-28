extends RefCounted

# All part definitions. Access via: load("res://scripts/PartCatalog.gd").ALL
# Part dict fields:
#   id        : String  — unique identifier
#   name      : String  — display label
#   slot      : String  — "torso" | "legs" | "arm"
#   hp        : float   — structural HP this part contributes (and limb HP pool)
#   dmg       : float   — damage per shot added to combot
#   spd       : float   — speed multiplier (multiplicative)
#   weight    : float   — increases total weight, reduces speed via weight penalty
#   stability : float   — adds to stability pool (0-1 range; higher = less knockback)
#   col       : Color   — visual tint

const ALL: Array = [
	# ── Torsos ────────────────────────────────────────────────────────────────
	{ "id": "basic_torso",  "name": "Basic Torso",  "slot": "torso", "hp":  50, "dmg": 0, "spd": 1.00, "weight": 15, "stability": 0.20, "col": Color(0.40, 0.55, 0.80) },
	{ "id": "armor_torso",  "name": "Armor Torso",  "slot": "torso", "hp": 100, "dmg": 0, "spd": 0.85, "weight": 28, "stability": 0.40, "col": Color(0.28, 0.40, 0.62) },
	{ "id": "light_torso",  "name": "Light Torso",  "slot": "torso", "hp":  30, "dmg": 0, "spd": 1.15, "weight":  8, "stability": 0.10, "col": Color(0.65, 0.72, 0.90) },

	# ── Legs ──────────────────────────────────────────────────────────────────
	{ "id": "basic_legs",   "name": "Basic Legs",   "slot": "legs",  "hp":  20, "dmg": 0, "spd": 1.00, "weight": 10, "stability": 0.10, "col": Color(0.40, 0.42, 0.65) },
	{ "id": "speed_legs",   "name": "Speed Legs",   "slot": "legs",  "hp":  10, "dmg": 0, "spd": 1.50, "weight":  7, "stability": 0.05, "col": Color(0.28, 0.70, 0.38) },
	{ "id": "heavy_legs",   "name": "Heavy Legs",   "slot": "legs",  "hp":  40, "dmg": 0, "spd": 0.75, "weight": 20, "stability": 0.30, "col": Color(0.30, 0.35, 0.58) },

	# ── Arms ──────────────────────────────────────────────────────────────────
	{ "id": "plasma_cannon",  "name": "Plasma Cannon",  "slot": "arm", "hp":  0, "dmg": 30, "spd": 1.00, "weight": 12, "stability": 0.00, "col": Color(0.82, 0.20, 0.20) },
	{ "id": "energy_blaster", "name": "Energy Blaster", "slot": "arm", "hp":  0, "dmg": 18, "spd": 1.00, "weight":  6, "stability": 0.00, "col": Color(0.52, 0.20, 0.82) },
	{ "id": "rocket_arm",     "name": "Rocket Arm",     "slot": "arm", "hp":  0, "dmg": 45, "spd": 0.90, "weight": 18, "stability": 0.00, "col": Color(1.00, 0.45, 0.12) },
	{ "id": "shield_arm",     "name": "Shield Arm",     "slot": "arm", "hp": 15, "dmg":  0, "spd": 1.00, "weight": 14, "stability": 0.35, "col": Color(0.35, 0.65, 0.95) },
	{ "id": "micro_cannon",   "name": "Micro Cannon",   "slot": "arm", "hp":  0, "dmg": 10, "spd": 1.00, "weight":  4, "stability": 0.00, "col": Color(0.90, 0.80, 0.20) },

	# ── Mil-Agro faction — industrial, heavy, high-damage ──────────────────────
	{ "id": "siege_torso",    "name": "Siege Torso",    "slot": "torso", "hp": 140, "dmg": 0, "spd": 0.70, "weight": 40, "stability": 0.60, "col": Color(0.62, 0.28, 0.10) },
	{ "id": "strength_legs",  "name": "Strength Legs",  "slot": "legs",  "hp":  55, "dmg": 0, "spd": 0.80, "weight": 25, "stability": 0.45, "col": Color(0.52, 0.26, 0.10) },
	{ "id": "gatling_arm",    "name": "Gatling Arm",    "slot": "arm",   "hp":   0, "dmg": 22, "spd": 1.00, "weight":  8, "stability": 0.00, "col": Color(0.75, 0.38, 0.08) },
	{ "id": "heavy_shield",   "name": "Heavy Shield",   "slot": "arm",   "hp":  28, "dmg":  0, "spd": 0.95, "weight": 20, "stability": 0.50, "col": Color(0.52, 0.32, 0.16) },

	# ── Neuropa faction — organic, fast, utility-focused ────────────────────────
	{ "id": "recon_torso",    "name": "Recon Torso",    "slot": "torso", "hp":  35, "dmg": 0, "spd": 1.20, "weight":  6, "stability": 0.15, "col": Color(0.48, 0.18, 0.68) },
	{ "id": "sonar_legs",     "name": "Sonar Legs",     "slot": "legs",  "hp":  18, "dmg": 0, "spd": 1.10, "weight":  9, "stability": 0.12, "col": Color(0.20, 0.56, 0.62) },
	{ "id": "energy_shield",  "name": "Energy Shield",  "slot": "arm",   "hp":  22, "dmg":  5, "spd": 1.00, "weight": 10, "stability": 0.28, "col": Color(0.32, 0.75, 0.85) },
	{ "id": "cloak_arm",      "name": "Cloak Arm",      "slot": "arm",   "hp":   8, "dmg": 14, "spd": 1.05, "weight":  5, "stability": 0.20, "col": Color(0.58, 0.22, 0.78) },
]
