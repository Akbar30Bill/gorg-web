extends Control

var _level: LevelManager = null
var _weapons: WeaponSystem = null
var _enemies: EnemySystem = null
var _sprite_renderer: SpriteRenderer = null
var _pickups: PickupSystem = null
var _menu: MenuSystem = null
var _intermission: Intermission = null
var _sound: SoundManager = null
var _vswap: WADParser.VSwapFile = null
var _gamemaps: WADParser.GameMapsFile = null

var _keys: Dictionary = {}
var _mouse_captured: bool = false
var _mouse_delta: float = 0.0
var _just_pressed: Dictionary = {}
var _local_game_state: int = Globals.GameState.TITLE
var _enemy_attack_timer: float = 0.0
var _death_timer: float = 0.0

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
	_menu = MenuSystem.new()
	_intermission = Intermission.new()
	_sound = SoundManager.new()

	_sound.setup()
	_load_assets()
	_menu.enter_state(MenuSystem.MenuState.TITLE)

func _load_assets() -> void:
	_vswap = WADParser.load_vswap("res://assets/wolf3d/VSWAP.WL6")
	if _vswap:
		var num_walls := mini(_vswap.sprite_start, Globals.NUM_WALL_TEXTURES)
		for i in num_walls:
			Globals.wall_textures.append(_vswap.load_wall_texture(i))
		for i in range(_vswap.sprite_start, mini(_vswap.sprite_start + 50, _vswap.offsets.size())):
			var img := _vswap.load_sprite(i - _vswap.sprite_start)
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
				img.set_pixel(x, y, Color(r * (0.7 + 0.3 * sin((x + y) * 0.1 + i)), g * (0.7 + 0.3 * sin((x + y) * 0.13 + i)), b * (0.7 + 0.3 * sin((x + y) * 0.17 + i))))
		Globals.wall_textures.append(img)

func start_new_game() -> void:
	Globals.current_level = 0
	Globals.player_health = 100
	Globals.player_ammo = 8
	Globals.player_lives = 3
	Globals.player_score = 0
	Globals.player_keys = 0
	Globals.player_weapon = WeaponSystem.WeaponType.PISTOL
	_load_level()
	_local_game_state = Globals.GameState.PLAYING
	Globals.game_state = Globals.GameState.PLAYING

func _load_level() -> void:
	_enemies.clear()
	var raw_map: Array
	if _gamemaps:
		raw_map = _gamemaps.load_map(Globals.current_level)
	else:
		raw_map = WADParser.GameMapsFile.new()._build_default_map()

	_level.load_from_gamemaps(raw_map)
	Globals.map_data = raw_map
	_spawn_player()
	_spawn_enemies_from_map()

func _spawn_player() -> void:
	for y in Globals.MAP_HEIGHT:
		for x in Globals.MAP_WIDTH:
			if _level.get_tile(x, y) == 0:
				Globals.player_pos = Vector2((x + 0.5) * Globals.TILE_SIZE, (y + 0.5) * Globals.TILE_SIZE)
				Globals.player_angle = 0.0
				return
	Globals.player_pos = Vector2(1000, 1000)
	Globals.player_angle = 0.0

func _spawn_enemies_from_map() -> void:
	var actor_map := {
		108: EnemySystem.EnemyType.GUARD, 116: EnemySystem.EnemyType.GUARD,
		110: EnemySystem.EnemyType.SS, 118: EnemySystem.EnemyType.SS,
		112: EnemySystem.EnemyType.OFFICER, 120: EnemySystem.EnemyType.OFFICER,
		114: EnemySystem.EnemyType.MUTANT, 122: EnemySystem.EnemyType.MUTANT,
		138: EnemySystem.EnemyType.DOG, 140: EnemySystem.EnemyType.DOG,
		142: EnemySystem.EnemyType.HANS,
	}
	for y in Globals.MAP_HEIGHT:
		for x in Globals.MAP_WIDTH:
			var val: int = Globals.map_data[y * Globals.MAP_WIDTH + x]
			var tile: int = val & 0xFF
			var et: int = actor_map.get(tile, -1)
			if et >= 0:
				var ambush: bool = (val & 0x8000) != 0
				_enemies.spawn(et, (x + 0.5) * Globals.TILE_SIZE, (y + 0.5) * Globals.TILE_SIZE, ambush)

