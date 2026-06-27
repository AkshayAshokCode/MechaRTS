extends Node2D

const MAP_SIZE := Vector2(6400.0, 4800.0)

const LAVA_POSITIONS: Array = [
	Vector2(800,  700),  Vector2(5600,  700),
	Vector2(900,  2400), Vector2(5500, 2400),
	Vector2(800,  4100), Vector2(5600, 4100),
	Vector2(3200, 2400),
]

# Enemy base layout — upper-right quadrant
const ENEMY_BUILDINGS: Array = [
	{ "pos": Vector2(5300, 580), "size": Vector2(100, 80), "color": Color(0.72, 0.15, 0.15), "label": "Command Post", "hp": 600.0 },
	{ "pos": Vector2(5100, 720), "size": Vector2( 80, 60), "color": Color(0.65, 0.18, 0.18), "label": "Power Plant",  "hp": 350.0 },
	{ "pos": Vector2(5450, 740), "size": Vector2( 90, 70), "color": Color(0.68, 0.16, 0.16), "label": "Barracks",     "hp": 400.0 },
]

const ENEMY_UNIT_POSITIONS: Array = [
	Vector2(5200, 850),
	Vector2(5350, 900),
	Vector2(5500, 860),
	Vector2(5300, 980),
]

func _ready() -> void:
	var world := Node2D.new()
	world.name = "WorldRoot"
	add_child(world)

	var bg := ColorRect.new()
	bg.color = Color(0.14, 0.11, 0.07)
	bg.size = MAP_SIZE
	world.add_child(bg)

	# Lava nodes (terrain layer, below units)
	for pos in LAVA_POSITIONS:
		var node: Node2D = preload("res://scripts/LavaNode.gd").new()
		node.position  = pos
		node.z_index   = 10
		world.add_child(node)

	# Enemy base
	for def in ENEMY_BUILDINGS:
		var eb: Node2D = preload("res://scripts/EnemyBuilding.gd").new()
		eb.position = def["pos"]
		eb.z_index  = 30
		world.add_child(eb)
		eb.setup(def["size"], def["color"], def["label"], def["hp"])

	for pos in ENEMY_UNIT_POSITIONS:
		var eu: Node2D = preload("res://scripts/EnemyUnit.gd").new()
		eu.position = pos
		eu.z_index  = 50
		world.add_child(eu)

	# Fog of war (above everything on the map)
	var fog: Node2D = preload("res://scripts/FogOfWar.gd").new()
	fog.name    = "FogOfWar"
	fog.z_index = 100
	world.add_child(fog)

	# Starting Hover Truck
	var truck: Node2D = preload("res://scripts/HoverTruck.gd").new()
	truck.name     = "HoverTruck1"
	truck.position = MAP_SIZE / 2.0 + Vector2(200, 150)
	truck.z_index  = 50
	world.add_child(truck)

	# Selection / input handler
	var sel: Node2D = preload("res://scripts/SelectionManager.gd").new()
	sel.name    = "SelectionManager"
	sel.z_index = 200
	world.add_child(sel)

	# Camera
	var cam: Camera2D = preload("res://scripts/CameraRig.gd").new()
	cam.name     = "CameraRig"
	cam.position = MAP_SIZE / 2.0 + Vector2(200, 150)
	add_child(cam)

	# UI layer (HUD + MiniMap)
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	var hud: Control = preload("res://scripts/HUD.gd").new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)

	var rp: Control = preload("res://scripts/RightPanel.gd").new()
	rp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(rp)

	var build_menu: Control = preload("res://scripts/BuildMenu.gd").new()
	build_menu.name       = "BuildMenu"
	build_menu.world_root = world
	build_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(build_menu)

	var bottom_bar: Control = preload("res://scripts/BottomBar.gd").new()
	bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bottom_bar)
