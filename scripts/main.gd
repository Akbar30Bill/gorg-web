extends Control

var vswap: WADParser.VSwapFile = null
var vgagraph: WADParser.VgaGraphFile = null
var gamemaps: WADParser.GameMapsFile = null

var _keys: Dictionary = {}
var _mouse_captured: bool = false
var _mouse_delta: float = 0.0

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

	_load_assets()
	_init_player()

func _load_assets() -> void:
	vswap = WADParser.load_vswap("res://assets/wolf3d/VSWAP.WL6")
	if vswap:
		var num_walls := mini(vswap.sprite_start, Globals.NUM_WALL_TEXTURES)
		for i in num_walls:
			var tex := vswap.load_wall_texture(i)
			Globals.wall_textures.append(tex)

	if Globals.wall_textures.is_empty():
		_generate_placeholder_textures()

	gamemaps = WADParser.load_gamemaps("res://assets/wolf3d/MAPHEAD.WL6", "res://assets/wolf3d/GAMEMAPS.WL6")
	if gamemaps:
		Globals.map_data = gamemaps.load_map(0)
	else:
		Globals.map_data = WADParser.GameMapsFile.new()._build_default_map()

	Globals.wad_loaded = vswap != null and gamemaps != null

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

func _init_player() -> void:
	if Globals.map_data.size() >= Globals.MAP_WIDTH * Globals.MAP_HEIGHT:
		for y in Globals.MAP_HEIGHT:
			for x in Globals.MAP_WIDTH:
				var tile := Globals.map_data[y * Globals.MAP_WIDTH + x] as int
				if tile == 0:
					Globals.player_pos = Vector2(
						(x + 0.5) * Globals.TILE_SIZE,
						(y + 0.5) * Globals.TILE_SIZE
					)
					Globals.player_angle = 0.0
					return
	Globals.player_pos = Vector2(
		(Globals.MAP_WIDTH / 2) * Globals.TILE_SIZE,
		(Globals.MAP_HEIGHT / 2) * Globals.TILE_SIZE
	)
	Globals.player_angle = 0.0

func _process(delta: float) -> void:
	_handle_input(delta)
	_render_frame()

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

func _move_player(speed: float) -> void:
	var new_x := Globals.player_pos.x + cos(Globals.player_angle) * speed
	var new_y := Globals.player_pos.y + sin(Globals.player_angle) * speed

	if not _is_wall(new_x, Globals.player_pos.y):
		Globals.player_pos.x = new_x
	if not _is_wall(Globals.player_pos.x, new_y):
		Globals.player_pos.y = new_y

func _strafe_player(speed: float) -> void:
	var strafe_angle := Globals.player_angle + deg_to_rad(90.0)
	var new_x := Globals.player_pos.x + cos(strafe_angle) * speed
	var new_y := Globals.player_pos.y + sin(strafe_angle) * speed

	if not _is_wall(new_x, Globals.player_pos.y):
		Globals.player_pos.x = new_x
	if not _is_wall(Globals.player_pos.x, new_y):
		Globals.player_pos.y = new_y

func _is_wall(px: float, py: float) -> bool:
	var map_x := int(px / Globals.TILE_SIZE)
	var map_y := int(py / Globals.TILE_SIZE)

	if map_x < 0 or map_x >= Globals.MAP_WIDTH or map_y < 0 or map_y >= Globals.MAP_HEIGHT:
		return true

	var tile := Globals.map_data[map_y * Globals.MAP_WIDTH + map_x] as int
	return tile > 0 and tile < 64

func _render_frame() -> void:
	Globals.screen_image.fill(Color(0.18, 0.18, 0.22))  # dark gray-blue background

	FloorCeilingRenderer.render_floor_ceiling(
		Globals.screen_image,
		Globals.map_data,
		Globals.z_buffer,
		Globals.player_pos,
		Globals.player_angle
	)

	WallRenderer.render_walls(
		Globals.screen_image,
		Globals.z_buffer,
		Globals.map_data,
		Globals.wall_textures,
		Globals.player_pos,
		Globals.player_angle
	)

	Globals.screen_texture.update(Globals.screen_image)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		_keys[event.keycode] = event.pressed
		if event.keycode == KEY_ESCAPE and event.pressed:
			if _mouse_captured:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				_mouse_captured = false
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				_mouse_captured = true

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not _mouse_captured:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				_mouse_captured = true

	if event is InputEventMouseMotion and _mouse_captured:
		_mouse_delta += event.relative.x * 0.01