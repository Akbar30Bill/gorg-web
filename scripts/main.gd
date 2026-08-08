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
var _weapon_renderer: WeaponRenderer = null
var _weapon_sound_timer: float = 0.0

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
	_weapon_renderer = WeaponRenderer.new()
	_menu.enter_state(MenuSystem.MenuState.MAIN)

func _load_assets() -> void:
	Globals.vgagraph = WADParser.load_vgagraph("res://assets/wolf3d/VGAGRAPH.WL6")
	_vswap = WADParser.load_vswap("res://assets/wolf3d/VSWAP.WL6")
	if _vswap:
		var num_walls: int = _vswap.sprite_start
		for i: int in range(num_walls):
			Globals.wall_textures.append(_vswap.load_wall_texture(i))
		var num_sprites: int = _vswap.sound_start - _vswap.sprite_start
		for i: int in range(_vswap.sprite_start, _vswap.offsets.size()):
			var img: Image = _vswap.load_sprite(i - _vswap.sprite_start)
			if img:
				Globals.sprite_images.append(img)
		for i: int in range(mini(num_sprites, 42)):
			var img: Image = _vswap.load_sprite(i)
			if img.get_width() > 0 and img.get_height() > 0:
				Globals.face_sprites.append(img)
	if Globals.wall_textures.is_empty():
		_generate_placeholder_textures()

	var total_sprites: int = Globals.sprite_images.size()
	var weapon_count: int = mini(25, total_sprites)
	if weapon_count > 0:
		for i: int in range(total_sprites - weapon_count, total_sprites):
			Globals.weapon_sprites.append(Globals.sprite_images[i])

	_gamemaps = WADParser.load_gamemaps("res://assets/wolf3d/MAPHEAD.WL6", "res://assets/wolf3d/GAMEMAPS.WL6")
	Globals.wad_loaded = _vswap != null and _gamemaps != null

func _generate_placeholder_textures() -> void:
	for i: int in range(Globals.NUM_WALL_TEXTURES):
		var img := Image.create(Globals.TILE_SIZE, Globals.TILE_SIZE, false, Image.FORMAT_RGBA8)
		for x: int in range(Globals.TILE_SIZE):
			for y: int in range(Globals.TILE_SIZE):
				var r: float = float(x) / Globals.TILE_SIZE
				var g: float = float(y) / Globals.TILE_SIZE
				var b: float = float((x ^ y) & 0x3F) / 64.0
				img.set_pixel(x, y, Color(r * (0.7 + 0.3 * sin((x + y) * 0.1 + i)), g * (0.7 + 0.3 * sin((x + y) * 0.13 + i)), b * (0.7 + 0.3 * sin((x + y) * 0.17 + i))))
		Globals.wall_textures.append(img)

func start_new_game() -> void:
	Globals.current_level = 0
	Globals.player_health = 100
	Globals.player_ammo = 8
	Globals.player_lives = 3
	Globals.player_score = 0
	Globals.player_keys = 0
	Globals.player_weapon = Globals.WeaponType.PISTOL
	_load_level()
	_local_game_state = Globals.GameState.PLAYING
	Globals.game_state = Globals.GameState.PLAYING

func _load_level() -> void:
	_enemies.clear()
	var result: Dictionary
	if _gamemaps:
		result = _gamemaps.load_map(Globals.current_level)
	else:
		var default_map: Array = WADParser.GameMapsFile.new()._build_default_map()
		result = {"plane0": default_map, "plane1": [], "plane2": []}

	_level.load_from_gamemaps(result)
	Globals.map_data = result.get("plane0", [])
	_spawn_player()
	_spawn_enemies_from_map()

func _spawn_player() -> void:
	for y: int in range(Globals.MAP_HEIGHT):
		for x: int in range(Globals.MAP_WIDTH):
			var tile: int = _level.get_object_tile(x, y)
			if tile >= 19 and tile <= 22:
				Globals.player_pos.x = (x + 0.5) * Globals.TILE_SIZE
				Globals.player_pos.y = (y + 0.5) * Globals.TILE_SIZE
				match tile:
					19: Globals.player_angle = -PI / 2.0
					20: Globals.player_angle = 0.0
					21: Globals.player_angle = PI / 2.0
					22: Globals.player_angle = PI
				return
	Globals.player_pos.x = 1000
	Globals.player_pos.y = 1000
	Globals.player_angle = 0.0