func _process(delta: float) -> void:
	_sound.process_audio()

	match _local_game_state:
		Globals.GameState.TITLE:
			_process_title(delta)
		Globals.GameState.PLAYING:
			_process_playing(delta)
		Globals.GameState.DEAD:
			_process_dead(delta)
		Globals.GameState.INTERMISSION:
			_process_intermission(delta)

func _process_title(delta: float) -> void:
	_menu.update(delta)

	if _just_pressed.get(KEY_UP) or _just_pressed.get(KEY_W):
		_menu.move_up()
	if _just_pressed.get(KEY_DOWN) or _just_pressed.get(KEY_S):
		_menu.move_down()
	if _just_pressed.get(KEY_ENTER) or _just_pressed.get(KEY_SPACE):
		var result: Dictionary = _menu.confirm_action()
		match result.get("action", ""):
			"new_game":
				start_new_game()
			"load":
				if SaveManager.load_game(result.get("slot", 0)):
					_load_level()
					_local_game_state = Globals.GameState.PLAYING
					Globals.game_state = Globals.GameState.PLAYING
			"quit":
				get_tree().quit()
	if _just_pressed.get(KEY_ESCAPE):
		if _menu.state == MenuSystem.MenuState.LOAD_GAME or _menu.state == MenuSystem.MenuState.CONTROLS:
			_menu.enter_state(MenuSystem.MenuState.MAIN)
		elif _menu.state == MenuSystem.MenuState.TITLE:
			_menu.enter_state(MenuSystem.MenuState.MAIN)

	_just_pressed.clear()
	_render_menu()

func _process_playing(delta: float) -> void:
	_handle_game_input(delta)
	_weapons.update(delta)
	_level.update_doors(delta)
	_enemies.update_all(delta, _level)

	if _weapons.is_firing():
		_try_fire()

	_enemy_attack_check(delta)
	_check_pickups()
	_check_elevator()
	_process_weapon_sound(delta)
	_render_game_frame()

func _process_dead(delta: float) -> void:
	_death_timer += delta
	if _death_timer > 3.0 and (_just_pressed.get(KEY_ENTER) or _just_pressed.get(KEY_SPACE)):
		_just_pressed.clear()
		if Globals.player_lives > 1:
			Globals.player_lives -= 1
			Globals.player_health = 100
			_load_level()
			_local_game_state = Globals.GameState.PLAYING
			Globals.game_state = Globals.GameState.PLAYING
			_death_timer = 0.0
		else:
			_menu.enter_state(MenuSystem.MenuState.MAIN)
			_local_game_state = Globals.GameState.TITLE
			Globals.game_state = Globals.GameState.TITLE
		return

	_just_pressed.clear()
	var screen := Globals.screen_image
	screen.fill(Color(0.6, 0.1, 0.1))
	HUD._draw_text(screen, "YOU DIED", (Globals.SCREEN_WIDTH - 48) / 2, 80, Color(1.0, 1.0, 1.0))
	if _death_timer > 3.0:
		var hint := "PRESS ENTER TO CONTINUE"
		HUD._draw_text(screen, hint, (Globals.SCREEN_WIDTH - len(hint) * 6) / 2, 120, Color(0.8, 0.6, 0.6))
	Globals.screen_texture.update(screen)

func _process_weapon_sound(_delta: float) -> void:
	pass

