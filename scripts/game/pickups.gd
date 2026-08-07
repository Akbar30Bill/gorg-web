extends RefCounted
class_name PickupSystem

enum PickupType {
	HEALTH, AMMO, GOLD_KEY, SILVER_KEY,
	CROSS, CHALICE, CHEST, CROWN,
	MACHINE_GUN, CHAIN_GUN,
	ONE_UP, GIB_POINTS,
}

const PICKUP_DEFS: Dictionary = {
	PickupType.HEALTH: { "amount": 25, "message": "Health +25" },
	PickupType.AMMO: { "amount": 8, "message": "Ammo +8" },
	PickupType.GOLD_KEY: { "amount": 1, "message": "Gold Key" },
	PickupType.SILVER_KEY: { "amount": 1, "message": "Silver Key" },
	PickupType.CROSS: { "amount": 100, "message": "Cross +100" },
	PickupType.CHALICE: { "amount": 500, "message": "Chalice +500" },
	PickupType.CHEST: { "amount": 1000, "message": "Treasure +1000" },
	PickupType.CROWN: { "amount": 5000, "message": "Crown +5000" },
	PickupType.MACHINE_GUN: { "amount": 1, "message": "Machine Gun" },
	PickupType.CHAIN_GUN: { "amount": 1, "message": "Chain Gun" },
	PickupType.ONE_UP: { "amount": 1, "message": "Extra Life" },
	PickupType.GIB_POINTS: { "amount": 200, "message": "Bonus +200" },
}

func try_pickup(tile_value: int) -> Dictionary:
	match tile_value:
		126: return _collect(PickupType.HEALTH)
		127: return _collect(PickupType.AMMO)
		128: return _collect(PickupType.GOLD_KEY)
		129: return _collect(PickupType.SILVER_KEY)
		130: return _collect(PickupType.CROSS)
		131: return _collect(PickupType.CHALICE)
		132: return _collect(PickupType.CHEST)
		133: return _collect(PickupType.CROWN)
		134: return _collect(PickupType.MACHINE_GUN)
		135: return _collect(PickupType.CHAIN_GUN)
		136: return _collect(PickupType.ONE_UP)
		137: return _collect(PickupType.GIB_POINTS)
	return { "collected": false }

func _collect(pickup_type: PickupType) -> Dictionary:
	var def: Dictionary = PICKUP_DEFS.get(pickup_type, {})
	var amount: int = def.get("amount", 0)

	match pickup_type:
		PickupType.HEALTH:
			Globals.player_health = mini(Globals.player_health + amount, 100)
		PickupType.AMMO:
			Globals.player_ammo += amount
		PickupType.GOLD_KEY:
			Globals.player_keys |= 1
		PickupType.SILVER_KEY:
			Globals.player_keys |= 2
		PickupType.CROSS, PickupType.CHALICE, PickupType.CHEST, PickupType.CROWN, PickupType.GIB_POINTS:
			Globals.player_score += amount
		PickupType.MACHINE_GUN:
			Globals.player_weapon = WeaponSystem.WeaponType.MACHINE_GUN
		PickupType.CHAIN_GUN:
			Globals.player_weapon = WeaponSystem.WeaponType.CHAIN_GUN
		PickupType.ONE_UP:
			Globals.player_lives += 1

	return {
		"collected": true,
		"message": def.get("message", ""),
	}

