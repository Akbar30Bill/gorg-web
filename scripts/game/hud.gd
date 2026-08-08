extends RefCounted
class_name HUD

const STATUS_Y := 160
const STATUS_H := 40
const BG_TOP := 22
const BG_MID := 23
const BG_BOT := 19
const BEVEL_TOP := 27
const BEVEL_BOT := 17
const BEVEL_HI := 29
const TEXT_COLOR := 15
const NUM_COLOR := 14
const SHADOW_COLOR := 0
const FACE_CENTER_X := 160
const FACE_Y := 166

const DIGIT_BITMAPS := {
	"0": [0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110],
	"1": [0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
	"2": [0b01110, 0b10001, 0b00001, 0b00110, 0b01000, 0b10000, 0b11111],
	"3": [0b01110, 0b10001, 0b00001, 0b00110, 0b00001, 0b10001, 0b01110],
	"4": [0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010],
	"5": [0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110],
	"6": [0b01110, 0b10000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110],
	"7": [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000],
	"8": [0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110],
	"9": [0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00001, 0b01110],
	"%": [0b11000, 0b11001, 0b00010, 0b00100, 0b01000, 0b10011, 0b00011],
	"x": [0b00000, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b00000],
}

const WEAPON_ICONS := {
	Globals.WeaponType.KNIFE: [0b00000,0b00000,0b00010,0b00110,0b00100,0b01100,0b00110,0b00010],
	Globals.WeaponType.PISTOL: [0b01111,0b01001,0b01001,0b01001,0b01111,0b00100,0b00100,0b00100],
	Globals.WeaponType.MACHINE_GUN: [0b00000,0b00100,0b00100,0b01110,0b00100,0b11111,0b00100,0b00100],
	Globals.WeaponType.CHAIN_GUN: [0b00000,0b01010,0b00100,0b01110,0b11111,0b01110,0b00100,0b01010],
}

const WEAPON_NAMES := {
	Globals.WeaponType.KNIFE: [0b00000,0b00000,0b00000,0b00000,0b00000,0b00000,0b00000,0b00000],
	Globals.WeaponType.PISTOL: [0b01110,0b01010,0b01110,0b00000,0b00000,0b00000,0b00000,0b00000],
	Globals.WeaponType.MACHINE_GUN: [0b11111,0b10111,0b10101,0b00000,0b00000,0b00000,0b00000,0b00000],
	Globals.WeaponType.CHAIN_GUN: [0b11101,0b10101,0b10110,0b00000,0b00000,0b00000,0b00000,0b00000],
}

static func render(screen: Image) -> void:
	_draw_status_bar_bg(screen)
	_draw_face(screen)
	_draw_score(screen)
	_draw_lives(screen)
	_draw_level(screen)
	_draw_health(screen)
	_draw_ammo(screen)
	_draw_weapon(screen)
	_draw_keys(screen)

static func _draw_status_bar_bg(screen: Image) -> void:
	for y: int in range(STATUS_Y, STATUS_Y + STATUS_H):
		for x: int in range(Globals.SCREEN_WIDTH):
			var ci: int = BG_MID
			if y == STATUS_Y:
				ci = BEVEL_TOP
			elif y == STATUS_Y + 1:
				ci = BG_TOP
			elif y == STATUS_Y + STATUS_H - 2:
				ci = BG_BOT
			elif y == STATUS_Y + STATUS_H - 1:
				ci = BEVEL_BOT
			elif y % 3 == 0 and x % 3 == 0:
				ci = BG_BOT if y < STATUS_Y + STATUS_H / 2 else BG_TOP
			screen.set_pixel(x, y, Palette.get_color(ci))

	for x: int in range(0, Globals.SCREEN_WIDTH - 1, 2):
		screen.set_pixel(x, STATUS_Y + 2, Palette.get_color(BEVEL_HI))
		screen.set_pixel(x + 1, STATUS_Y + STATUS_H - 3, Palette.get_color(BG_BOT))

	var div_x: Array[int] = [120, 196]
	for dx: int in div_x:
		for y: int in range(STATUS_Y + 4, STATUS_Y + STATUS_H - 4):
			if y % 3 == 0:
				screen.set_pixel(dx, y, Palette.get_color(BEVEL_TOP))
				screen.set_pixel(dx + 1, y, Palette.get_color(BG_BOT))

static func _draw_face(screen: Image) -> void:
	var face_sprites: Array = Globals.face_sprites
	if face_sprites.is_empty():
		_draw_face_placeholder(screen)
		return

	var frame: int = Globals.face_frame
	var sprite_idx: int

	match Globals.face_state:
		Globals.FaceState.NEUTRAL:
			sprite_idx = frame
		Globals.FaceState.HAPPY:
			sprite_idx = min(frame + 3, face_sprites.size() - 1)
		Globals.FaceState.HURT:
			sprite_idx = min(frame + 6, face_sprites.size() - 1)
		Globals.FaceState.LOW:
			sprite_idx = min(frame + 9, face_sprites.size() - 1)
		Globals.FaceState.GOD:
			sprite_idx = frame
		_:
			sprite_idx = frame

	if sprite_idx < 0 or sprite_idx >= face_sprites.size():
		_draw_face_placeholder(screen)
		return

	var face_img := face_sprites[sprite_idx] as Image
	if face_img == null:
		_draw_face_placeholder(screen)
		return

	var face_w: int = face_img.get_width()
	var face_h: int = face_img.get_height()
	var face_x: int = FACE_CENTER_X - face_w / 2
	var face_y: int = FACE_Y - face_h / 2

	for y: int in range(face_h):
		for x: int in range(face_w):
			var px: Color = face_img.get_pixel(x, y)
			if px.a > 0:
				var sx: int = face_x + x
				var sy: int = face_y + y
				if sx >= 0 and sx < Globals.SCREEN_WIDTH and sy >= STATUS_Y and sy < STATUS_Y + STATUS_H:
					screen.set_pixel(sx, sy, px)

static func _draw_face_placeholder(screen: Image) -> void:
	var face_size: int = 28
	var fx: int = FACE_CENTER_X - face_size / 2
	var fy: int = FACE_Y - face_size / 2

	var skin: Color = Palette.get_color(5)
	var hair: Color = Palette.get_color(6)
	var eyes: Color = Palette.get_color(0)
	var mouth: Color = Palette.get_color(4)

	for y: int in range(face_size):
		for x: int in range(face_size):
			var px: int = fx + x
			var py: int = fy + y
			if px < 0 or px >= Globals.SCREEN_WIDTH or py < STATUS_Y or py >= STATUS_Y + STATUS_H:
				continue

			var cx: int = x - face_size / 2
			var cy: int = y - face_size / 2
			var dist: int = cx * cx + cy * cy
			var r: int = face_size / 2 - 2

			if dist <= r * r:
				if cy < -4:
					screen.set_pixel(px, py, hair)
				else:
					screen.set_pixel(px, py, skin)

			if cy > -2 and cy < 2 and abs(cx) < 4:
				screen.set_pixel(px, py, eyes)

	if Globals.face_state == Globals.FaceState.HURT or Globals.face_state == Globals.FaceState.LOW:
		for y: int in range(3):
			for x: int in range(6):
				var px: int = fx + face_size / 2 - 3 + x
				var py: int = fy + face_size / 2 + 2 + y
				screen.set_pixel(px, py, mouth)
	elif Globals.face_state == Globals.FaceState.HAPPY:
		screen.set_pixel(fx + face_size / 2 - 2, fy + face_size / 2 + 3, mouth)
		screen.set_pixel(fx + face_size / 2 + 1, fy + face_size / 2 + 3, mouth)
		screen.set_pixel(fx + face_size / 2 - 1, fy + face_size / 2 + 4, mouth)
		screen.set_pixel(fx + face_size / 2, fy + face_size / 2 + 4, mouth)
		screen.set_pixel(fx + face_size / 2 + 2, fy + face_size / 2 + 4, mouth)
	else:
		screen.set_pixel(fx + face_size / 2 - 1, fy + face_size / 2 + 3, mouth)
		screen.set_pixel(fx + face_size / 2, fy + face_size / 2 + 3, mouth)
		screen.set_pixel(fx + face_size / 2 + 1, fy + face_size / 2 + 3, mouth)

	if Globals.player_health <= 15:
		for y: int in range(face_size):
			for x: int in range(face_size):
				var px2: int = fx + x
				var py2: int = fy + y
				if (x + y) % 4 == 0 and px2 < Globals.SCREEN_WIDTH and py2 < STATUS_Y + STATUS_H:
					var c: Color = screen.get_pixel(px2, py2)
					screen.set_pixel(px2, py2, Color(c.r * 0.5, c.g * 0.3, c.b * 0.3, c.a))

static var _accum_delta: float = 0.0

static func update(delta: float) -> void:
	_accum_delta += delta
	if _accum_delta > 0.05:
		_update_face_animation(_accum_delta)
		_accum_delta = 0.0

static func _update_face_animation(dt: float) -> void:
	var health: int = Globals.player_health

	if health <= 15:
		Globals.face_state = Globals.FaceState.LOW
	elif health <= 40:
		Globals.face_state = Globals.FaceState.LOW
	elif Globals.face_hurt_timer <= 0.0 and Globals.face_happy_timer <= 0.0:
		Globals.face_state = Globals.FaceState.NEUTRAL

	if Globals.face_hurt_timer > 0.0:
		Globals.face_hurt_timer -= dt
		if Globals.face_hurt_timer > 0.0:
			Globals.face_state = Globals.FaceState.HURT
	if Globals.face_happy_timer > 0.0:
		Globals.face_happy_timer -= dt
		if Globals.face_happy_timer > 0.0:
			Globals.face_state = Globals.FaceState.HAPPY

	Globals.face_timer += dt
	if Globals.face_timer > Globals.FACE_ANIM_SPEED:
		Globals.face_timer = 0.0
		Globals.face_frame = (Globals.face_frame + 1) % 3

static func face_on_hurt() -> void:
	Globals.face_hurt_timer = Globals.FACE_HURT_DURATION
	Globals.face_state = Globals.FaceState.HURT
	Globals.face_frame = 0

static func face_on_heal() -> void:
	Globals.face_happy_timer = Globals.FACE_HAPPY_DURATION
	Globals.face_state = Globals.FaceState.HAPPY
	Globals.face_frame = 0

static func _draw_score(screen: Image) -> void:
	_draw_label(screen, "SCORE", 8, STATUS_Y + 2)
	_draw_number(screen, Globals.player_score, 8, STATUS_Y + 11, 7)

static func _draw_lives(screen: Image) -> void:
	_draw_label(screen, "LIVES", 64, STATUS_Y + 2)
	_draw_number(screen, Globals.player_lives, 64, STATUS_Y + 11, 1)

static func _draw_level(screen: Image) -> void:
	_draw_label(screen, "LEVEL", 64, STATUS_Y + 20)
	_draw_number(screen, Globals.current_level + 1, 64, STATUS_Y + 29, 2)

static func _draw_health(screen: Image) -> void:
	_draw_label(screen, "HEALTH", 200, STATUS_Y + 2)
	_draw_number(screen, Globals.player_health, 200, STATUS_Y + 11, 3)
	_draw_text_px(screen, "%", 200 + _number_width(Globals.player_health) * 8 + 1, STATUS_Y + 11, Palette.get_color(NUM_COLOR))

static func _draw_ammo(screen: Image) -> void:
	_draw_label(screen, "AMMO", 200, STATUS_Y + 20)
	_draw_number(screen, Globals.player_ammo, 200, STATUS_Y + 29, 3)

static func _draw_weapon(screen: Image) -> void:
	var icon: Array = WEAPON_ICONS.get(Globals.player_weapon, WEAPON_ICONS[Globals.WeaponType.PISTOL])
	var wx: int = 265
	var wy: int = STATUS_Y + 5
	var wc: Color = Palette.get_color(NUM_COLOR) if Globals.player_weapon == Globals.WeaponType.CHAIN_GUN else Palette.get_color(TEXT_COLOR)
	for row: int in range(icon.size()):
		for col: int in range(8):
			if icon[row] & (1 << (7 - col)):
				var px: int = wx + col
				var py: int = wy + row
				if py >= STATUS_Y and py < STATUS_Y + STATUS_H:
					screen.set_pixel(px, py, wc)

	var name_pic: Array = WEAPON_NAMES.get(Globals.player_weapon, WEAPON_NAMES[Globals.WeaponType.PISTOL])
	for row: int in range(name_pic.size()):
		for col: int in range(8):
			if name_pic[row] & (1 << (7 - col)):
				var px: int = wx + col
				var py: int = wy + 9 + row
				if py >= STATUS_Y and py < STATUS_Y + STATUS_H:
					screen.set_pixel(px, py, Palette.get_color(TEXT_COLOR))

static func _draw_keys(screen: Image) -> void:
	var kx: int = 290
	var ky: int = STATUS_Y + 6
	var gold: Color = Palette.get_color(14)
	var silver: Color = Palette.get_color(7)

	if Globals.player_keys & 1:
		for y: int in range(8):
			for x: int in range(6):
				var px: int = kx + x
				var py: int = ky + y
				if [0,4,4,5,6,6,4,4][y] & (1 << (5 - x)):
					screen.set_pixel(px, py, gold)
		kx += 10

	if Globals.player_keys & 2:
		for y: int in range(8):
			for x: int in range(6):
				var px: int = kx + x
				var py: int = ky + y
				if [0,4,4,5,6,6,4,4][y] & (1 << (5 - x)):
					screen.set_pixel(px, py, silver)

static func _draw_label(screen: Image, text: String, x: int, y: int) -> void:
	var cx: int = x
	for ch: String in text:
		_draw_char(screen, ch, cx, y, Palette.get_color(TEXT_COLOR), true)
		cx += 7

static func _draw_number(screen: Image, value: int, x: int, y: int, min_digits: int) -> void:
	var s: String = str(value)
	while s.length() < min_digits:
		s = "0" + s

	var color: Color = Palette.get_color(NUM_COLOR)
	var health_max: int = 100

	var cx: int = x
	for ch: String in s:
		if value == Globals.player_health:
			var pct: float = float(value) / health_max
			if pct < 0.25:
				color = Palette.get_color(4)
			elif pct < 0.5:
				color = Palette.get_color(14)
			else:
				color = Palette.get_color(2)
		_draw_digit(screen, ch, cx, y, color)
		cx += 8

static func _draw_digit(screen: Image, ch: String, x: int, y: int, color: Color) -> void:
	var glyph: Array = DIGIT_BITMAPS.get(ch, [0])
	for row: int in range(glyph.size()):
		for col: int in range(5):
			if glyph[row] & (1 << (4 - col)):
				var px: int = x + col
				var py: int = y + row
				if px >= 0 and px < Globals.SCREEN_WIDTH and py >= STATUS_Y and py < STATUS_Y + STATUS_H:
					screen.set_pixel(px, py, color)
					if col < 4 and px + 1 < Globals.SCREEN_WIDTH:
						var shadow: Color = Palette.get_color(SHADOW_COLOR)
						var sc: Color = screen.get_pixel(px + 1, py + 1)
						if sc != color:
							if (glyph[row] & (1 << (3 - col))) == 0:
								screen.set_pixel(px + 1, py, shadow)

static func _draw_char(screen: Image, ch: String, x: int, y: int, color: Color, _shadow: bool = false) -> void:
	var cm := {
		"A": [0b01110, 0b10001, 0b10001, 0b11111, 0b10001],
		"B": [0b11110, 0b10001, 0b11110, 0b10001, 0b11110],
		"C": [0b01110, 0b10001, 0b10000, 0b10001, 0b01110],
		"D": [0b11110, 0b10001, 0b10001, 0b10001, 0b11110],
		"E": [0b11111, 0b10000, 0b11110, 0b10000, 0b11111],
		"F": [0b11111, 0b10000, 0b11110, 0b10000, 0b10000],
		"G": [0b01110, 0b10001, 0b10111, 0b10001, 0b01110],
		"H": [0b10001, 0b10001, 0b11111, 0b10001, 0b10001],
		"I": [0b01110, 0b00100, 0b00100, 0b00100, 0b01110],
		"L": [0b10000, 0b10000, 0b10000, 0b10000, 0b11111],
		"M": [0b10001, 0b11011, 0b10101, 0b10001, 0b10001],
		"N": [0b10001, 0b11001, 0b10101, 0b10011, 0b10001],
		"O": [0b01110, 0b10001, 0b10001, 0b10001, 0b01110],
		"P": [0b11110, 0b10001, 0b11110, 0b10000, 0b10000],
		"R": [0b11110, 0b10001, 0b11110, 0b10010, 0b10001],
		"S": [0b01111, 0b10000, 0b01110, 0b00001, 0b11110],
		"T": [0b11111, 0b00100, 0b00100, 0b00100, 0b00100],
		"U": [0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
		"V": [0b10001, 0b10001, 0b10001, 0b01010, 0b00100],
		"W": [0b10001, 0b10001, 0b10101, 0b11011, 0b10001],
		"X": [0b10001, 0b01010, 0b00100, 0b01010, 0b10001],
		"Y": [0b10001, 0b01010, 0b00100, 0b00100, 0b00100],
		" ": [0b00000, 0b00000, 0b00000, 0b00000, 0b00000],
		"-": [0b00000, 0b00000, 0b11111, 0b00000, 0b00000],
		"/": [0b00001, 0b00010, 0b00100, 0b01000, 0b10000],
	}
	var glyph: Array = cm.get(ch, [0])
	for row: int in range(glyph.size()):
		for col: int in range(5):
			if glyph[row] & (1 << (4 - col)):
				var px: int = x + col
				var py: int = y + row
				if px >= 0 and px < Globals.SCREEN_WIDTH and py >= STATUS_Y and py < STATUS_Y + STATUS_H:
					screen.set_pixel(px, py, color)

static func _draw_text_px(screen: Image, text: String, x: int, y: int, color: Color) -> void:
	var cx: int = x
	for ch: String in text:
		_draw_digit(screen, ch, cx, y, color)
		cx += 8

static func _number_width(value: int) -> int:
	var s: String = str(value)
	return s.length()

static func _old_draw_text(screen: Image, text: String, x: int, y: int, color: Color) -> void:
	_draw_text(screen, text, x, y, color)

static func _draw_text(screen: Image, text: String, x: int, y: int, color: Color) -> void:
	var cx: int = x
	for ch: String in text.to_upper():
		var glyph: Array = [0]
		match ch:
			"A": glyph = [0b01110, 0b10001, 0b10001, 0b11111, 0b10001]
			"B": glyph = [0b11110, 0b10001, 0b11110, 0b10001, 0b11110]
			"C": glyph = [0b01110, 0b10001, 0b10000, 0b10001, 0b01110]
			"D": glyph = [0b11110, 0b10001, 0b10001, 0b10001, 0b11110]
			"E": glyph = [0b11111, 0b10000, 0b11110, 0b10000, 0b11111]
			"F": glyph = [0b11111, 0b10000, 0b11110, 0b10000, 0b10000]
			"G": glyph = [0b01110, 0b10001, 0b10111, 0b10001, 0b01110]
			"H": glyph = [0b10001, 0b10001, 0b11111, 0b10001, 0b10001]
			"I": glyph = [0b01110, 0b00100, 0b00100, 0b00100, 0b01110]
			"K": glyph = [0b10001, 0b10010, 0b11100, 0b10010, 0b10001]
			"L": glyph = [0b10000, 0b10000, 0b10000, 0b10000, 0b11111]
			"M": glyph = [0b10001, 0b11011, 0b10101, 0b10001, 0b10001]
			"N": glyph = [0b10001, 0b11001, 0b10101, 0b10011, 0b10001]
			"O": glyph = [0b01110, 0b10001, 0b10001, 0b10001, 0b01110]
			"P": glyph = [0b11110, 0b10001, 0b11110, 0b10000, 0b10000]
			"R": glyph = [0b11110, 0b10001, 0b11110, 0b10010, 0b10001]
			"S": glyph = [0b01111, 0b10000, 0b01110, 0b00001, 0b11110]
			"T": glyph = [0b11111, 0b00100, 0b00100, 0b00100, 0b00100]
			"U": glyph = [0b10001, 0b10001, 0b10001, 0b10001, 0b01110]
			"V": glyph = [0b10001, 0b10001, 0b10001, 0b01010, 0b00100]
			"Y": glyph = [0b10001, 0b01010, 0b00100, 0b00100, 0b00100]
			"0": glyph = [0b01110, 0b10011, 0b10101, 0b11001, 0b01110]
			"1": glyph = [0b00100, 0b01100, 0b00100, 0b00100, 0b01110]
			"2": glyph = [0b01110, 0b00001, 0b01110, 0b10000, 0b11111]
			"3": glyph = [0b01110, 0b00001, 0b01110, 0b00001, 0b01110]
			"4": glyph = [0b10001, 0b10001, 0b01111, 0b00001, 0b00001]
			"5": glyph = [0b11111, 0b10000, 0b11110, 0b00001, 0b11110]
			"6": glyph = [0b01110, 0b10000, 0b11110, 0b10001, 0b01110]
			"7": glyph = [0b11111, 0b00001, 0b00010, 0b00100, 0b00100]
			"8": glyph = [0b01110, 0b10001, 0b01110, 0b10001, 0b01110]
			"9": glyph = [0b01110, 0b10001, 0b01111, 0b00001, 0b01110]
			"+": glyph = [0b00000, 0b00100, 0b01110, 0b00100, 0b00000]
			":": glyph = [0b00000, 0b00100, 0b00000, 0b00100, 0b00000]
			")": glyph = [0b01000, 0b00100, 0b00100, 0b00100, 0b01000]
			"(": glyph = [0b00010, 0b00100, 0b00100, 0b00100, 0b00010]
			"/": glyph = [0b00001, 0b00010, 0b00100, 0b01000, 0b10000]
			" ": glyph = [0b00000, 0b00000, 0b00000, 0b00000, 0b00000]
		for row: int in range(glyph.size()):
			var bits: int = glyph[row]
			for col: int in range(5):
				if bits & (1 << (4 - col)):
					var px: int = cx + col
					var py: int = y + row
					if px >= 0 and px < Globals.SCREEN_WIDTH and py >= 0 and py < Globals.SCREEN_HEIGHT:
						screen.set_pixel(px, py, color)
		cx += 6