func _spawn_enemies_from_map() -> void:
	var actor_map: Dictionary = {
		108: EnemySystem.EnemyType.GUARD, 116: EnemySystem.EnemyType.GUARD,
		110: EnemySystem.EnemyType.OFFICER, 118: EnemySystem.EnemyType.OFFICER,
		112: EnemySystem.EnemyType.SS, 120: EnemySystem.EnemyType.SS,
		114: EnemySystem.EnemyType.MUTANT, 122: EnemySystem.EnemyType.MUTANT,
		138: EnemySystem.EnemyType.DOG, 140: EnemySystem.EnemyType.DOG,
		142: EnemySystem.EnemyType.HANS,
	}
	var plane1: Array = _level.get_plane1()
	if plane1.is_empty():
		return
	for y: int in range(Globals.MAP_HEIGHT):
		for x: int in range(Globals.MAP_WIDTH):
			var val: int = plane1[y * Globals.MAP_WIDTH + x]
			var tile: int = val & 0xFF
			var et: int = actor_map.get(tile, -1)
			if et >= 0:
				var ambush: bool = (val & LevelManager.AMBUSH_FLAG) != 0
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
	HUD.update(delta)
	_handle_game_input(delta)
	_weapons.update(delta)
	_level.update_doors(delta)
	_enemies.update_all(delta, _level)

	if _weapons._is_firing:
		_try_fire()

	_weapon_renderer.update(delta, Globals.player_is_moving)

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
	var screen: Image = Globals.screen_image
	screen.fill(Color(0.6, 0.1, 0.1))
	HUD._old_draw_text(screen, "YOU DIED", (Globals.SCREEN_WIDTH - 48) / 2, 80, Color(1.0, 1.0, 1.0))
	if _death_timer > 3.0:
		var hint: String = "PRESS ENTER TO CONTINUE"
		HUD._old_draw_text(screen, hint, (Globals.SCREEN_WIDTH - len(hint) * 6) / 2, 120, Color(0.8, 0.6, 0.6))
	Globals.screen_texture.update(screen)

func _process_weapon_sound(delta: float) -> void:
	if not _weapons.is_firing():
		return
	_weapon_sound_timer -= delta
	if _weapon_sound_timer > 0.0:
		return
	match Globals.player_weapon:
		Globals.WeaponType.MACHINE_GUN, Globals.WeaponType.CHAIN_GUN:
			_sound.play_machine_gun()
			_weapon_sound_timer = 0.06

func _handle_game_input(delta: float) -> void:
	var move_speed: float = Globals.PLAYER_SPEED * delta
	var rot_speed: float = deg_to_rad(Globals.ROTATION_SPEED * delta)

	Globals.player_is_moving = false

	if _keys.get(KEY_W) or _keys.get(KEY_UP):
		_move_player(move_speed)
		Globals.player_is_moving = true
	if _keys.get(KEY_S) or _keys.get(KEY_DOWN):
		_move_player(-move_speed)
		Globals.player_is_moving = true
	if _keys.get(KEY_A):
		_strafe_player(-move_speed)
		Globals.player_is_moving = true
	if _keys.get(KEY_D):
		_strafe_player(move_speed)
		Globals.player_is_moving = true
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
		_weapons.switch_to(Globals.WeaponType.KNIFE)
	if _just_pressed.get(KEY_2):
		_weapons.switch_to(Globals.WeaponType.PISTOL)
	if _just_pressed.get(KEY_3):
		_weapons.switch_to(Globals.WeaponType.MACHINE_GUN)
	if _just_pressed.get(KEY_4):
		_weapons.switch_to(Globals.WeaponType.CHAIN_GUN)

	if _keys.get(KEY_CTRL) or _keys.get(MOUSE_BUTTON_LEFT):
		_weapons.start_fire()
	else:
		_weapons.stop_fire()

	_just_pressed.clear()

func _move_player(speed: float) -> void:
	var nx: float = Globals.player_pos.x + cos(Globals.player_angle) * speed
	var ny: float = Globals.player_pos.y + sin(Globals.player_angle) * speed
	var tx: int = int(nx / Globals.TILE_SIZE)
	var ty: int = int(ny / Globals.TILE_SIZE)
	var px: int = int(Globals.player_pos.x / Globals.TILE_SIZE)
	var py: int = int(Globals.player_pos.y / Globals.TILE_SIZE)

	var blocked_x: bool = _level.is_wall(tx, py)
	var blocked_y: bool = _level.is_wall(px, ty)

	if blocked_x:
		_try_pushwall(tx, py, 1 if nx > Globals.player_pos.x else 3)
	if blocked_y:
		_try_pushwall(px, ty, 2 if ny > Globals.player_pos.y else 0)

	if not blocked_x:
		Globals.player_pos.x = nx
	if not blocked_y:
		Globals.player_pos.y = ny

func _strafe_player(speed: float) -> void:
	var sa: float = Globals.player_angle + deg_to_rad(90.0)
	var nx: float = Globals.player_pos.x + cos(sa) * speed
	var ny: float = Globals.player_pos.y + sin(sa) * speed
	var tx: int = int(nx / Globals.TILE_SIZE)
	var ty: int = int(ny / Globals.TILE_SIZE)
	var px: int = int(Globals.player_pos.x / Globals.TILE_SIZE)
	var py: int = int(Globals.player_pos.y / Globals.TILE_SIZE)

	var blocked_x: bool = _level.is_wall(tx, py)
	var blocked_y: bool = _level.is_wall(px, ty)

	if blocked_x:
		_try_pushwall(tx, py, 1 if nx > Globals.player_pos.x else 3)
	if blocked_y:
		_try_pushwall(px, ty, 2 if ny > Globals.player_pos.y else 0)

	if not blocked_x:
		Globals.player_pos.x = nx
	if not blocked_y:
		Globals.player_pos.y = ny

