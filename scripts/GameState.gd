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
