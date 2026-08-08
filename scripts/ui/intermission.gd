extends RefCounted
class_name Intermission

var _display_timer: float = 0.0
var _ready_to_continue: bool = false

func start() -> void:
	_display_timer = 0.0
	_ready_to_continue = false

func update(delta: float) -> void:
	_display_timer += delta
	if _display_timer > 2.0:
		_ready_to_continue = true

func render(screen: Image) -> void:
	screen.fill(Color(0.05, 0.08, 0.15))

	var title: String = "LEVEL COMPLETE"
	HUD._draw_text(screen, title, (Globals.SCREEN_WIDTH - len(title) * 6) / 2, 30, Color(1.0, 0.9, 0.2))

	var y: int = 55
	var text_color: Color = Color(0.8, 0.8, 0.8)
	HUD._draw_text(screen, "BONUS", 40, y, Color(0.5, 0.5, 1.0))
	y += 12

	var lines: Array[String] = [
		"Score:    " + str(Globals.player_score),
		"Health:   " + str(Globals.player_health) + "%",
		"Ammo:     " + str(Globals.player_ammo),
		"Lives:    " + str(Globals.player_lives),
	]

	for line: String in lines:
		HUD._draw_text(screen, line, 40, y, text_color)
		y += 12

	if _display_timer > 2.0:
		HUD._draw_text(screen, "", 20, y + 10, text_color)
		var hint: String = "PRESS ENTER TO CONTINUE"
		HUD._draw_text(screen, hint, (Globals.SCREEN_WIDTH - len(hint) * 6) / 2, y + 10, Color(0.8, 0.6, 0.3))

func can_continue() -> bool:
	return _ready_to_continue