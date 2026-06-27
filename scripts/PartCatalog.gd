extends RefCounted

# All part definitions. Access via: load("res://scripts/PartCatalog.gd").ALL
# Part dict fields:
#   id   : String  — unique identifier
#   name : String  — display label
#   slot : String  — "torso" | "legs" | "arm"
#   hp   : float   — health added to the combot
#   dmg  : float   — damage per shot added
#   spd  : float   — speed multiplier (multiplicative with other parts)
#   col  : Color   — visual tint for this part

const ALL: Array = [
	{ "id": "basic_torso",    "name": "Basic Torso",    "slot": "torso", "hp":  50, "dmg":  0, "spd": 1.00, "col": Color(0.40, 0.55, 0.80) },
	{ "id": "armor_torso",    "name": "Armor Torso",    "slot": "torso", "hp": 100, "dmg":  0, "spd": 0.85, "col": Color(0.28, 0.40, 0.62) },
	{ "id": "basic_legs",     "name": "Basic Legs",     "slot": "legs",  "hp":  20, "dmg":  0, "spd": 1.00, "col": Color(0.40, 0.42, 0.65) },
	{ "id": "speed_legs",     "name": "Speed Legs",     "slot": "legs",  "hp":  10, "dmg":  0, "spd": 1.50, "col": Color(0.28, 0.70, 0.38) },
	{ "id": "plasma_cannon",  "name": "Plasma Cannon",  "slot": "arm",   "hp":   0, "dmg": 30, "spd": 1.00, "col": Color(0.82, 0.20, 0.20) },
	{ "id": "energy_blaster", "name": "Energy Blaster", "slot": "arm",   "hp":   0, "dmg": 18, "spd": 1.00, "col": Color(0.52, 0.20, 0.82) },
]
