extends RefCounted
class_name MenuSystem

enum MenuState { TITLE, MAIN, NEW_GAME, LOAD_GAME, CONTROLS, PAUSED }

var state: MenuState = MenuState.TITLE
var _selected_option: int = 0
var _menu_options: Array[String] = []
var _blink_timer: float = 0.0
var _blink_visible: bool = true

func enter_state(new_state: MenuState) -> void:
	state = new_state
	_selected_option = 0
	_blink_timer = 0.0
	_blink_visible = true

	match state:
		MenuState.MAIN:
			_menu_options = ["New Game", "Load Game", "Controls", "Quit"]
		MenuState.LOAD_GAME:
			_menu_options = []
			for i in 6:
				var info := SaveManager.get_slot_info(i)
				if info.get("empty", true):
					_menu_options.append("Slot " + str(i + 1) + " - Empty")
				else:
					_menu_options.append("Slot " + str(i + 1) + " - Lv" + str(info["level"]) + " HP" + str(info["health"]))
			_menu_options.append("Back")
		MenuState.CONTROLS:
			_menu_options = []
		_:
			_menu_options = []

func move_up() -> void:
	if _menu_options.is_empty():
		return
	_selected_option = (_selected_option - 1 + _menu_options.size()) % _menu_options.size()

func move_down() -> void:
	if _menu_options.is_empty():
		return
	_selected_option = (_selected_option + 1) % _menu_options.size()

func get_selected() -> int:
	return _selected_option

func get_option(index: int) -> String:
	if index < 0 or index >= _menu_options.size():
		return ""
	return _menu_options[index]

func option_count() -> int:
	return _menu_options.size()

func update(delta: float) -> void:
	_blink_timer += delta
	if _blink_timer >= 0.5:
		_blink_timer -= 0.5
		_blink_visible = not _blink_visible

func confirm_action() -> Dictionary:
	match state:
		MenuState.MAIN:
			match _selected_option:
				0: return { "action": "new_game" }
				1:
					enter_state(MenuState.LOAD_GAME)
					return { "action": "none" }
				2:
					enter_state(MenuState.CONTROLS)
					return { "action": "none" }
				3: return { "action": "quit" }
		MenuState.LOAD_GAME:
			if _selected_option == _menu_options.size() - 1:
				enter_state(MenuState.MAIN)
				return { "action": "none" }
			return { "action": "load", "slot": _selected_option }
		MenuState.CONTROLS:
			enter_state(MenuState.MAIN)
			return { "action": "none" }
	return { "action": "none" }

func render(screen: Image) -> void:
	screen.fill(Color(0.05, 0.05, 0.1))

	match state:
		MenuState.TITLE:
			_render_title_screen(screen)
		MenuState.MAIN:
			_render_title_screen(screen)
			_render_menu(screen)
		MenuState.LOAD_GAME:
			_render_heading(screen, "LOAD GAME")
			_render_menu(screen)
		MenuState.CONTROLS:
			_render_heading(screen, "CONTROLS")
			_render_controls(screen)
		MenuState.PAUSED:
			_render_heading(screen, "PAUSED")
			_render_menu(screen)

func _render_title_screen(screen: Image) -> void:
	var title_chars := "WOLFENSTEIN 3D"
	var title_x := (Globals.SCREEN_WIDTH - len(title_chars) * 6) / 2 + 4
	for i in title_chars.length():
		var c := float(i) / title_chars.length()
		var color := Color(1.0, 0.3 + c * 0.3, 0.3)
		HUD._draw_text(screen, title_chars[i], title_x + i * 6 - 2, 20, color)
		HUD._draw_text(screen, title_chars[i], title_x + i * 6, 18, Color(1.0, 0.1, 0.1))

	var subtitle := "A GODOT 4 REIMAGINING"
	var sub_x := (Globals.SCREEN_WIDTH - len(subtitle) * 6) / 2
	HUD._draw_text(screen, subtitle, sub_x, 40, Color(0.6, 0.6, 0.6))

	var credit := "github.com/Akbar30Bill/gorg-web"
	var cred_x := (Globals.SCREEN_WIDTH - len(credit) * 6) / 2
	HUD._draw_text(screen, credit, cred_x, Globals.SCREEN_HEIGHT - 20, Color(0.4, 0.4, 0.5))

	var hint := "PRESS ENTER TO START"
	var hx := (Globals.SCREEN_WIDTH - len(hint) * 6) / 2
	HUD._draw_text(screen, hint, hx, Globals.SCREEN_HEIGHT - 34, Color(0.6, 0.6, 0.3))

func _render_heading(screen: Image, text: String) -> void:
	var x := (Globals.SCREEN_WIDTH - len(text) * 6) / 2
	HUD._draw_text(screen, text, x, 30, Color(1.0, 0.9, 0.3))

func _render_menu(screen: Image) -> void:
	var start_y := 70
	for i in _menu_options.size():
		var option := _menu_options[i]
		var x := (Globals.SCREEN_WIDTH - len(option) * 6) / 2
		var y := start_y + i * 14
		var color := Color(0.8, 0.8, 0.8)
		if i == _selected_option:
			if _blink_visible:
				HUD._draw_text(screen, ">", x - 10, y, Color(1.0, 0.8, 0.2))
			color = Color(1.0, 0.9, 0.3)
		HUD._draw_text(screen, option, x, y, color)

	var hint := "ARROWS: Select  ENTER: Confirm  ESC: Back"
	var hx := (Globals.SCREEN_WIDTH - len(hint) * 6) / 2
	HUD._draw_text(screen, hint, hx, Globals.SCREEN_HEIGHT - 12, Color(0.5, 0.5, 0.5))

func _render_controls(screen: Image) -> void:
	var controls := [
		"W/UP       Move Forward",
		"S/DOWN     Move Backward",
		"A          Strafe Left",
		"D          Strafe Right",
		"LEFT/RIGHT Rotate",
		"MOUSE      Look Around",
		"CTRL/CLICK Fire Weapon",
		"1-4        Switch Weapon",
		"E/SPACE    Open Door",
		"ESC        Release Mouse",
	]

	var y := 50
	for line in controls:
		var x := 20
		HUD._draw_text(screen, line, x, y, Color(0.7, 0.7, 0.7))
		y += 12

	var hint := "Press ENTER or ESC to return"
	var hx := (Globals.SCREEN_WIDTH - len(hint) * 6) / 2
	HUD._draw_text(screen, hint, hx, Globals.SCREEN_HEIGHT - 12, Color(0.5, 0.5, 0.5))