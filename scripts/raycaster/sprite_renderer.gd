extends RefCounted
class_name SpriteRenderer

const MAX_VISIBLE_SPRITES := 128

class Sprite:
	var image: Image
	var world_pos: Vector2
	var visible: bool

var _sprites: Array[Sprite] = []

func clear() -> void:
	_sprites.clear()

func add_sprite(img: Image, world_x: float, world_y: float) -> void:
	var s := Sprite.new()
	s.image = img
	s.world_pos = Vector2(world_x, world_y)
	s.visible = true
	_sprites.append(s)

func render(screen: Image, z_buffer: Array, player_pos: Vector2, player_angle: float) -> void:
	if _sprites.is_empty():
		return

	var dir := Vector2(cos(player_angle), sin(player_angle))
	var plane := Vector2(cos(player_angle + deg_to_rad(90.0)), sin(player_angle + deg_to_rad(90.0)))

	var sorted: Array = []
	for s in _sprites:
		if not s.visible or s.image == null:
			continue
		var dx := s.world_pos.x - player_pos.x
		var dy := s.world_pos.y - player_pos.y
		var dist_sq := dx * dx + dy * dy
		sorted.append({ "sprite": s, "dist_sq": dist_sq })

	sorted.sort_custom(func(a, b): return a["dist_sq"] > b["dist_sq"])

	for entry in sorted:
		var s: Sprite = entry["sprite"]
		var dx := s.world_pos.x - player_pos.x
		var dy := s.world_pos.y - player_pos.y

		var inv_det := 1.0 / (plane.x * dir.y - dir.x * plane.y)
		var transform_x := inv_det * (dir.y * dx - dir.x * dy)
		var transform_y := inv_det * (-plane.y * dx + plane.x * dy)

		if transform_y <= 0.01:
			continue

		var sprite_screen_x := int((Globals.SCREEN_WIDTH / 2.0) * (1.0 + transform_x / transform_y))
		var sprite_height := int(abs(Globals.SCREEN_HEIGHT / transform_y))
		var sprite_width := sprite_height

		var draw_start_x := sprite_screen_x - sprite_width / 2
		var draw_end_x := draw_start_x + sprite_width
		var draw_start_y := (Globals.SCREEN_HEIGHT - sprite_height) / 2

		var tex := s.image
		if tex == null:
			continue
		var tex_w := tex.get_width()
		var tex_h := tex.get_height()

		for stripe in range(maxi(0, draw_start_x), mini(draw_end_x, Globals.SCREEN_WIDTH)):
			if transform_y >= z_buffer[stripe]:
				continue

			var tex_x := int(float(stripe - draw_start_x) * tex_w / sprite_width)
			if tex_x < 0 or tex_x >= tex_w:
				continue

			var h := sprite_height
			var y_start := draw_start_y
			var y_end := y_start + h

			for y in range(maxi(0, y_start), mini(y_end, Globals.SCREEN_HEIGHT)):
				var tex_y := int(float(y - y_start) * tex_h / h)
				if tex_y < 0 or tex_y >= tex_h:
					continue
				var pixel := tex.get_pixel(tex_x, tex_y)
				if pixel.a > 0.01:
					screen.set_pixel(stripe, y, pixel)