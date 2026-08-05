extends RefCounted
class_name ProjectileSystem

static func fire_hitscan(from: Vector2, angle: float, range: float, _level: LevelManager) -> Dictionary:
	var dir := Vector2(cos(angle), sin(angle))
	var check_pos := from

	var steps := int(range / 10.0)
	for _i in steps:
		check_pos += dir * 10.0
		var mx := int(check_pos.x / Globals.TILE_SIZE)
		var my := int(check_pos.y / Globals.TILE_SIZE)

		if _level.is_wall(mx, my):
			return {
				"hit": true,
				"hit_wall": true,
				"hit_enemy": false,
				"position": check_pos,
				"tile_x": mx,
				"tile_y": my,
			}

	return {
		"hit": false,
		"hit_wall": false,
		"hit_enemy": false,
		"position": check_pos,
	}

static func check_melee_hit(player_pos: Vector2, player_angle: float, enemies: Array, range: float, damage: int):
	var dir := Vector2(cos(player_angle), sin(player_angle))
	for e in enemies:
		if not e.alive:
			continue
		var to_enemy: Vector2 = e.world_pos - player_pos
		var dist: float = to_enemy.length()
		if dist > range:
			continue
		to_enemy = to_enemy.normalized()
		var dot: float = to_enemy.dot(dir)
		if dot > 0.5:
			return e
	return null