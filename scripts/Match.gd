extends Node2D

const MAP_SIZE       := Vector2(6400.0, 4800.0)
const AUTOSAVE_EVERY := 60.0   # seconds between autosaves

# ── Start positions (§11b) ──────────────────────────────────────────────────────
const PLAYER_START := Vector2(700.0, 4200.0)   # bottom-left
# AI starts top-right — enemy buildings placed there below

var _world: Node2D
var _autosave_timer: float = AUTOSAVE_EVERY

# Diagonal lava layout: 2 near player (BL), 2 near AI (TR), 3 contested middle
const LAVA_POSITIONS: Array = [
	Vector2( 600, 4000), Vector2(1100, 4400),   # player-side
	Vector2(5200,  480), Vector2(5800,  950),   # AI-side
	Vector2(1900, 3100), Vector2(3200, 2400), Vector2(4500, 1700),  # contested strip
]

# Enemy base — only the static HQ; all other buildings are constructed by AIPlayer
const ENEMY_BUILDINGS: Array = [
	{ "pos": Vector2(5300, 580), "size": Vector2(100, 80), "color": Color(0.72, 0.15, 0.15), "label": "Command Post", "hp": 800.0, "is_hq": true },
]

# Neutral control points — hold them for +20 MJ/s each
const CAPTURE_POINTS: Array = [
	{ "pos": Vector2(1200, 3400), "label": "Relay Alpha" },
	{ "pos": Vector2(3200, 2400), "label": "Relay Beta"  },
	{ "pos": Vector2(5000, 1400), "label": "Relay Gamma" },
]

# Terrain obstacles — rock formations that form 3 choke points along the diagonal
# Each entry: "pos" = world position of rock centre, "poly" = local polygon vertices
const TERRAIN_OBSTACLES: Array = [
	# Choke 1 — south-west approach (~1600, 3350)
	{ "pos": Vector2(1480, 3150), "poly": [
		Vector2(-30, -90), Vector2( 45, -75), Vector2( 70, -10),
		Vector2( 50,  70), Vector2(-20,  90), Vector2(-65,  30), Vector2(-55, -50) ] },
	{ "pos": Vector2(1750, 3560), "poly": [
		Vector2(-55, -55), Vector2( 35, -70), Vector2( 80,  10),
		Vector2( 50,  65), Vector2(-30,  80), Vector2(-75,  20) ] },

	# Choke 2 — mid-map (~3050, 2350)
	{ "pos": Vector2(2880, 2180), "poly": [
		Vector2(-25, -100), Vector2( 55, -80), Vector2( 75,  20),
		Vector2( 40,   90), Vector2(-40,  85), Vector2(-70,  -5) ] },
	{ "pos": Vector2(3300, 2540), "poly": [
		Vector2(-60, -50), Vector2( 30, -75), Vector2( 85,   5),
		Vector2( 60,  70), Vector2(-15,  90), Vector2(-70,  35) ] },

	# Choke 3 — north-east approach (~4350, 1600)
	{ "pos": Vector2(4150, 1430), "poly": [
		Vector2(-35, -80), Vector2( 50, -65), Vector2( 70,  20),
		Vector2( 35,  80), Vector2(-45,  70), Vector2(-60, -15) ] },
	{ "pos": Vector2(4580, 1770), "poly": [
		Vector2(-50, -65), Vector2( 40, -80), Vector2( 75,  15),
		Vector2( 45,  75), Vector2(-30,  80), Vector2(-70,  10) ] },
]

func _process(delta: float) -> void:
	if GameState.game_ended:
		return
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_EVERY
		SaveSystem.save_game(_world)