func _handle_game_input(delta: float) -> void:
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
	var nx := Globals.player_pos.x + cos(Globals.player_angle) * speed
	var ny := Globals.player_pos.y + sin(Globals.player_angle) * speed
	var tx := int(nx / Globals.TILE_SIZE)
	var ty := int(ny / Globals.TILE_SIZE)
	var px := int(Globals.player_pos.x / Globals.TILE_SIZE)
	var py := int(Globals.player_pos.y / Globals.TILE_SIZE)

	var blocked_x := _level.is_wall(tx, py)
	var blocked_y := _level.is_wall(px, ty)

	if blocked_x:
		_try_pushwall(tx, py, nx > Globals.player_pos.x)
	if blocked_y:
		_try_pushwall(px, ty, ny > Globals.player_pos.y)

	if not blocked_x:
		Globals.player_pos.x = nx
	if not blocked_y:
		Globals.player_pos.y = ny

func _strafe_player(speed: float) -> void:
	var sa := Globals.player_angle + deg_to_rad(90.0)
	var nx := Globals.player_pos.x + cos(sa) * speed
	var ny := Globals.player_pos.y + sin(sa) * speed
	var tx := int(nx / Globals.TILE_SIZE)
	var ty := int(ny / Globals.TILE_SIZE)
	var px := int(Globals.player_pos.x / Globals.TILE_SIZE)
	var py := int(Globals.player_pos.y / Globals.TILE_SIZE)

	var blocked_x := _level.is_wall(tx, py)
	var blocked_y := _level.is_wall(px, ty)

	if blocked_x:
		_try_pushwall(tx, py, nx > Globals.player_pos.x)
	if blocked_y:
		_try_pushwall(px, ty, ny > Globals.player_pos.y)

	if not blocked_x:
		Globals.player_pos.x = nx
	if not blocked_y:
		Globals.player_pos.y = ny

func _try_pushwall(tx: int, ty: int, pushing_right: bool) -> void:
	var tile: int = _level.get_tile(tx, ty)
	if tile < 64 or tile > 67:
		return
	var dir := tile - 64
	var dir_map := { 0: 1, 1: 2, 2: 3, 3: 0 }
	var needed_dir: int
	if pushing_right:
		needed_dir = 1
	else:
		needed_dir = 3
	if dir_map[dir] == needed_dir or dir_map[needed_dir] == dir:
		pass
	if _level.push_wall(tx, ty, dir):
		_sound.play_secret()

func _try_open_door() -> void:
	var px := int(Globals.player_pos.x / Globals.TILE_SIZE)
	var py := int(Globals.player_pos.y / Globals.TILE_SIZE)
	for cp in [Vector2i(px + 1, py), Vector2i(px - 1, py), Vector2i(px, py + 1), Vector2i(px, py - 1)]:
		if _level.is_door(cp.x, cp.y):
			var door := _level.get_door_at(cp.x, cp.y)
			if door and door.state == 0:
				var can_open := true
				if door.locked:
					var needed := 1 if door.key_required == 1 else 2
					if Globals.player_keys & needed:
						door.locked = false
					else:
						can_open = false
				if can_open:
					_level.trigger_door(cp.x, cp.y)
					_sound.play_door_open()
				break

func _try_fire() -> void:
	var result: Dictionary = _weapons.try_fire()
	if not result["fired"]:
		return

	if result.get("hit_radius", 0) > 0:
		var hit: EnemySystem.EnemyData = ProjectileSystem.check_melee_hit(
			Globals.player_pos, Globals.player_angle,
			_enemies.get_enemies(), result["hit_radius"], result["damage"]
		)
		if hit:
			if _enemies.damage_enemy(hit, result["damage"]):
				_sound.play_enemy_death()
			else:
				_sound.play_enemy_hurt()
	else:
		_sound.play_pistol()
		var hr: Dictionary = ProjectileSystem.fire_hitscan(Globals.player_pos, Globals.player_angle, 1000.0, _level)
		for e in _enemies.get_enemies():
			if not e.alive:
				continue
			var to_e: Vector2 = e.world_pos - Globals.player_pos
			if to_e.length() > 1000.0:
				continue
			var ad := wrapf(atan2(to_e.y, to_e.x) - Globals.player_angle, -PI, PI)
			if abs(ad) < deg_to_rad(8.0):
				var dist := to_e.length()
				if not hr["hit"] or dist < Globals.player_pos.distance_to(hr["position"]):
					if _enemies.damage_enemy(e, result["damage"]):
						_sound.play_enemy_death()
					else:
						_sound.play_enemy_hurt()
					break

