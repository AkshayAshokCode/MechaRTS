extends Node2D

const MAP_SIZE       := Vector2(6400.0, 4800.0)
const CELL_SIZE      := 64
const UPDATE_INTERVAL := 0.1

const STATE_UNSEEN   := 0
const STATE_EXPLORED := 1
const STATE_VISIBLE  := 2

var _cols: int
var _rows: int
var _grid:    PackedByteArray
var _image:   Image
var _texture: ImageTexture
var _sprite:  Sprite2D
var _timer    := 0.0

func _ready() -> void:
	add_to_group("fog_of_war")
	_cols = int(MAP_SIZE.x) / CELL_SIZE
	_rows = int(MAP_SIZE.y) / CELL_SIZE

	_grid = PackedByteArray()
	_grid.resize(_cols * _rows)
	_grid.fill(STATE_UNSEEN)

	_image = Image.create(_cols, _rows, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	_texture = ImageTexture.create_from_image(_image)

	_sprite = Sprite2D.new()
	_sprite.texture        = _texture
	_sprite.centered       = false
	_sprite.scale          = Vector2(CELL_SIZE, CELL_SIZE)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= UPDATE_INTERVAL:
		_timer = 0.0
		_update_vision()

func _update_vision() -> void:
	for i in _grid.size():
		if _grid[i] == STATE_VISIBLE:
			_grid[i] = STATE_EXPLORED
	for unit in get_tree().get_nodes_in_group("units"):
		_reveal_around((unit as Node2D).global_position, unit.vision_range)
	_flush_texture()

func _reveal_around(world_pos: Vector2, radius: float) -> void:
	var cx     := int(world_pos.x) / CELL_SIZE
	var cy     := int(world_pos.y) / CELL_SIZE
	var cell_r := int(ceil(radius / CELL_SIZE)) + 1
	var r2     := (radius / CELL_SIZE) * (radius / CELL_SIZE)
	for dy in range(-cell_r, cell_r + 1):
		for dx in range(-cell_r, cell_r + 1):
			if float(dx * dx + dy * dy) > r2:
				continue
			var nx := cx + dx
			var ny := cy + dy
			if nx < 0 or ny < 0 or nx >= _cols or ny >= _rows:
				continue
			_grid[ny * _cols + nx] = STATE_VISIBLE

func _flush_texture() -> void:
	for cy in _rows:
		for cx in _cols:
			var color: Color
			match _grid[cy * _cols + cx]:
				STATE_VISIBLE:  color = Color(0.0, 0.0, 0.0, 0.0)
				STATE_EXPLORED: color = Color(0.0, 0.0, 0.0, 0.65)
				_:              color = Color(0.0, 0.0, 0.0, 1.0)
			_image.set_pixel(cx, cy, color)
	_texture.update(_image)

func get_cell_state(world_pos: Vector2) -> int:
	var cx := int(world_pos.x) / CELL_SIZE
	var cy := int(world_pos.y) / CELL_SIZE
	if cx < 0 or cy < 0 or cx >= _cols or cy >= _rows:
		return STATE_UNSEEN
	return _grid[cy * _cols + cx]
