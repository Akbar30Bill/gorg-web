extends RefCounted
class_name SaveManager

const SAVE_DIR := "user://saves/"
const MAX_SLOTS := 6

static func save_exists(slot: int) -> bool:
	return FileAccess.file_exists(SAVE_DIR + "save_" + str(slot) + ".json")

static func save_game(slot: int) -> bool:
	DirAccess.make_dir_recursive_absolute("user://saves")

	var data := {
		"level": Globals.current_level,
		"episode": Globals.current_episode,
		"health": Globals.player_health,
		"ammo": Globals.player_ammo,
		"lives": Globals.player_lives,
		"score": Globals.player_score,
		"keys": Globals.player_keys,
		"weapon": Globals.player_weapon,
		"pos_x": Globals.player_pos.x,
		"pos_y": Globals.player_pos.y,
		"angle": Globals.player_angle,
	}

	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_DIR + "save_" + str(slot) + ".json", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json)
	file.close()
	return true

static func load_game(slot: int) -> bool:
	if not save_exists(slot):
		return false

	var file := FileAccess.open(SAVE_DIR + "save_" + str(slot) + ".json", FileAccess.READ)
	if file == null:
		return false

	var json := file.get_as_text()
	file.close()

	var json_obj := JSON.new()
	var err := json_obj.parse(json)
	if err != OK:
		return false

	var data: Variant = json_obj.get_data()
	if not data is Dictionary:
		return false

	Globals.current_level = data.get("level", 0)
	Globals.current_episode = data.get("episode", 1)
	Globals.player_health = data.get("health", 100)
	Globals.player_ammo = data.get("ammo", 8)
	Globals.player_lives = data.get("lives", 3)
	Globals.player_score = data.get("score", 0)
	Globals.player_keys = data.get("keys", 0)
	Globals.player_weapon = data.get("weapon", WeaponSystem.WeaponType.PISTOL)
	Globals.player_pos = Vector2(
		data.get("pos_x", 1000.0),
		data.get("pos_y", 1000.0),
	)
	Globals.player_angle = data.get("angle", 0.0)

	return true

static func get_slot_info(slot: int) -> Dictionary:
	if not save_exists(slot):
		return { "empty": true }

	var file := FileAccess.open(SAVE_DIR + "save_" + str(slot) + ".json", FileAccess.READ)
	if file == null:
		return { "empty": true }

	var json := file.get_as_text()
	file.close()

	var json_obj := JSON.new()
	if json_obj.parse(json) != OK:
		return { "empty": true }

	var data: Variant = json_obj.get_data()
	if not data is Dictionary:
		return { "empty": true }

	return {
		"empty": false,
		"level": data.get("level", 0),
		"health": data.get("health", 100),
		"score": data.get("score", 0),
	}