extends RefCounted
class_name LevelManager

const DOOR_TILE_START := 90
const DOOR_TILE_END := 105
const ACTOR_TILE_START := 106
const AMBUSH_FLAG := 0x8000

class DoorData:
	var map_x: int
	var map_y: int
	var vertical: bool
	var locked: bool
	var key_required: int  # 0=none, 1=gold, 2=silver
	var state: int  # 0=closed, 1-3=opening stages, fully open=empty on map
	var position: int  # 0=closed, fully open=MAX
	var ticcount: int
	var open_delay: int = 150  # 2.5 seconds at 60fps
	var secret: bool = false

	const MAX_POSITION := 64  # fully open

class PushwallData:
	var map_x: int
	var map_y: int
	var direction: int  # 0=N, 1=E, 2=S, 3=W
	var position: int  # 0=start, 64=fully pushed (one tile)
	var active: bool = false

var _map: Array = []
var _doors: Array[DoorData] = []
var _pushwalls: Array[PushwallData] = []

var wall_tiles_zero_based: bool = true

func load_from_gamemaps(raw_map: Array) -> void:
	_map = raw_map.duplicate()
	_doors.clear()
	_pushwalls.clear()
	_scan_map_for_features()

func get_tile(x: int, y: int) -> int:
	if x < 0 or x >= Globals.MAP_WIDTH or y < 0 or y >= Globals.MAP_HEIGHT:
		return 1
	return _map[y * Globals.MAP_WIDTH + x] & 0xFF

func get_map() -> Array:
	return _map

func is_wall(x: int, y: int) -> bool:
	var tile: int = get_tile(x, y)
	if tile == 0:
		return false
	if tile >= 1 and tile < DOOR_TILE_START:
		return true
	if tile >= DOOR_TILE_START and tile <= DOOR_TILE_END:
		return true
	return false

func is_door(x: int, y: int) -> bool:
	var tile: int = get_tile(x, y)
	return tile >= DOOR_TILE_START and tile <= DOOR_TILE_END

func get_door_at(x: int, y: int) -> DoorData:
	for d in _doors:
		if d.map_x == x and d.map_y == y:
			return d
	return null

func trigger_door(x: int, y: int) -> bool:
	var door := get_door_at(x, y)
	if door == null:
		return false
	if door.state != 0:  # not closed
		return false
	door.state = 1  # start opening
	door.ticcount = 0
	return true

func update_doors(delta: float) -> void:
	for d in _doors:
		if d.state == 1:  # opening
			d.ticcount += 1
			var step := int(float(d.ticcount) / float(d.open_delay) * d.MAX_POSITION)
			if step >= d.MAX_POSITION:
				step = d.MAX_POSITION
				d.state = 2  # open
			d.position = step
			_update_door_tile(d)
		elif d.state == 3:  # closing
			d.ticcount -= 1
			var step := int(float(d.ticcount) / float(d.open_delay) * d.MAX_POSITION)
			if step <= 0:
				step = 0
				d.state = 0  # closed
			d.position = step
			_update_door_tile(d)

func _update_door_tile(d: DoorData) -> void:
	if d.position <= 0:
		# closed - restore door tile
		var base_tile := DOOR_TILE_START
		if d.locked:
			base_tile = 98 if d.key_required == 1 else 100
		_map[d.map_y * Globals.MAP_WIDTH + d.map_x] = base_tile + (0 if d.vertical else 4)
	elif d.position >= d.MAX_POSITION:
		# fully open
		_map[d.map_y * Globals.MAP_WIDTH + d.map_x] = 0
	else:
		# partially open - use intermediate tile
		var base_tile := DOOR_TILE_START
		var frame := 1 + int(d.position * 3 / d.MAX_POSITION)
		if d.locked:
			base_tile = 98 if d.key_required == 1 else 100
		_map[d.map_y * Globals.MAP_WIDTH + d.map_x] = base_tile + frame + (0 if d.vertical else 4)

func push_wall(x: int, y: int, dir: int) -> bool:
	if _map[y * Globals.MAP_WIDTH + x] != 0:
		return false

	var dx := 0
	var dy := 0
	match dir:
		0: dy = 1   # north (push south)
		1: dx = -1  # east (push west)
		2: dy = -1  # south (push north)
		3: dx = 1   # west (push east)

	var target_x := x + dx
	var target_y := y + dy
	if target_x < 1 or target_x >= Globals.MAP_WIDTH - 1:
		return false
	if target_y < 1 or target_y >= Globals.MAP_HEIGHT - 1:
		return false
	if _map[target_y * Globals.MAP_WIDTH + target_x] != 0:
		return false

	var pw := PushwallData.new()
	pw.map_x = x
	pw.map_y = y
	pw.direction = dir
	pw.position = 0
	pw.active = true

	_map[y * Globals.MAP_WIDTH + x] = 64 + dir
	_pushwalls.append(pw)
	return true

func _scan_map_for_features() -> void:
	for y in Globals.MAP_HEIGHT:
		for x in Globals.MAP_WIDTH:
			var val: int = _map[y * Globals.MAP_WIDTH + x]
			var tile: int = val & 0xFF

			if tile >= DOOR_TILE_START and tile <= DOOR_TILE_END:
				var d := DoorData.new()
				d.map_x = x
				d.map_y = y
				d.vertical = (tile == 90 or tile == 91 or tile == 98 or tile == 99 or tile == 100 or tile == 101)
				if tile >= 98 and tile <= 101:
					d.locked = true
					d.key_required = 1 if tile <= 99 else 2
				_doors.append(d)