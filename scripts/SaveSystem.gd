extends Node

const SAVE_PATH := "user://savegame.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func save_game(world: Node2D) -> void:
	var data := {
		"version":        2,
		"elapsed":        GameState.elapsed_time,
		"energy":         GameState.energy,
		"energy_cap":     GameState.energy_cap,
		"part_inventory": GameState.part_inventory.duplicate(true),
		"buildings":      _collect_buildings(world),
		"units":          _collect_units(world),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))

func load_game(world: Node2D) -> void:
	if not has_save():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		return
	var data := parsed as Dictionary

	# Timer
	GameState.elapsed_time = float(data.get("elapsed", 0.0))

	# Economy
	GameState.energy     = float(data.get("energy",     0.0))
	GameState.energy_cap = float(data.get("energy_cap", 500.0))
	GameState.energy_changed.emit(GameState.energy)

	# Part inventory
	GameState.part_inventory = []
	for p in data.get("part_inventory", []):
		if p is Dictionary:
			GameState.part_inventory.append(p)
	GameState.inventory_changed.emit()

	# Buildings
	for bdata in data.get("buildings", []):
		if not bdata is Dictionary:
			continue
		var btype: String = str(bdata.get("type", ""))
		if btype.is_empty() or not load("res://scripts/Building.gd").DEFS.has(btype):
			continue
		var b: Node2D = load("res://scripts/Building.gd").new()
		b.position = Vector2(float(bdata.get("x", 0.0)), float(bdata.get("y", 0.0)))
		b.z_index  = 30
		world.add_child(b)
		b.setup(btype)
		b.is_ghost       = false
		b.is_built       = bool(bdata.get("is_built", false))
		b.build_progress = float(bdata.get("progress", 0.0))
		b.health         = float(bdata.get("health", b.max_health))
		b.queue_redraw()

	# Units (vehicles + combots)
	for udata in data.get("units", []):
		if not udata is Dictionary:
			continue
		var script_name: String = str(udata.get("script", ""))
		var script_path := "res://scripts/" + script_name + ".gd"
		if not ResourceLoader.exists(script_path):
			continue
		var v: Node2D = load(script_path).new()
		v.position = Vector2(float(udata.get("x", 0.0)), float(udata.get("y", 0.0)))
		v.z_index  = 50
		world.add_child(v)
		# Combots store parts as a var_to_str string so Color survives the JSON round-trip
		if udata.has("combot_parts") and v.has_method("setup_from_draft"):
			var parts_var: Variant = str_to_var(str(udata.get("combot_parts", "")))
			if parts_var is Dictionary:
				v.setup_from_draft(parts_var as Dictionary)
		# Restore health after setup (setup_from_draft resets it to max)
		v.set("health", float(udata.get("health", 100.0)))

	# Rebake nav to include all restored buildings
	for nm in world.get_tree().get_nodes_in_group("nav_manager"):
		if nm.has_method("on_building_placed"):
			nm.on_building_placed(null)
			break

# ── Collectors ────────────────────────────────────────────────────────────────

func _collect_buildings(world: Node2D) -> Array:
	var result: Array = []
	if world == null or not world.is_inside_tree():
		return result
	for b in world.get_tree().get_nodes_in_group("buildings"):
		if b.get("is_ghost") == true:
			continue
		var bpos: Vector2 = (b as Node2D).global_position
		result.append({
			"type":     str(b.get("building_type")),
			"x":        bpos.x,
			"y":        bpos.y,
			"is_built": bool(b.get("is_built")),
			"progress": float(b.get("build_progress")),
			"health":   float(b.get("health")),
		})
	return result

func _collect_units(world: Node2D) -> Array:
	var result: Array = []
	if world == null or not world.is_inside_tree():
		return result
	for unit in world.get_tree().get_nodes_in_group("units"):
		var upos: Vector2 = (unit as Node2D).global_position
		var script_name: String = unit.get_script().get_path().get_file().get_basename()
		var entry: Dictionary = {
			"script": script_name,
			"x":      upos.x,
			"y":      upos.y,
			"health": float(unit.get("health")),
		}
		# Combot: serialise parts (including Color) via var_to_str
		var parts = unit.get("combot_parts")
		if parts is Dictionary:
			entry["combot_parts"] = var_to_str((parts as Dictionary).duplicate(true))
		result.append(entry)
	return result
