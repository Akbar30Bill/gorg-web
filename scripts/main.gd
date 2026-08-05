extends Control

var _level: LevelManager = null
var _weapons: WeaponSystem = null
var _enemies: EnemySystem = null
var _sprite_renderer: SpriteRenderer = null
var _pickups: PickupSystem = null
var _vswap: WADParser.VSwapFile = null
var _gamemaps: WADParser.GameMapsFile = null

var _keys: Dictionary = {}
var _mouse_captured: bool = false
var _mouse_delta: float = 0.0
var _just_pressed: Dictionary = {}

func _ready() -> void:
	Globals.screen_image = Image.create(Globals.SCREEN_WIDTH, Globals.SCREEN_HEIGHT, false, Image.FORMAT_RGBA8)
	Globals.screen_texture = ImageTexture.create_from_image(Globals.screen_image)
	Globals.z_buffer.resize(Globals.SCREEN_WIDTH)
	Globals.z_buffer.fill(0.0)

	var texture_rect := TextureRect.new()
	texture_rect.name = "GameView"
	texture_rect.texture = Globals.screen_texture
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(texture_rect)
	Globals.texture_rect = texture_rect

	_level = LevelManager.new()
	_weapons = WeaponSystem.new()
	_enemies = EnemySystem.new()
	_sprite_renderer = SpriteRenderer.new()
	_pickups = PickupSystem.new()

	_load_assets()
	_init_game()

func _load_assets() -> void:
	_vswap = WADParser.load_vswap("res://assets/wolf3d/VSWAP.WL6")
	if _vswap:
		var num_walls := mini(_vswap.sprite_start, Globals.NUM_WALL_TEXTURES)
		for i in num_walls:
			Globals.wall_textures.append(_vswap.load_wall_texture(i))
		for i in range(_vswap.sprite_start, _vswap.offsets.size()):
			var si := i - _vswap.sprite_start
			if si >= 50:
				break
			var img := _vswap.load_sprite(si)
			if img:
				Globals.sprite_images.append(img)

	if Globals.wall_textures.is_empty():
		_generate_placeholder_textures()

	_gamemaps = WADParser.load_gamemaps("res://assets/wolf3d/MAPHEAD.WL6", "res://assets/wolf3d/GAMEMAPS.WL6")
	Globals.wad_loaded = _vswap != null and _gamemaps != null

func _generate_placeholder_textures() -> void:
	for i in Globals.NUM_WALL_TEXTURES:
		var img := Image.create(Globals.TILE_SIZE, Globals.TILE_SIZE, false, Image.FORMAT_RGBA8)
		for x in Globals.TILE_SIZE:
			for y in Globals.TILE_SIZE:
				var r := float(x) / Globals.TILE_SIZE
				var g := float(y) / Globals.TILE_SIZE
				var b := float((x ^ y) & 0x3F) / 64.0
				var shade := 0.7 + 0.3 * sin((x + y) * 0.1 + i)
				img.set_pixel(x, y, Color(r * shade, g * shade, b * shade))
		Globals.wall_textures.append(img)

func _init_game() -> void:
	var raw_map: Array
	if _gamemaps:
		raw_map = _gamemaps.load_map(Globals.current_level)
	else:
		raw_map = WADParser.GameMapsFile.new()._build_default_map()

	_level.load_from_gamemaps(raw_map)
	Globals.map_data = raw_map

	_spawn_player()
	_spawn_enemies_from_map()
	Globals.game_state = Globals.GameState.PLAYING

func _spawn_player() -> void:
	for y in Globals.MAP_HEIGHT:
		for x in Globals.MAP_WIDTH:
			var tile := _level.get_tile(x, y)
			if tile == 0:
				Globals.player_pos = Vector2(
					(x + 0.5) * Globals.TILE_SIZE,
					(y + 0.5) * Globals.TILE_SIZE,
				)
				Globals.player_angle = 0.0
				return
	Globals.player_pos = Vector2(1000, 1000)
	Globals.player_angle = 0.0

