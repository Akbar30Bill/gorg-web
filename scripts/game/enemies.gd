extends RefCounted
class_name EnemySystem

enum EnemyState { SPAWN, IDLE, PATROL, CHASE, ATTACK, PAIN, DEATH }
enum EnemyType { GUARD, SS, DOG, MUTANT, OFFICER, HANS }

class EnemyData:
	var type: EnemyType
	var world_pos: Vector2
	var angle: float
	var health: int
	var max_health: int
	var state: EnemyState
	var state_timer: float
	var speed: float
	var damage: float
	var attack_range: float
	var sight_range: float
	var sprite_index: int
	var alive: bool
	var alert: bool
	var path_target: Vector2
	var attack_cooldown: float
	var pain_timer: float
	var tile_x: int
	var tile_y: int

const ENEMY_DEFS: Dictionary = {
	EnemyType.GUARD: {
		"max_health": 25, "speed": 80.0, "damage": 8.0,
		"attack_range": 200.0, "sight_range": 350.0,
		"sprite_base": 0
	},
	EnemyType.SS: {
		"max_health": 50, "speed": 110.0, "damage": 10.0,
		"attack_range": 220.0, "sight_range": 400.0,
		"sprite_base": 1
	},
	EnemyType.DOG: {
		"max_health": 15, "speed": 160.0, "damage": 12.0,
		"attack_range": 30.0, "sight_range": 300.0,
		"sprite_base": 2
	},
	EnemyType.MUTANT: {
		"max_health": 55, "speed": 70.0, "damage": 15.0,
		"attack_range": 100.0, "sight_range": 250.0,
		"sprite_base": 4
	},
	EnemyType.OFFICER: {
		"max_health": 50, "speed": 100.0, "damage": 10.0,
		"attack_range": 250.0, "sight_range": 380.0,
		"sprite_base": 3
	},
	EnemyType.HANS: {
		"max_health": 200, "speed": 90.0, "damage": 20.0,
		"attack_range": 300.0, "sight_range": 500.0,
		"sprite_base": 5
	},
}

var _enemies: Array[EnemyData] = []

func clear() -> void:
	_enemies.clear()

func spawn(enemy_type: EnemyType, world_x: float, world_y: float, ambush: bool = false) -> EnemyData:
	var e := EnemyData.new()
	e.type = enemy_type
	e.world_pos = Vector2(world_x, world_y)
	e.angle = 0.0
	var def: Dictionary = ENEMY_DEFS.get(enemy_type, ENEMY_DEFS[EnemyType.GUARD])
	e.max_health = def["max_health"]
	e.health = e.max_health
	e.speed = def["speed"]
	e.damage = def["damage"]
	e.attack_range = def["attack_range"]
	e.sight_range = def["sight_range"]
	e.sprite_index = def["sprite_base"]
	e.alive = true
	e.alert = not ambush
	e.state = EnemyState.IDLE
	e.state_timer = 0.0
	e.attack_cooldown = 0.0
	e.pain_timer = 0.0
	e.tile_x = int(world_x / Globals.TILE_SIZE)
	e.tile_y = int(world_y / Globals.TILE_SIZE)
	_enemies.append(e)
	return e

func update_all(delta: float, _level: LevelManager) -> void:
	for e: EnemyData in _enemies:
		if not e.alive:
			continue
		e.attack_cooldown = maxf(0.0, e.attack_cooldown - delta)
		e.pain_timer = maxf(0.0, e.pain_timer - delta)
		e.state_timer += delta

		match e.state:
			EnemyState.IDLE:
				if e.alert or _can_see_player(e, _level):
					e.state = EnemyState.CHASE
					e.alert = true
			EnemyState.PATROL:
				if _can_see_player(e, _level):
					e.state = EnemyState.CHASE
				else:
					_move_patrol(e, delta, _level)
			EnemyState.CHASE:
				if not _can_see_player(e, _level):
					e.state = EnemyState.IDLE
				else:
					var dist: float = e.world_pos.distance_to(Globals.player_pos)
					if dist < e.attack_range:
						e.state = EnemyState.ATTACK
					else:
						_move_toward(e, Globals.player_pos, delta, _level)
			EnemyState.ATTACK:
				var dist: float = e.world_pos.distance_to(Globals.player_pos)
				if dist > e.attack_range * 1.2:
					e.state = EnemyState.CHASE
				elif e.attack_cooldown <= 0:
					e.attack_cooldown = 0.8
			EnemyState.PAIN:
				if e.pain_timer <= 0:
					if _can_see_player(e, _level):
						e.state = EnemyState.CHASE
					else:
						e.state = EnemyState.IDLE
			EnemyState.DEATH:
				pass

func damage_enemy(e: EnemyData, amount: int) -> bool:
	if not e.alive:
		return false
	e.health -= amount
	if e.health <= 0:
		e.health = 0
		e.alive = false
		e.state = EnemyState.DEATH
		Globals.player_score += 100
		return true
	e.state = EnemyState.PAIN
	e.pain_timer = 0.3
	e.alert = true
	return false

func get_enemies() -> Array[EnemyData]:
	return _enemies

func get_enemies_for_rendering() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for e: EnemyData in _enemies:
		if not e.alive:
			continue
		if e.sprite_index < Globals.sprite_images.size():
			result.append({
				"image": Globals.sprite_images[e.sprite_index],
				"pos": e.world_pos,
			})
	return result

func _can_see_player(e: EnemyData, _level: LevelManager) -> bool:
	var dist: float = e.world_pos.distance_to(Globals.player_pos)
	if dist > e.sight_range:
		return false
	return true  # TODO: proper LOS check with raycast

func _move_toward(e: EnemyData, target: Vector2, delta: float, _level: LevelManager) -> void:
	var dir: Vector2 = target - e.world_pos
	if dir.length() < 1.0:
		return
	dir = dir.normalized()
	e.angle = atan2(dir.y, dir.x)

	var new_x: float = e.world_pos.x + dir.x * e.speed * delta
	var new_y: float = e.world_pos.y + dir.y * e.speed * delta

	if not _level.is_wall(int(new_x / Globals.TILE_SIZE), int(e.world_pos.y / Globals.TILE_SIZE)):
		e.world_pos.x = new_x
	if not _level.is_wall(int(e.world_pos.x / Globals.TILE_SIZE), int(new_y / Globals.TILE_SIZE)):
		e.world_pos.y = new_y

	e.tile_x = int(e.world_pos.x / Globals.TILE_SIZE)
	e.tile_y = int(e.world_pos.y / Globals.TILE_SIZE)

func _move_patrol(e: EnemyData, delta: float, _level: LevelManager) -> void:
	if e.path_target == Vector2.ZERO or e.world_pos.distance_to(e.path_target) < 5.0:
		e.path_target = Vector2(
			(e.tile_x + randi_range(-3, 3)) * Globals.TILE_SIZE + Globals.TILE_SIZE / 2.0,
			(e.tile_y + randi_range(-3, 3)) * Globals.TILE_SIZE + Globals.TILE_SIZE / 2.0,
		)
	_move_toward(e, e.path_target, delta, _level)