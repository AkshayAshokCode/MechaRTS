extends Node

# Global signals
signal energy_changed(amount: float)
signal manpower_changed(amount: int)
signal selection_changed(units: Array)
signal building_selected(building: Node)

# Economy
var energy: float = 0.0
var energy_cap: float = 500.0
var manpower: int = 0
var manpower_cap: int = 10

# Selection
var selected_units: Array = []
var selected_building: Node = null

# Fog grid (populated by FogOfWar in Phase 1)
var fog_grid: Dictionary = {}

# Parts system (Phase 5)
var part_inventory: Array = []   # Array of part Dictionaries (see PartCatalog.gd)
var combot_draft: Dictionary = { "torso": null, "legs": null, "arm_l": null, "arm_r": null }
signal inventory_changed


func select_units(units: Array) -> void:
	selected_units = units
	selection_changed.emit(selected_units)

func select_building(building: Node) -> void:
	selected_building = building
	building_selected.emit(building)


func add_energy(amount: float) -> void:
	energy = minf(energy + amount, energy_cap)
	energy_changed.emit(energy)


func spend_energy(amount: float) -> bool:
	if energy < amount:
		return false
	energy -= amount
	energy_changed.emit(energy)
	return true


# ── Parts helpers ──────────────────────────────────────────────────────────────

func add_part(part: Dictionary) -> void:
	part_inventory.append(part)
	inventory_changed.emit()

# Assign the part at inv_idx to the appropriate draft slot.
# Arms auto-fill arm_l then arm_r; existing parts are returned to inventory.
func draft_part(inv_idx: int) -> void:
	if inv_idx < 0 or inv_idx >= part_inventory.size():
		return
	var p: Dictionary = part_inventory[inv_idx]
	var slot: String = p.get("slot", "")
	if slot == "arm":
		if combot_draft["arm_l"] == null:
			slot = "arm_l"
		elif combot_draft["arm_r"] == null:
			slot = "arm_r"
		else:
			# Both arm slots full — replace arm_l and return old one
			part_inventory.append(combot_draft["arm_l"])
			slot = "arm_l"
	elif not combot_draft.has(slot):
		return
	# Return current draft occupant to inventory
	if combot_draft[slot] != null:
		part_inventory.append(combot_draft[slot])
	combot_draft[slot] = p
	part_inventory.remove_at(inv_idx)
	inventory_changed.emit()

# Remove a part from the draft, returning it to inventory.
func undraft_part(slot: String) -> void:
	if not combot_draft.has(slot) or combot_draft[slot] == null:
		return
	part_inventory.append(combot_draft[slot])
	combot_draft[slot] = null
	inventory_changed.emit()

func can_assemble() -> bool:
	return combot_draft["torso"] != null and combot_draft["legs"] != null
