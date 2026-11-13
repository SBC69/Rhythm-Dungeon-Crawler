# scripts/domain/encounter_factory.gd
class_name EncounterFactory
extends RefCounted

const MONSTER_TEMPLATES: Dictionary = {
	"skeleton": {
		"id": "skeleton",
		"name": "Skeleton Warrior",
		"title": "Keeper of the Crypts",
		"sprite": "res://assets/sprites/monsters/skeleton.png",
		"tint": [1.0, 1.0, 1.0, 1.0],
		"flavor": "Ancient bones grip a serrated sword."
	},
	"shadow_ghoul": {
		"id": "shadow_ghoul",
		"name": "Plague Ghoul",
		"title": "Dweller in Darkness",
		"sprite": "res://assets/sprites/monsters/shadow_ghoul-pixel.png",
		"tint": [1.0, 1.0, 1.0, 1.0],
		"flavor": "Its breath poisons the air of the crypt."
	},
	"crypt_knight": {
		"id": "crypt_knight",
		"name": "Fallen Knight",
		"title": "Cursed Guardian",
		"sprite": "res://assets/sprites/monsters/crypt_knight-pixel.png",
		"tint": [1.0, 1.0, 1.0, 1.0],
		"flavor": "Rusted plate guards an oath of eternal service."
	},
	"abyss_demon": {
		"id": "abyss_demon",
		"name": "Abyss Demon",
		"title": "Winged Hunter",
		"sprite": "res://assets/sprites/monsters/boss_archon-pixel.png",
		"tint": [1.0, 1.0, 1.0, 1.0],
		"flavor": "A horned hunter emerges from the dark with a searing blade."
	},
	"cave_spider": {
		"id": "cave_spider",
		"name": "Cave Spider",
		"title": "Dungeon Dweller",
		"sprite": "res://assets/sprites/monsters/cave_spider.png",
		"tint": [
			1,
			1,
			1,
			1
		],
		"flavor": "A cave spider emerges from the dark."
	},
	"dungeon_slime": {
		"id": "dungeon_slime",
		"name": "Dungeon Slime",
		"title": "Dungeon Dweller",
		"sprite": "res://assets/sprites/monsters/dungeon_slime.png",
		"tint": [
			1,
			1,
			1,
			1
		],
		"flavor": "A dungeon slime emerges from the dark."
	},
	"restless_ghost": {
		"id": "restless_ghost",
		"name": "Restless Ghost",
		"title": "Dungeon Dweller",
		"sprite": "res://assets/sprites/monsters/restless_ghost.png",
		"tint": [
			1,
			1,
			1,
			1
		],
		"flavor": "A restless ghost emerges from the dark."
	},
	"werewolf": {
		"id": "werewolf",
		"name": "Wolfkin",
		"title": "Dungeon Dweller",
		"sprite": "res://assets/sprites/monsters/werewolf.png",
		"tint": [
			1,
			1,
			1,
			1
		],
		"flavor": "A wolfkin emerges from the dark."
	},
	"goblin_raider": {
		"id": "goblin_raider",
		"name": "Goblin Raider",
		"title": "Dungeon Dweller",
		"sprite": "res://assets/sprites/monsters/goblin_raider.png",
		"tint": [
			1,
			1,
			1,
			1
		],
		"flavor": "A goblin raider emerges from the dark."
	},
	"stone_golem": {
		"id": "stone_golem",
		"name": "Stone Golem",
		"title": "Dungeon Dweller",
		"sprite": "res://assets/sprites/monsters/stone_golem.png",
		"tint": [
			1,
			1,
			1,
			1
		],
		"flavor": "A stone golem emerges from the dark."
	},
	"bound_djinn": {
		"id": "bound_djinn",
		"name": "Bound Djinn",
		"title": "Dungeon Dweller",
		"sprite": "res://assets/sprites/monsters/bound_djinn.png",
		"tint": [
			1,
			1,
			1,
			1
		],
		"flavor": "A bound djinn emerges from the dark."
	}
}

static func sprite_for(monster: Dictionary) -> String:
	var id := str(monster.get("id", ""))
	# Resolve current artwork for old saved encounters without regenerating their stats.
	if MONSTER_TEMPLATES.has(id):
		return str(MONSTER_TEMPLATES[id].sprite)
	if id == "boss_archon":
		return "res://assets/sprites/monsters/boss_archon-pixel.png"
	return str(monster.get("sprite", "res://assets/sprites/monsters/skeleton.png"))

const TRAP_TEMPLATES: Dictionary = {
	"spike_trap": {
		"id": "spike_trap",
		"name": "Spike Trap",
		"title": "Hidden Mechanism",
		"type": "trap",
		"flavor": "A floor plate clicks beneath you. Sharp steel spikes burst from the ground!",
		"sprite": "res://assets/sprites/dungeon/curse_trap.png"
	},
	"cursed_altar": {
		"id": "cursed_altar",
		"name": "Cursed Altar",
		"title": "Occult Whisper",
		"type": "curse",
		"flavor": "An ominous altar drains your life force and reduces your power by 1.",
		"sprite": "res://assets/sprites/dungeon/curse_trap.png"
	},
	"poison_gas": {
		"id": "poison_gas",
		"name": "Plague Mist",
		"title": "Poisonous Fumes",
		"type": "trap",
		"flavor": "Caustic green smoke fills the room, burning your lungs!",
		"sprite": "res://assets/sprites/dungeon/curse_trap.png"
	}
}

static func calculate_q_for_context(context: Dictionary, balance: Dictionary = {}) -> int:
	if balance.is_empty():
		var cfg = BalanceConfig.new()
		cfg.load_from_file()
		balance = cfg.config_data
	var mode = str(context.get("mode", "timed")).to_lower()
	var f = maxi(1, int(context.get("floor_number", 1)))
	var d = maxi(1, int(context.get("dungeon_index", 1)))
	return f - 1 if mode == "endless" else int(balance.modes.timed.depth_stride) * (d - 1) + f - 1

