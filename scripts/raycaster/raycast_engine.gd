extends RefCounted
class_name RaycastEngine

static func cast_ray(map: Array, pos: Vector2, angle: float) -> Dictionary:
	var ray_dir := Vector2(cos(angle), sin(angle))
	var map_x := int(pos.x / Globals.TILE_SIZE)
	var map_y := int(pos.y / Globals.TILE_SIZE)

	var delta_dist := Vector2(
		abs(1.0 / ray_dir.x) if abs(ray_dir.x) > 0.0001 else 1e30,
		abs(1.0 / ray_dir.y) if abs(ray_dir.y) > 0.0001 else 1e30
	)

	var step_x: int
	var step_y: int
	var side_dist: Vector2

	if ray_dir.x < 0:
		step_x = -1
		side_dist.x = (pos.x / Globals.TILE_SIZE - map_x) * delta_dist.x
	else:
		step_x = 1
		side_dist.x = (map_x + 1.0 - pos.x / Globals.TILE_SIZE) * delta_dist.x

	if ray_dir.y < 0:
		step_y = -1
		side_dist.y = (pos.y / Globals.TILE_SIZE - map_y) * delta_dist.y
	else:
		step_y = 1
		side_dist.y = (map_y + 1.0 - pos.y / Globals.TILE_SIZE) * delta_dist.y

	var side := 0
	var max_steps := 64
	var steps := 0
	var hit := false

	while steps < max_steps:
		steps += 1
		if side_dist.x < side_dist.y:
			side_dist.x += delta_dist.x
			map_x += step_x
			side = 0
		else:
			side_dist.y += delta_dist.y
			map_y += step_y
			side = 1

		if map_x < 0 or map_x >= Globals.MAP_WIDTH or map_y < 0 or map_y >= Globals.MAP_HEIGHT:
			break

		var tile := map[map_y * Globals.MAP_WIDTH + map_x] as int
		if tile > 0 and tile < 64:
			hit = true
			break

	if not hit:
		return { "hit": false, "distance": 0.0, "tile": 0, "side": 0, "wall_x": 0.0, "map_x": map_x, "map_y": map_y }

	var perp_dist: float
	var wall_x: float

	if side == 0:
		perp_dist = side_dist.x - delta_dist.x
		wall_x = pos.y / Globals.TILE_SIZE + perp_dist * ray_dir.y
	else:
		perp_dist = side_dist.y - delta_dist.y
		wall_x = pos.x / Globals.TILE_SIZE + perp_dist * ray_dir.x

	wall_x -= floor(wall_x)

	var tile := map[map_y * Globals.MAP_WIDTH + map_x] as int

	return {
		"hit": true,
		"distance": perp_dist,
		"tile": tile,
		"side": side,
		"wall_x": wall_x,
		"map_x": map_x,
		"map_y": map_y,
	}