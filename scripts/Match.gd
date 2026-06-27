extends Node2D

const MAP_SIZE := Vector2(6400.0, 4800.0)

func _ready() -> void:
	var world := Node2D.new()
	world.name = "WorldRoot"
	add_child(world)

	var bg := ColorRect.new()
	bg.color = Color(0.14, 0.11, 0.07)
	bg.size = MAP_SIZE
	world.add_child(bg)

	var fog: Node2D = preload("res://scripts/FogOfWar.gd").new()
	fog.name = "FogOfWar"
	fog.z_index = 100
	world.add_child(fog)

	var unit: Node2D = preload("res://scripts/Unit.gd").new()
	unit.name = "TestUnit"
	unit.position = MAP_SIZE / 2.0
	unit.z_index = 50
	world.add_child(unit)

	var sel: Node2D = preload("res://scripts/SelectionManager.gd").new()
	sel.name = "SelectionManager"
	sel.z_index = 200
	world.add_child(sel)

	var cam: Camera2D = preload("res://scripts/CameraRig.gd").new()
	cam.name = "CameraRig"
	cam.position = MAP_SIZE / 2.0
	add_child(cam)

	var mm_layer := CanvasLayer.new()
	mm_layer.layer = 10
	add_child(mm_layer)

	var mm: Control = preload("res://scripts/MiniMap.gd").new()
	mm.name = "MiniMap"
	mm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm_layer.add_child(mm)
