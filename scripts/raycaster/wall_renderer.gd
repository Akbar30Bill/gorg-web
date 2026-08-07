extends RefCounted
class_name WallRenderer

static func render_walls(
	screen: Image,
	z_buffer: Array,
	map: Array,
	wall_textures: Array,
	player_pos: Vector2,
	player_angle: float
) -> void:
	if wall_textures.is_empty():
		_draw_solid_walls(screen, z_buffer, map, player_pos, player_angle)
		return

	var plane := Vector2(cos(player_angle + deg_to_rad(90.0)), sin(player_angle + deg_to_rad(90.0)))
	var dir := Vector2(cos(player_angle), sin(player_angle))
	var tan_half := tan(deg_to_rad(Globals.HALF_FOV))

	for x in Globals.SCREEN_WIDTH:
		var camera_x := 2.0 * x / Globals.SCREEN_WIDTH - 1.0
		var ray_dir := Vector2(dir.x + plane.x * camera_x * tan_half, dir.y + plane.y * camera_x * tan_half)
		var ray_angle := atan2(ray_dir.y, ray_dir.x)

		var result := RaycastEngine.cast_ray(map, player_pos, ray_angle)
		z_buffer[x] = result["distance"]

		if not result["hit"]:
			continue

		var perp_dist := result["distance"] as float
		if perp_dist < 0.01:
			perp_dist = 0.01

		var line_height := int(Globals.SCREEN_HEIGHT / perp_dist)
		var draw_start := (Globals.SCREEN_HEIGHT - line_height) / 2
		var draw_end := draw_start + line_height

		var tile: int = result["tile"] as int
		var wall_x := result["wall_x"] as float
		var tex_x := int(wall_x * Globals.TILE_SIZE)

		if result["side"] == 1:
			tex_x = Globals.TILE_SIZE - tex_x - 1

		var tex_index := tile - 1
		if tex_index < 0 or tex_index >= wall_textures.size():
			_draw_column_color(screen, x, draw_start, draw_end, result["side"])
			continue

		var tex := wall_textures[tex_index] as Image
		_draw_textured_column(screen, x, draw_start, draw_end, tex, tex_x, line_height)

	var img_tex := ImageTexture.create_from_image(screen)


static func _draw_textured_column(screen: Image, x: int, draw_start: int, draw_end: int, tex: Image, tex_x: int, line_height: int) -> void:
	var tex_h := tex.get_height()
	var step := float(tex_h) / line_height
	var tex_pos := 0.0

	if draw_start < 0:
		tex_pos = -draw_start * step
		draw_start = 0

	var max_y := mini(draw_end, Globals.SCREEN_HEIGHT)

	for y in range(draw_start, max_y):
		var tex_y := int(tex_pos) % tex_h
		var pixel := tex.get_pixel(tex_x % tex.get_width(), tex_y)
		screen.set_pixel(x, y, pixel)
		tex_pos += step


static func _draw_solid_walls(screen: Image, z_buffer: Array, map: Array, player_pos: Vector2, player_angle: float) -> void:
	var plane := Vector2(cos(player_angle + deg_to_rad(90.0)), sin(player_angle + deg_to_rad(90.0)))
	var dir := Vector2(cos(player_angle), sin(player_angle))
	var tan_half := tan(deg_to_rad(Globals.HALF_FOV))

	for x in Globals.SCREEN_WIDTH:
		var camera_x := 2.0 * x / Globals.SCREEN_WIDTH - 1.0
		var ray_dir := Vector2(dir.x + plane.x * camera_x * tan_half, dir.y + plane.y * camera_x * tan_half)
		var ray_angle := atan2(ray_dir.y, ray_dir.x)

		var result := RaycastEngine.cast_ray(map, player_pos, ray_angle)
		z_buffer[x] = result["distance"]

		if not result["hit"]:
			continue

		var perp_dist := result["distance"] as float
		if perp_dist < 0.01:
			perp_dist = 0.01

		var line_height := int(Globals.SCREEN_HEIGHT / perp_dist)
		var draw_start := (Globals.SCREEN_HEIGHT - line_height) / 2
		var draw_end := draw_start + line_height

		_draw_column_color(screen, x, draw_start, draw_end, result["side"])


static func _draw_column_color(screen: Image, x: int, draw_start: int, draw_end: int, side: int) -> void:
	var color := Color(0.6, 0.3, 0.1) if side == 0 else Color(0.4, 0.2, 0.05)
	for y in range(maxi(0, draw_start), mini(draw_end, Globals.SCREEN_HEIGHT)):
		screen.set_pixel(x, y, color)