extends RefCounted
class_name HUD

static func render(screen: Image) -> void:
	var status_y := int(Globals.SCREEN_HEIGHT * 0.82)
	var status_h := Globals.SCREEN_HEIGHT - status_y

	for y in range(status_y, Globals.SCREEN_HEIGHT):
		for x in Globals.SCREEN_WIDTH:
			screen.set_pixel(x, y, Color(0.3, 0.3, 0.3))

	var color := Color(0.0, 1.0, 0.0) if Globals.player_health > 30 else Color(1.0, 0.3, 0.0)
	_draw_text(screen, "HP: " + str(Globals.player_health) + "%", 4, status_y + 4, color)
	_draw_text(screen, "AMMO: " + str(Globals.player_ammo), 4, status_y + 14, Color(0.9, 0.9, 0.2))
	_draw_text(screen, "SCORE: " + str(Globals.player_score), 4, status_y + 24, Color(0.7, 0.7, 0.9))

	# Weapon indicator
	var weapon_name := "Pistol"
	match Globals.player_weapon:
		Globals.WeaponType.KNIFE:
			weapon_name = "Knife"
		Globals.WeaponType.MACHINE_GUN:
			weapon_name = "MG"
		Globals.WeaponType.CHAIN_GUN:
			weapon_name = "Chain"
	_draw_text(screen, weapon_name, Globals.SCREEN_WIDTH - 60, status_y + 4, Color(1.0, 1.0, 1.0))

	# Health bar
	var bar_x := 4
	var bar_y := status_y + 30
	var bar_w := 100
	var bar_h := 4
	for x in range(bar_x, bar_x + bar_w):
		for y in range(bar_y, bar_y + bar_h):
			screen.set_pixel(x, y, Color(0.15, 0.15, 0.15))
	var fill_w := int(bar_w * Globals.player_health / 100.0)
	for x in range(bar_x, bar_x + fill_w):
		var bar_color := Color(0.0, 1.0, 0.0) if Globals.player_health > 30 else Color(1.0, 0.3, 0.0)
		for y in range(bar_y, bar_y + bar_h):
			screen.set_pixel(x, y, bar_color)

	# Key indicators
	var key_str := ""
	if Globals.player_keys & 1:
		key_str += "G "
	if Globals.player_keys & 2:
		key_str += "S "
	_draw_text(screen, key_str, Globals.SCREEN_WIDTH - 40, status_y + 14, Color(1.0, 0.8, 0.0))

	# Lives
	_draw_text(screen, "LIVES: " + str(Globals.player_lives), Globals.SCREEN_WIDTH - 60, status_y + 24, Color(0.9, 0.5, 0.5))

	# Face placeholder
	var face_x := Globals.SCREEN_WIDTH / 2 - 16
	var face_y := status_y + 2
	for y in range(face_y, face_y + 32):
		for x in range(face_x, face_x + 32):
			screen.set_pixel(x, y, Color(0.7, 0.6, 0.5))

	if Globals.player_health > 70:
		_draw_text(screen, ":)", face_x + 8, face_y + 8, Color.BLACK)
	elif Globals.player_health > 30:
		_draw_text(screen, ":/", face_x + 8, face_y + 8, Color.BLACK)
	else:
		_draw_text(screen, ":(", face_x + 8, face_y + 8, Color.BLACK)


const CHAR_MAP := {
	"A": [0b01110, 0b10001, 0b10001, 0b11111, 0b10001],
	"B": [0b11110, 0b10001, 0b11110, 0b10001, 0b11110],
	"C": [0b01110, 0b10001, 0b10000, 0b10001, 0b01110],
	"D": [0b11110, 0b10001, 0b10001, 0b10001, 0b11110],
	"E": [0b11111, 0b10000, 0b11110, 0b10000, 0b11111],
	"F": [0b11111, 0b10000, 0b11110, 0b10000, 0b10000],
	"G": [0b01110, 0b10001, 0b10111, 0b10001, 0b01110],
	"H": [0b10001, 0b10001, 0b11111, 0b10001, 0b10001],
	"I": [0b01110, 0b00100, 0b00100, 0b00100, 0b01110],
	"K": [0b10001, 0b10010, 0b11100, 0b10010, 0b10001],
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
	"Y": [0b10001, 0b01010, 0b00100, 0b00100, 0b00100],
	"0": [0b01110, 0b10011, 0b10101, 0b11001, 0b01110],
	"1": [0b00100, 0b01100, 0b00100, 0b00100, 0b01110],
	"2": [0b01110, 0b00001, 0b01110, 0b10000, 0b11111],
	"3": [0b01110, 0b00001, 0b01110, 0b00001, 0b01110],
	"4": [0b10001, 0b10001, 0b01111, 0b00001, 0b00001],
	"5": [0b11111, 0b10000, 0b11110, 0b00001, 0b11110],
	"6": [0b01110, 0b10000, 0b11110, 0b10001, 0b01110],
	"7": [0b11111, 0b00001, 0b00010, 0b00100, 0b00100],
	"8": [0b01110, 0b10001, 0b01110, 0b10001, 0b01110],
	"9": [0b01110, 0b10001, 0b01111, 0b00001, 0b01110],
	"+": [0b00000, 0b00100, 0b01110, 0b00100, 0b00000],
	":": [0b00000, 0b00100, 0b00000, 0b00100, 0b00000],
	")": [0b01000, 0b00100, 0b00100, 0b00100, 0b01000],
	"(": [0b00010, 0b00100, 0b00100, 0b00100, 0b00010],
	"/": [0b00001, 0b00010, 0b00100, 0b01000, 0b10000],
	" ": [0b00000, 0b00000, 0b00000, 0b00000, 0b00000],
}

static func _draw_text(screen: Image, text: String, x: int, y: int, color: Color) -> void:
	var cx := x
	for ch in text.to_upper():
		var glyph: Array = CHAR_MAP.get(ch, [0])
		for row in glyph.size():
			var bits: int = glyph[row]
			for col in 5:
				if bits & (1 << (4 - col)):
					var px: int = cx + col
					var py: int = y + row
					if px >= 0 and px < Globals.SCREEN_WIDTH and py >= 0 and py < Globals.SCREEN_HEIGHT:
						screen.set_pixel(px, py, color)
		cx += 6