func _spawn_enemies_from_map() -> void:
	_enemies.clear()
	var actor_map := {
		108: EnemySystem.EnemyType.GUARD,
		116: EnemySystem.EnemyType.GUARD,
		110: EnemySystem.EnemyType.SS,
		118: EnemySystem.EnemyType.SS,
		112: EnemySystem.EnemyType.OFFICER,
		120: EnemySystem.EnemyType.OFFICER,
		114: EnemySystem.EnemyType.MUTANT,
		122: EnemySystem.EnemyType.MUTANT,
		138: EnemySystem.EnemyType.DOG,
		140: EnemySystem.EnemyType.DOG,
		142: EnemySystem.EnemyType.HANS,
	}

	for y in Globals.MAP_HEIGHT:
		for x in Globals.MAP_WIDTH:
			var val := Globals.map_data[y * Globals.MAP_WIDTH + x]
			var tile := val & 0xFF
			var et := actor_map.get(tile, -1)
			if et >= 0:
				var ambush := (val & 0x8000) != 0
				var wx := (x + 0.5) * Globals.TILE_SIZE
				var wy := (y + 0.5) * Globals.TILE_SIZE
				_enemies.spawn(et, wx, wy, ambush)

func _process(delta: float) -> void:
	if Globals.game_state != Globals.GameState.PLAYING:
		return

	_handle_input(delta)
	_weapons.update(delta)
	_level.update_doors(delta)
	_enemies.update_all(delta, _level)

	if _weapons.is_firing():
		_try_fire()

	_enemy_attack_check(delta)
	_check_pickups()
	_render_frame()

var _enemy_attack_timer: float = 0.0

func _enemy_attack_check(delta: float) -> void:
	_enemy_attack_timer -= delta
	if _enemy_attack_timer > 0:
		return
	_enemy_attack_timer = 0.3

	for e in _enemies.get_enemies():
		if not e.alive or e.state != EnemySystem.EnemyState.ATTACK:
			continue
		var dist := e.world_pos.distance_to(Globals.player_pos)
		if dist < e.attack_range:
			Globals.player_health -= int(e.damage)
			if Globals.player_health <= 0:
				Globals.player_health = 0
				Globals.game_state = Globals.GameState.DEAD
			return

func _handle_input(delta: float) -> void:
	var move_speed := Globals.PLAYER_SPEED * delta
	var rot_speed := deg_to_rad(Globals.ROTATION_SPEED * delta)

	if _keys.get(KEY_W) or _keys.get(KEY_UP):
		_move_player(move_speed)
	if _keys.get(KEY_S) or _keys.get(KEY_DOWN):
		_move_player(-move_speed)

	if _keys.get(KEY_A):
		_strafe_player(-move_speed)
	if _keys.get(KEY_D):
		_strafe_player(move_speed)

	if _keys.get(KEY_LEFT):
		Globals.player_angle -= rot_speed
	if _keys.get(KEY_RIGHT):
		Globals.player_angle += rot_speed

	if _mouse_captured and abs(_mouse_delta) > 0.001:
		Globals.player_angle += _mouse_delta * Globals.MOUSE_SENSITIVITY
		_mouse_delta = 0.0

	if _just_pressed.get(KEY_SPACE) or _just_pressed.get(KEY_E):
		_try_open_door()

	if _just_pressed.get(KEY_1):
		_weapons.switch_to(WeaponSystem.WeaponType.KNIFE)
	if _just_pressed.get(KEY_2):
		_weapons.switch_to(WeaponSystem.WeaponType.PISTOL)
	if _just_pressed.get(KEY_3):
		_weapons.switch_to(WeaponSystem.WeaponType.MACHINE_GUN)
	if _just_pressed.get(KEY_4):
		_weapons.switch_to(WeaponSystem.WeaponType.CHAIN_GUN)

	if _keys.get(KEY_CTRL) or _keys.get(MOUSE_BUTTON_LEFT):
		_weapons.start_fire()
	else:
		_weapons.stop_fire()

	_just_pressed.clear()

func _move_player(speed: float) -> void:
	var new_x := Globals.player_pos.x + cos(Globals.player_angle) * speed
	var new_y := Globals.player_pos.y + sin(Globals.player_angle) * speed

	if not _level.is_wall(int(new_x / Globals.TILE_SIZE), int(Globals.player_pos.y / Globals.TILE_SIZE)):
		Globals.player_pos.x = new_x
	if not _level.is_wall(int(Globals.player_pos.x / Globals.TILE_SIZE), int(new_y / Globals.TILE_SIZE)):
		Globals.player_pos.y = new_y

func _strafe_player(speed: float) -> void:
	var strafe_angle := Globals.player_angle + deg_to_rad(90.0)
	var new_x := Globals.player_pos.x + cos(strafe_angle) * speed
	var new_y := Globals.player_pos.y + sin(strafe_angle) * speed

	if not _level.is_wall(int(new_x / Globals.TILE_SIZE), int(Globals.player_pos.y / Globals.TILE_SIZE)):
		Globals.player_pos.x = new_x
	if not _level.is_wall(int(Globals.player_pos.x / Globals.TILE_SIZE), int(new_y / Globals.TILE_SIZE)):
		Globals.player_pos.y = new_y