static func enemy_power(kind: String, q: int, room: int, offset: int, balance: Dictionary) -> int:
	var rule = balance.enemies[kind]
	var power = int(rule.base) + int(rule.depth_multiplier) * q
	if rule.has("room_bonus_divisor"):
		power += int((room - 1) / int(rule.room_bonus_divisor)) + offset
	if rule.has("depth_extra_divisor"):
		power += mini(int(rule.depth_extra_cap), int(q / int(rule.depth_extra_divisor)))
	return maxi(int(rule.get("minimum_power", 0)), power)

static func combat_stats_for(power: int, rule: Dictionary = {}) -> Dictionary:
	return {"attack": maxi(1, power + int(rule.get("attack_offset", 0))),
		"defense": maxi(1, power + int(rule.get("defense_offset", 0)))}

static func pick_by_weight(candidates: Array, weights: Array, rng: RandomNumberGenerator) -> Variant:
	if candidates.is_empty():
		return null
	var total_weight = 0
	for w in weights:
		total_weight += maxi(0, int(w))
	if total_weight <= 0:
		return candidates[0]

	var roll = rng.randi_range(1, total_weight)
	var accum = 0
	for i in range(candidates.size()):
		accum += maxi(0, int(weights[i]))
		if roll <= accum:
			return candidates[i]
	return candidates.back()

static func create_encounter(kind: String, context: Dictionary, rng: RandomNumberGenerator, balance_snapshot: Dictionary = {}) -> Dictionary:
	if balance_snapshot.is_empty():
		var cfg = BalanceConfig.new()
		if not cfg.load_from_file():
			return {}
		balance_snapshot = cfg.config_data
	var q = calculate_q_for_context(context, balance_snapshot)
	var room = maxi(1, int(context.get("room_number", 1)))
	var floor_num = maxi(1, int(context.get("floor_number", 1)))
	if kind in ["regular", "elite"]:
		var legacy_ids := ["skeleton", "shadow_ghoul", "crypt_knight"]
		var archetypes: Array[String] = []
		var weights: Array[int] = []
		var offsets: Array[int] = []
		var stat_rules: Array[Dictionary] = []
		var entries: Array = balance_snapshot.enemies.archetypes
		for i in range(entries.size()):
			var entry: Dictionary = entries[i]
			var fallback_id: String = legacy_ids[i] if i < legacy_ids.size() else ""
			var candidate := str(entry.get("id", fallback_id))
			if not MONSTER_TEMPLATES.has(candidate):
				continue
			archetypes.append(candidate)
			weights.append(int(entry.weight))
			offsets.append(int(entry.power_offset))
			stat_rules.append(entry)
		if archetypes.is_empty():
			return {}
		var id = str(pick_by_weight(archetypes, weights, rng))
		var v = offsets[archetypes.find(id)]
		var data = MONSTER_TEMPLATES[id].duplicate(true)
		if kind == "elite":
			data["title"] = "[ ELITE ENEMY ] " + str(data.title)
		data.merge({"power": enemy_power(kind, q, room, v, balance_snapshot), "is_boss": false, "is_elite": kind == "elite", "archetype_offset": v, "q": q}, true)
		data.merge(combat_stats_for(int(data.power), stat_rules[archetypes.find(id)]), true)
		return data
	if kind == "trap":
		var rules = balance_snapshot.traps
		var ids = rules.templates.keys()
		var weights = []
		for id in ids:
			weights.append(int(rules.templates[id].weight))
		var id = str(pick_by_weight(ids, weights, rng))
		var rule = rules.templates[id]
		var data = TRAP_TEMPLATES[id].duplicate(true)
		data["dc"] = mini(int(rules.dc_cap), int(rule.base_dc) + int(q / int(rules.dc_depth_divisor)))
		data["damage_on_fail"] = mini(int(rules.raw_damage_cap), int(rule.base_damage) + int(q / int(rules.damage_depth_divisor)))
		data["power_drain"] = int(rule.power_penalty)
		data["power_penalty"] = int(rule.power_penalty)
		data["q"] = q
		return data
	if kind == "boss":
		var final_boss = floor_num >= int(balance_snapshot.modes.timed.floor_limit) and str(context.get("mode", "timed")).to_lower() != "endless"
		var power = enemy_power("final_boss" if final_boss else "floor_boss", q, room, 0, balance_snapshot)
		var boss := {"id": "final_boss_malgor" if final_boss else ("boss_lich" if floor_num % 2 == 1 else "boss_archon"), "name": "Lich Lord Malgor (True Form)" if final_boss else ("Lich Lord Malgor" if floor_num % 2 == 1 else "Archdemon of the Abyss"), "title": "Overlord of the Crypt" if final_boss else ("Lord of the Necropolis" if floor_num % 2 == 1 else "Devourer of Souls"), "power": power, "base_power": int(balance_snapshot.enemies["final_boss" if final_boss else "floor_boss"].base), "is_boss": true, "is_final": final_boss, "is_elite": false, "sprite": "res://assets/sprites/monsters/boss_archon-pixel.png" if not final_boss and floor_num % 2 == 0 else "res://assets/sprites/monsters/boss_lich.png", "tint": [1.0, 0.4, 0.4, 1.0] if final_boss else [1.0, 1.0, 1.0, 1.0], "flavor": "A guardian blocks your path.", "q": q}
		boss.merge(combat_stats_for(power, balance_snapshot.enemies["final_boss" if final_boss else "floor_boss"]), true)
		return boss
	return {}
