class_name AshData
extends RefCounted

const RARITIES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const COLORS := [Color("aaa18a"), Color("8eab80"), Color("8da5b3"), Color("ae8cba"), Color("c2a46b")]
const WEAPONS := {
	"dagger": {"name": "Grave Dagger", "min": 8, "max": 15, "cost": 5, "reach": 1.8, "windup": 0.13, "recovery": 0.23},
	"sword": {"name": "Pilgrim's Sword", "min": 10, "max": 20, "cost": 10, "reach": 2.6, "windup": 0.23, "recovery": 0.33},
	"greatsword": {"name": "Oathbreaker", "min": 18, "max": 30, "cost": 18, "reach": 3.1, "windup": 0.46, "recovery": 0.5},
	"spear": {"name": "Briar Spear", "min": 10, "max": 18, "cost": 9, "reach": 3.9, "windup": 0.29, "recovery": 0.32}
}

static func item(kind: String, rarity: int = 0) -> Dictionary:
	var title: String = WEAPONS[kind].name if WEAPONS.has(kind) else {"flask": "Ember Draught", "shard": "Mastery Shard"}.get(kind, "Relic")
	return {"uid": str(Time.get_ticks_usec()) + str(randi()), "kind": kind, "name": title, "rarity": rarity, "amount": 1, "xp": 0}

static func roll_rarity(rng: RandomNumberGenerator, boss: bool = false) -> int:
	var roll := rng.randi_range(0, 99)
	if boss:
		return 2 if roll < 75 else (3 if roll < 95 else 4)
	return 0 if roll < 59 else (1 if roll < 84 else (2 if roll < 96 else (3 if roll < 99 else 4)))

static func loot(rng: RandomNumberGenerator, family: String, boss: bool = false) -> Dictionary:
	var pools := {"stone": ["greatsword", "sword", "shard", "flask"], "briar": ["spear", "dagger", "flask", "shard"], "iron": ["sword", "greatsword", "shard", "flask"]}
	var pool: Array = pools.get(family, pools.stone)
	return item(pool[rng.randi_range(0, pool.size() - 1)], roll_rarity(rng, boss))

static func price(entry: Dictionary) -> int:
	return 100 + 25 * int(entry.rarity)

static func describe(entry: Dictionary) -> String:
	var kind: String = entry.kind
	if WEAPONS.has(kind):
		var weapon: Dictionary = WEAPONS[kind]
		return "%s\n%d–%d base damage  ·  %d stamina\nMastery %d / 50 XP\n25 XP: combo finisher  ·  50 XP: special\nRarity grants +%d%% damage." % [RARITIES[entry.rarity], weapon.min, weapon.max, weapon.cost, entry.xp, entry.rarity * 15]
	if kind == "flask":
		return "%s consumable\nRestore %d health.\nStacks up to five. Use from inventory or press R." % [RARITIES[entry.rarity], 35 + entry.rarity * 8]
	return "%s material\nGrant your equipped weapon 20 mastery XP.\nStacks up to five." % RARITIES[entry.rarity]