func _check_pickups() -> void:
	var px: int = int(Globals.player_pos.x / Globals.TILE_SIZE)
	var py: int = int(Globals.player_pos.y / Globals.TILE_SIZE)
	var tile: int = _level.get_tile(px, py)
	if tile >= 126 and tile <= 137:
		var p_result: Dictionary = _pickups.try_pickup(tile)
		if p_result["collected"]:
			Globals.map_data[py * Globals.MAP_WIDTH + px] = 0
			_sound.play_pickup()

func _check_elevator() -> void:
	var px: int = int(Globals.player_pos.x / Globals.TILE_SIZE)
	var py: int = int(Globals.player_pos.y / Globals.TILE_SIZE)
	var tile: int = _level.get_tile(px, py)
	if tile == 0x15:
		var alive_count := 0
		for e in _enemies.get_enemies():
			if e.alive:
				alive_count += 1
		if alive_count == 0:
			_local_game_state = Globals.GameState.INTERMISSION
			Globals.game_state = Globals.GameState.INTERMISSION
			_intermission.start()

func _process_intermission(delta: float) -> void:
	_intermission.update(delta)
	if _just_pressed.get(KEY_ENTER) or _just_pressed.get(KEY_SPACE):
		if _intermission.can_continue():
			Globals.current_level += 1
			if Globals.current_level >= 10:
				_menu.enter_state(MenuSystem.MenuState.MAIN)
				_local_game_state = Globals.GameState.TITLE
				Globals.game_state = Globals.GameState.TITLE
			else:
				_load_level()
				_local_game_state = Globals.GameState.PLAYING
				Globals.game_state = Globals.GameState.PLAYING
	_just_pressed.clear()
	_intermission.render(Globals.screen_image)
	Globals.screen_texture.update(Globals.screen_image)

func _enemy_attack_check(delta: float) -> void:
	_enemy_attack_timer -= delta
	if _enemy_attack_timer > 0:
		return
	_enemy_attack_timer = 0.3

	for e in _enemies.get_enemies():
		if not e.alive or e.state != EnemySystem.EnemyState.ATTACK:
			continue
		if e.world_pos.distance_to(Globals.player_pos) < e.attack_range:
			Globals.player_health -= int(e.damage)
			_sound.play_player_hurt()
			if Globals.player_health <= 0:
				Globals.player_health = 0
				_local_game_state = Globals.GameState.DEAD
				Globals.game_state = Globals.GameState.DEAD
				_death_timer = 0.0
			return

func _render_game_frame() -> void:
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

	_sprite_renderer.clear()
	for e in _enemies.get_enemies():
		if e.alive and e.sprite_index < Globals.sprite_images.size():
			_sprite_renderer.add_sprite(
				Globals.sprite_images[e.sprite_index],
				e.world_pos.x, e.world_pos.y
			)

	_sprite_renderer.render(screen, Globals.z_buffer, Globals.player_pos, Globals.player_angle)

	HUD.render(screen)
	Globals.screen_texture.update(screen)

func _render_menu() -> void:
	_menu.render(Globals.screen_image)
	Globals.screen_texture.update(Globals.screen_image)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			_just_pressed[event.keycode] = true
		_keys[event.keycode] = event.pressed

		if event.keycode == KEY_ESCAPE and event.pressed:
			if _local_game_state == Globals.GameState.PLAYING:
				if _mouse_captured:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
					_mouse_captured = false

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _local_game_state == Globals.GameState.PLAYING and not _mouse_captured:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
					_mouse_captured = true
				_keys[MOUSE_BUTTON_LEFT] = true
				_just_pressed[MOUSE_BUTTON_LEFT] = true
			else:
				_keys[MOUSE_BUTTON_LEFT] = false

	if event is InputEventMouseMotion and _mouse_captured:
		_mouse_delta += event.relative.x * 0.01