func _ready() -> void:
	add_to_group("nav_manager")
	_world = Node2D.new()
	_world.name = "WorldRoot"
	_world.add_to_group("world_root")
	add_child(_world)
	var world := _world

	var bg := ColorRect.new()
	bg.color        = Color(0.14, 0.11, 0.07)
	bg.size         = MAP_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(bg)

	# Navigation region — added before units so agents can start pathing immediately
	_setup_nav_region(world)

	# Terrain obstacles — rock formations creating choke points
	for def in TERRAIN_OBSTACLES:
		var rock: Node2D = preload("res://scripts/TerrainObstacle.gd").new()
		rock.position = def["pos"]
		rock.z_index  = 15
		world.add_child(rock)
		rock.setup(PackedVector2Array(def["poly"]))

	# Lava nodes (terrain layer, below units)
	for pos in LAVA_POSITIONS:
		var node: Node2D = preload("res://scripts/LavaNode.gd").new()
		node.position  = pos
		node.z_index   = 10
		world.add_child(node)

	# Enemy base (top-right) — AIPlayer owns all unit spawning
	for def in ENEMY_BUILDINGS:
		var eb: Node2D = preload("res://scripts/EnemyBuilding.gd").new()
		eb.position = def["pos"]
		eb.z_index  = 30
		world.add_child(eb)
		eb.setup(def["size"], def["color"], def["label"], def["hp"], def.get("is_hq", false))

	# AI controller (manages enemy economy, build plan, and waves)
	var ai: Node = preload("res://scripts/AIPlayer.gd").new()
	ai.name = "AIPlayer"
	world.add_child(ai)

	# AI starting trucks — self-register with AIPlayer via deferred call in _ready
	for truck_pos in [Vector2(5350, 860), Vector2(5480, 820)]:
		var at: Node2D = preload("res://scripts/AIHoverTruck.gd").new()
		at.position = truck_pos
		at.z_index  = 50
		world.add_child(at)

	# Neutral capture points
	for def in CAPTURE_POINTS:
		var cp: Node2D = preload("res://scripts/CapturePoint.gd").new()
		cp.position = def["pos"]
		cp.z_index  = 25
		world.add_child(cp)
		cp.setup(def["label"])

	# Fog of war (above everything on the map)
	var fog: Node2D = preload("res://scripts/FogOfWar.gd").new()
	fog.name    = "FogOfWar"
	fog.z_index = 100
	world.add_child(fog)

	# Player HQ + starting truck — skipped when loading a save (save restores them)
	if not GameState.load_save_on_start:
		var hq: Node2D = preload("res://scripts/Building.gd").new()
		hq.position = PLAYER_START
		hq.z_index  = 30
		world.add_child(hq)
		hq.setup("matter_converter")
		hq.is_ghost       = false
		hq.is_built       = true
		hq.build_progress = 1.0
		hq.queue_redraw()

		var truck: Node2D = preload("res://scripts/HoverTruck.gd").new()
		truck.name     = "HoverTruck1"
		truck.position = PLAYER_START + Vector2(180, 0)
		truck.z_index  = 50
		world.add_child(truck)

	# Selection / input handler
	var sel: Node2D = preload("res://scripts/SelectionManager.gd").new()
	sel.name    = "SelectionManager"
	sel.z_index = 200
	world.add_child(sel)

	# Camera — opens at player start (bottom-left)
	var cam: Camera2D = preload("res://scripts/CameraRig.gd").new()
	cam.name     = "CameraRig"
	cam.position = PLAYER_START
	add_child(cam)

	# UI layer (HUD + panels)
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

	# Pause menu — layer 20, always-process so ESC and buttons work while paused
	var pause_layer := CanvasLayer.new()
	pause_layer.layer        = 20
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	var pause_menu: Control = preload("res://scripts/PauseMenu.gd").new()
	pause_menu.name = "PauseMenu"
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(pause_menu)

	# Game-over overlay on a top-most canvas layer
	var go_layer := CanvasLayer.new()
	go_layer.layer = 50
	add_child(go_layer)
	var go: Control = preload("res://scripts/GameOver.gd").new()
	go.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	go_layer.add_child(go)

	# Economy + parts: restore from save or hand out starter kit
	if GameState.load_save_on_start:
		SaveSystem.load_game(_world)
		GameState.load_save_on_start = false
	else:
		GameState.add_energy(200.0)
		var cat: Array = load("res://scripts/PartCatalog.gd").ALL
		GameState.add_part(cat[0].duplicate())   # Basic Torso
		GameState.add_part(cat[2].duplicate())   # Basic Legs
		GameState.add_part(cat[4].duplicate())   # Plasma Cannon
		GameState.add_part(cat[1].duplicate())   # Armor Torso
		GameState.add_part(cat[3].duplicate())   # Speed Legs

	# Rebake nav after all buildings are in the tree so the player HQ is an obstacle
	call_deferred("_rebake_nav")

