extends RefCounted
class_name WeaponSystem

enum WeaponType { KNIFE, PISTOL, MACHINE_GUN, CHAIN_GUN }

class WeaponDef:
	var name: String
	var damage: int
	var fire_rate: float
	var ammo_type: int
	var ammo_per_shot: int
	var auto_fire: bool
	var hit_radius: int  # for knife (melee)

const WEAPONS: Dictionary = {
	WeaponType.KNIFE: {
		"name": "Knife",
		"damage": 10,
		"fire_rate": 0.5,
		"ammo_per_shot": 0,
		"auto_fire": false,
		"hit_radius": 40,
	},
	WeaponType.PISTOL: {
		"name": "Pistol",
		"damage": 15,
		"fire_rate": 0.3,
		"ammo_per_shot": 1,
		"auto_fire": false,
		"hit_radius": 0,
	},
	WeaponType.MACHINE_GUN: {
		"name": "Machine Gun",
		"damage": 12,
		"fire_rate": 0.15,
		"ammo_per_shot": 1,
		"auto_fire": true,
		"hit_radius": 0,
	},
	WeaponType.CHAIN_GUN: {
		"name": "Chain Gun",
		"damage": 14,
		"fire_rate": 0.08,
		"ammo_per_shot": 1,
		"auto_fire": true,
		"hit_radius": 0,
	},
}

var current_weapon: WeaponType = WeaponType.PISTOL
var _fire_timer: float = 0.0
var _is_firing: bool = false

func get_def(wtype: WeaponType = -1) -> Dictionary:
	var wt := wtype if wtype >= 0 else current_weapon
	return WEAPONS.get(wt, WEAPONS[WeaponType.PISTOL])

func can_fire() -> bool:
	if _fire_timer > 0:
		return false
	var def := get_def()
	if current_weapon == WeaponType.KNIFE:
		return true
	return Globals.player_ammo >= def["ammo_per_shot"]

func try_fire() -> Dictionary:
	if not can_fire():
		return { "fired": false }

	var def := get_def()

	if current_weapon != WeaponType.KNIFE:
		Globals.player_ammo -= def["ammo_per_shot"]
		if Globals.player_ammo < 0:
			Globals.player_ammo = 0

	_fire_timer = def["fire_rate"]
	return {
		"fired": true,
		"weapon": current_weapon,
		"damage": def["damage"],
		"hit_radius": def.get("hit_radius", 0),
	}

func update(delta: float) -> void:
	if _fire_timer > 0:
		_fire_timer -= delta

func start_fire() -> void:
	_is_firing = true

func stop_fire() -> void:
	_is_firing = false

func is_firing() -> bool:
	if not _is_firing:
		return false
	var def := get_def()
	return def.get("auto_fire", false)

func switch_to(wtype: WeaponType) -> void:
	current_weapon = wtype
	_fire_timer = 0.0

func has_weapon(wtype: WeaponType) -> bool:
	match wtype:
		WeaponType.KNIFE:
			return true
		WeaponType.PISTOL:
			return true
		WeaponType.MACHINE_GUN:
			return Globals.player_score >= 100  # placeholder unlock
		WeaponType.CHAIN_GUN:
			return Globals.player_score >= 500  # placeholder unlock
	return false