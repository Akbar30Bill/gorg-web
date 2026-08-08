extends RefCounted
class_name LevelManager

const DOOR_TILE_START := 90
const DOOR_TILE_END := 101
const ACTOR_TILE_START := 106
const AMBUSH_FLAG := 0x8000
const WALL_TILE_END := 63
const ELEVATOR_TILE := 21
const PUSHWALL_TILE_START := 64

class DoorData:
	var map_x: int
	var map_y: int
	var vertical: bool
	var locked: bool
	var key_required: int
	var state: int
	var position: int
	var ticcount: int
	var open_delay: int = 150
	var secret: bool = false

	const MAX_POSITION := 64

class PushwallData:
	var map_x: int
	var map_y: int
	var direction: int
	var position: int
	var active: bool = false

var _map: Array = []
var _plane0: Array = []
var _plane1: Array = []
var _plane2: Array = []
var _doors: Array[DoorData] = []
var _pushwalls: Array[PushwallData] = []

var wall_tiles_zero_based: bool = true

func load_from_gamemaps(result: Dictionary) -> void:
	_plane0 = result.get("plane0", []).duplicate()
	_plane1 = result.get("plane1", []).duplicate()
	_plane2 = result.get("plane2", []).duplicate()
	if _plane0.is_empty() or _plane0.size() < Globals.MAP_WIDTH * Globals.MAP_HEIGHT:
		_plane0 = WADParser.GameMapsFile.new()._build_default_map()
	if _plane0.is_empty():
		_plane0 = WADParser.GameMapsFile.new()._build_default_map()
	_map = _plane0
	_doors.clear()
	_pushwalls.clear()
	_scan_map_for_features()

func get_tile(x: int, y: int) -> int:
	if x < 0 or x >= Globals.MAP_WIDTH or y < 0 or y >= Globals.MAP_HEIGHT:
		return 1
	if _plane0.is_empty():
		return 0
	var raw_val = _plane0[y * Globals.MAP_WIDTH + x]
	return (raw_val if raw_val != null else 0) & 0xFF

func get_object_tile(x: int, y: int) -> int:
	if x < 0 or x >= Globals.MAP_WIDTH or y < 0 or y >= Globals.MAP_HEIGHT:
		return 0
	if _plane1.is_empty():
		return 0
	var raw_val = _plane1[y * Globals.MAP_WIDTH + x]
	return (raw_val if raw_val != null else 0) & 0xFF

func get_plane1() -> Array:
	return _plane1

func get_map() -> Array:
	return _map

func is_wall(x: int, y: int) -> bool:
	var tile: int = get_tile(x, y)
	if tile == 0:
		return false
	if tile >= 1 and tile <= WALL_TILE_END:
		return true
	if tile >= PUSHWALL_TILE_START and tile <= PUSHWALL_TILE_START + 3:
		return true
	if tile >= DOOR_TILE_START and tile <= DOOR_TILE_END:
		return true
	return false

func is_door(x: int, y: int) -> bool:
	var tile: int = get_tile(x, y)
	return tile >= DOOR_TILE_START and tile <= DOOR_TILE_END

func get_door_at(x: int, y: int) -> DoorData:
	for d: DoorData in _doors:
		if d.map_x == x and d.map_y == y:
			return d
	return null

func trigger_door(x: int, y: int) -> bool:
	var door: DoorData = get_door_at(x, y)
	if door == null:
		return false
	if door.state != 0:
		return false
	door.state = 1
	door.ticcount = 0
	return true

func update_doors(delta: float) -> void:
	for d: DoorData in _doors:
		if d.state == 1:
			d.ticcount += 1
			var step: int = int(float(d.ticcount) / float(d.open_delay) * d.MAX_POSITION)
			if step >= d.MAX_POSITION:
				step = d.MAX_POSITION
				d.state = 2
			d.position = step
			_update_door_tile(d)
		elif d.state == 3:
			d.ticcount -= 1
			var step: int = int(float(d.ticcount) / float(d.open_delay) * d.MAX_POSITION)
			if step <= 0:
				step = 0
				d.state = 0
			d.position = step
			_update_door_tile(d)

func _update_door_tile(d: DoorData) -> void:
	if d.position <= 0:
		var base_tile: int = DOOR_TILE_START
		if d.locked:
			base_tile = 98 if d.key_required == 1 else 100
		_map[d.map_y * Globals.MAP_WIDTH + d.map_x] = base_tile + (0 if d.vertical else 4)
	elif d.position >= d.MAX_POSITION:
		_map[d.map_y * Globals.MAP_WIDTH + d.map_x] = 0
	else:
		var base_tile: int = DOOR_TILE_START
		var frame: int = 1 + int(d.position * 3 / d.MAX_POSITION)
		if d.locked:
			base_tile = 98 if d.key_required == 1 else 100
		_map[d.map_y * Globals.MAP_WIDTH + d.map_x] = base_tile + frame + (0 if d.vertical else 4)

func push_wall(wall_x: int, wall_y: int, push_dir: int) -> bool:
	var tile: int = (_plane0[wall_y * Globals.MAP_WIDTH + wall_x] if _plane0[wall_y * Globals.MAP_WIDTH + wall_x] != null else 0) as int
	if tile < 1 or tile > WALL_TILE_END:
		return false

	var dest_x: int = wall_x
	var dest_y: int = wall_y
	match push_dir:
		0: dest_y -= 1
		1: dest_x += 1
		2: dest_y += 1
		3: dest_x -= 1

	if dest_x < 1 or dest_x >= Globals.MAP_WIDTH - 1:
		return false
	if dest_y < 1 or dest_y >= Globals.MAP_HEIGHT - 1:
		return false
	if _plane0[dest_y * Globals.MAP_WIDTH + dest_x] != 0:
		return false
	if not _plane1.is_empty() and _plane1[dest_y * Globals.MAP_WIDTH + dest_x] != 0:
		return false

	var pw := PushwallData.new()
	pw.map_x = wall_x
	pw.map_y = wall_y
	pw.direction = push_dir
	pw.position = 0
	pw.active = true

	_plane0[wall_y * Globals.MAP_WIDTH + wall_x] = PUSHWALL_TILE_START + push_dir
	_pushwalls.append(pw)
	return true

func _scan_map_for_features() -> void:
	for y: int in range(Globals.MAP_HEIGHT):
		for x: int in range(Globals.MAP_WIDTH):
			var raw_val = _plane0[y * Globals.MAP_WIDTH + x]
			var val: int = raw_val if raw_val != null else 0
			var tile: int = val & 0xFF

			if tile >= DOOR_TILE_START and tile <= DOOR_TILE_END:
				var d := DoorData.new()
				d.map_x = x
				d.map_y = y
				d.vertical = (tile % 2 == 0)
				if tile >= 98 and tile <= 101:
					d.locked = true
					d.key_required = 1 if tile <= 99 else 2
				_doors.append(d)