# ── Navigation region ──────────────────────────────────────────────────────────

func _setup_nav_region(world: Node2D) -> void:
	var nav_region := NavigationRegion2D.new()
	nav_region.name = "NavRegion"
	nav_region.add_to_group("nav_region")
	world.add_child(nav_region)
	_rebake_nav()

# Called by Building.place() whenever a player building is finalized.
func on_building_placed(_building: Node) -> void:
	_rebake_nav()

func _rebake_nav() -> void:
	var nav_region: Node = get_tree().get_first_node_in_group("nav_region")
	if nav_region == null:
		return

	var nav_poly    := NavigationPolygon.new()
	var source_geom := NavigationMeshSourceGeometryData2D.new()
	_populate_source_geom(source_geom)
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_geom)
	(nav_region as NavigationRegion2D).navigation_polygon = nav_poly

func _populate_source_geom(sg: NavigationMeshSourceGeometryData2D) -> void:
	# Traversable area: full map
	sg.add_traversable_outline(PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(MAP_SIZE.x, 0.0),
		Vector2(MAP_SIZE.x, MAP_SIZE.y),
		Vector2(0.0, MAP_SIZE.y),
	]))

	# Lava exclusion zones — 50 px radius, 12-sided polygon
	for lava_pos in LAVA_POSITIONS:
		var hole := PackedVector2Array()
		for i in 12:
			var a := TAU * i / 12.0
			hole.append(lava_pos + Vector2(cos(a), sin(a)) * 50.0)
		sg.add_obstruction_outline(hole)

	# Static enemy building exclusion boxes (with 14 px margin)
	for def in ENEMY_BUILDINGS:
		var pos: Vector2 = def["pos"]
		var sz: Vector2  = def["size"]
		var hx := sz.x * 0.5 + 14.0
		var hy := sz.y * 0.5 + 14.0
		sg.add_obstruction_outline(PackedVector2Array([
			pos + Vector2(-hx, -hy),
			pos + Vector2( hx, -hy),
			pos + Vector2( hx,  hy),
			pos + Vector2(-hx,  hy),
		]))

	# Static terrain obstacle outlines (with 12 px nav margin)
	for def in TERRAIN_OBSTACLES:
		var centre: Vector2 = def["pos"]
		var local_pts: Array = def["poly"]
		var out := PackedVector2Array()
		var centroid := Vector2.ZERO
		for p in local_pts:
			centroid += Vector2(p.x, p.y)
		centroid /= local_pts.size()
		for p in local_pts:
			var lp := Vector2(p.x, p.y)
			var expanded := centroid + (lp - centroid) * 1.18   # ~12 px outset via scale
			out.append(centre + expanded)
		sg.add_obstruction_outline(out)

	# Player-placed buildings (non-ghost)
	if get_tree() == null:
		return
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.get("is_ghost") == true:
			continue
		var bpos: Vector2  = (b as Node2D).global_position
		var bsz: Variant   = b.get("_size")
		if not bsz is Vector2:
			continue
		var half := (bsz as Vector2) * 0.5 + Vector2(8.0, 8.0)
		sg.add_obstruction_outline(PackedVector2Array([
			bpos + Vector2(-half.x, -half.y),
			bpos + Vector2( half.x, -half.y),
			bpos + Vector2( half.x,  half.y),
			bpos + Vector2(-half.x,  half.y),
		]))