func _try_open_door() -> void:
	var px := int(Globals.player_pos.x / Globals.TILE_SIZE)
	var py := int(Globals.player_pos.y / Globals.TILE_SIZE)
	var check_positions := [
		Vector2i(px + 1, py),
		Vector2i(px - 1, py),
		Vector2i(px, py + 1),
		Vector2i(px, py - 1),
	]

	for cp in check_positions:
		if _level.is_door(cp.x, cp.y):
			var door := _level.get_door_at(cp.x, cp.y)
			if door and door.state == 0:
				if door.locked:
					var needed_key := 1 if door.key_required == 1 else 2
					if Globals.player_keys & needed_key:
						door.locked = false
						_level.trigger_door(cp.x, cp.y)
				else:
					_level.trigger_door(cp.x, cp.y)
				break

func _try_fire() -> void:
	var result := _weapons.try_fire()
	if not result["fired"]:
		return

	if result.get("hit_radius", 0) > 0:
		var hit := ProjectileSystem.check_melee_hit(
			Globals.player_pos, Globals.player_angle,
			_enemies.get_enemies(), result["hit_radius"], result["damage"]
		)
		if hit:
			_enemies.damage_enemy(hit, result["damage"])
	else:
		var hit_result := ProjectileSystem.fire_hitscan(
			Globals.player_pos, Globals.player_angle, 1000.0, _level
		)
		var hit_enemy: bool = false
		for e in _enemies.get_enemies():
			if not e.alive:
				continue
			var to_enemy := e.world_pos - Globals.player_pos
			if to_enemy.length() > 1000.0:
				continue
			var angle_to_enemy := atan2(to_enemy.y, to_enemy.x)
			var angle_diff := wrapf(angle_to_enemy - Globals.player_angle, -PI, PI)
			if abs(angle_diff) < deg_to_rad(8.0):
				var dist := to_enemy.length()
				if not hit_result["hit"] or dist < Globals.player_pos.distance_to(hit_result["position"]):
					_enemies.damage_enemy(e, result["damage"])
					hit_enemy = true
					break

func _check_pickups() -> void:
	var px := int(Globals.player_pos.x / Globals.TILE_SIZE)
	var py := int(Globals.player_pos.y / Globals.TILE_SIZE)
	var tile := _level.get_tile(px, py)

	if tile >= 126 and tile <= 137:
		var result := _pickups.try_pickup(tile)
		if result["collected"]:
			Globals.map_data[py * Globals.MAP_WIDTH + px] = 0

func _render_frame() -> void:
	var screen := Globals.screen_image
	screen.fill(Color(0.18, 0.18, 0.22))

	FloorCeilingRenderer.render_floor_ceiling(
		screen, Globals.map_data, Globals.z_buffer,
		Globals.player_pos, Globals.player_angle
	)

	WallRenderer.render_walls(
		screen, Globals.z_buffer, Globals.map_data,
		Globals.wall_textures, Globals.player_pos, Globals.player_angle
	)

	var sprites: Array = []
	for e in _enemies.get_enemies():
		if e.alive and e.sprite_index < Globals.sprite_images.size():
			sprites.append(Globals.sprite_images[e.sprite_index])
			_sprite_renderer.add_sprite(
				Globals.sprite_images[e.sprite_index],
				e.world_pos.x, e.world_pos.y
			)

	_sprite_renderer.render(
		screen, Globals.z_buffer,
		Globals.player_pos, Globals.player_angle
	)
	_sprite_renderer.clear()

	HUD.render(screen)

	Globals.screen_texture.update(screen)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			_just_pressed[event.keycode] = true
		_keys[event.keycode] = event.pressed

		if event.keycode == KEY_ESCAPE and event.pressed:
			if _mouse_captured:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				_mouse_captured = false
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				_mouse_captured = true

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not _mouse_captured:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
					_mouse_captured = true
				_keys[MOUSE_BUTTON_LEFT] = true
				_just_pressed[MOUSE_BUTTON_LEFT] = true
			else:
				_keys[MOUSE_BUTTON_LEFT] = false

	if event is InputEventMouseMotion and _mouse_captured:
		_mouse_delta += event.relative.x * 0.01