extends RefCounted
class_name FloorCeilingRenderer

static func render_floor_ceiling(screen: Image, map: Array, z_buffer: Array, player_pos: Vector2, player_angle: float) -> void:
	var ceiling_color := Color(0.2, 0.2, 0.25)
	var floor_color := Color(0.3, 0.3, 0.3)

	var dir := Vector2(cos(player_angle), sin(player_angle))
	var plane := Vector2(cos(player_angle + deg_to_rad(90.0)), sin(player_angle + deg_to_rad(90.0)))

	for y in Globals.SCREEN_HEIGHT:
		var is_ceiling := y < Globals.SCREEN_HEIGHT / 2

		var p: float
		if is_ceiling:
			p = float(Globals.SCREEN_HEIGHT) / (Globals.SCREEN_HEIGHT - 2.0 * y)
		else:
			p = float(Globals.SCREEN_HEIGHT) / (2.0 * y - Globals.SCREEN_HEIGHT)

		if p <= 0:
			continue

		for x in Globals.SCREEN_WIDTH:
			var ray_dir_x0 := dir.x - plane.x
			var ray_dir_y0 := dir.y - plane.y
			var ray_dir_x1 := dir.x + plane.x
			var ray_dir_y1 := dir.y + plane.y

			var camera_x := 2.0 * x / Globals.SCREEN_WIDTH - 1.0
			var ray_dir_x := ray_dir_x0 + (ray_dir_x1 - ray_dir_x0) * (camera_x + 1.0) * 0.5
			var ray_dir_y := ray_dir_y0 + (ray_dir_y1 - ray_dir_y0) * (camera_x + 1.0) * 0.5

			var floor_x := player_pos.x / Globals.TILE_SIZE + p * ray_dir_x
			var floor_y := player_pos.y / Globals.TILE_SIZE + p * ray_dir_y

			var map_x := int(floor(floor_x))
			var map_y := int(floor(floor_y))

			if map_x < 0 or map_x >= Globals.MAP_WIDTH or map_y < 0 or map_y >= Globals.MAP_HEIGHT:
				if is_ceiling:
					screen.set_pixel(x, y, ceiling_color)
				else:
					screen.set_pixel(x, y, floor_color)
				continue

			var tile := map[map_y * Globals.MAP_WIDTH + map_x] as int
			if tile == 0:
				if is_ceiling:
					screen.set_pixel(x, y, ceiling_color)
				else:
					screen.set_pixel(x, y, floor_color)
			else:
				if is_ceiling:
					screen.set_pixel(x, y, ceiling_color)
				else:
					screen.set_pixel(x, y, floor_color)