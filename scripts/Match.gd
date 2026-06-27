extends Node2D

const MAP_SIZE := Vector2(6400.0, 4800.0)

const LAVA_POSITIONS: Array = [
	Vector2(800,  700),  Vector2(5600,  700),
	Vector2(900,  2400), Vector2(5500, 2400),
	Vector2(800,  4100), Vector2(5600, 4100),
	Vector2(3200, 2400),
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

	for script_path in ["res://scripts/HUD.gd", "res://scripts/MiniMap.gd"]:
		var ctrl: Control = load(script_path).new()
		ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(ctrl)

	var build_menu: Control = preload("res://scripts/BuildMenu.gd").new()
	build_menu.name       = "BuildMenu"
	build_menu.world_root = world
	build_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(build_menu)