func _try_pushwall(tx: int, ty: int, push_dir: int) -> void:
	var tile: int = _level.get_tile(tx, ty)
	if tile <= 0 or tile > LevelManager.WALL_TILE_END:
		return
	if _level.push_wall(tx, ty, push_dir):
		_sound.play_secret()

func _try_open_door() -> void:
	var px: int = int(Globals.player_pos.x / Globals.TILE_SIZE)
	var py: int = int(Globals.player_pos.y / Globals.TILE_SIZE)
	for cp: Vector2i in [Vector2i(px + 1, py), Vector2i(px - 1, py), Vector2i(px, py + 1), Vector2i(px, py - 1)]:
		if _level.is_door(cp.x, cp.y):
			var door: LevelManager.DoorData = _level.get_door_at(cp.x, cp.y)
			if door and door.state == 0:
				var can_open: bool = true
				if door.locked:
					var needed: int = 1 if door.key_required == 1 else 2
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

	_weapon_renderer.start_fire_animation()

	if result.get("hit_radius", 0) > 0:
		var hit: Variant = ProjectileSystem.check_melee_hit(
			Globals.player_pos, Globals.player_angle,
			_enemies.get_enemies(), result["hit_radius"], result["damage"]
		)
		if hit:
			if _enemies.damage_enemy(hit, result["damage"]):
				_sound.play_enemy_death()
			else:
				_sound.play_enemy_hurt()
	else:
		match Globals.player_weapon:
			Globals.WeaponType.PISTOL:
				_sound.play_pistol()
			Globals.WeaponType.MACHINE_GUN, Globals.WeaponType.CHAIN_GUN:
				_sound.play_machine_gun()
		var hr: Dictionary = ProjectileSystem.fire_hitscan(Globals.player_pos, Globals.player_angle, 1000.0, _level)
		for e: EnemySystem.EnemyData in _enemies.get_enemies():
			if not e.alive:
				continue
			var to_e: Vector2 = e.world_pos - Globals.player_pos
			if to_e.length() > 1000.0:
				continue
			var ad: float = wrapf(atan2(to_e.y, to_e.x) - Globals.player_angle, -PI, PI)
			if abs(ad) < deg_to_rad(8.0):
				var dist: float = to_e.length()
				if not hr["hit"] or dist < Globals.player_pos.distance_to(hr["position"]):
					if _enemies.damage_enemy(e, result["damage"]):
						_sound.play_enemy_death()
					else:
						_sound.play_enemy_hurt()
					break

func _check_pickups() -> void:
	var px: int = int(Globals.player_pos.x / Globals.TILE_SIZE)
	var py: int = int(Globals.player_pos.y / Globals.TILE_SIZE)
	var tile: int = _level.get_object_tile(px, py)
	if tile >= 43 and tile <= 57:
		var p_result: Dictionary = _pickups.try_pickup(tile)
		if p_result["collected"]:
			var plane1: Array = _level.get_plane1()
			if not plane1.is_empty():
				plane1[py * Globals.MAP_WIDTH + px] = 0
			_sound.play_pickup()
			if p_result.get("type", -1) == PickupSystem.PickupType.HEALTH:
				HUD.face_on_heal()

func _check_elevator() -> void:
	var px: int = int(Globals.player_pos.x / Globals.TILE_SIZE)
	var py: int = int(Globals.player_pos.y / Globals.TILE_SIZE)
	var tile: int = _level.get_object_tile(px, py)
	if tile == LevelManager.ELEVATOR_TILE:
		var alive_count: int = 0
		for e: EnemySystem.EnemyData in _enemies.get_enemies():
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

	for e: EnemySystem.EnemyData in _enemies.get_enemies():
		if not e.alive or e.state != EnemySystem.EnemyState.ATTACK:
			continue
		if e.world_pos.distance_to(Globals.player_pos) < e.attack_range:
			Globals.player_health -= int(e.damage)
			_sound.play_player_hurt()
			HUD.face_on_hurt()
			if Globals.player_health <= 0:
				Globals.player_health = 0
				_local_game_state = Globals.GameState.DEAD
				Globals.game_state = Globals.GameState.DEAD
				_death_timer = 0.0
			return

func _render_game_frame() -> void:
	var screen: Image = Globals.screen_image
	screen.fill(Color(0.18, 0.18, 0.22))

	var level_map: Array = _level.get_map()

	FloorCeilingRenderer.render_floor_ceiling(
		screen, level_map, Globals.z_buffer,
		Globals.player_pos, Globals.player_angle
	)

	WallRenderer.render_walls(
		screen, Globals.z_buffer, level_map,
		Globals.wall_textures, Globals.player_pos, Globals.player_angle
	)

	_sprite_renderer.clear()
	for e: EnemySystem.EnemyData in _enemies.get_enemies():
		if e.alive and e.sprite_index < Globals.sprite_images.size():
			_sprite_renderer.add_sprite(
				Globals.sprite_images[e.sprite_index],
				e.world_pos.x, e.world_pos.y
			)

	_sprite_renderer.render(screen, Globals.z_buffer, Globals.player_pos, Globals.player_angle)

	_weapon_renderer.render(screen)

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