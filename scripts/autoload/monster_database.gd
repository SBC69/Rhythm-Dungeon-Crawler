extends Node

var regular_monsters: Array[Dictionary] = [
	{
		"id": "skeleton",
		"name": "Skeleton Warrior",
		"title": "Keeper of the Crypts",
		"base_power": 4,
		"sprite": "res://assets/sprites/monsters/skeleton.png",
		"tint": [
			1,
			1,
			1,
			1
		],
		"flavor": "Ancient bones grip a serrated sword."
	},
	{
		"id": "shadow_ghoul",
		"name": "Plague Ghoul",
		"title": "Dweller in Darkness",
		"base_power": 5,
		"sprite": "res://assets/sprites/monsters/shadow_ghoul-pixel.png",
		"tint": [
			1,
			1,
			1,
			1
		],
		"flavor": "Its breath poisons the air of the crypt."
	},
	{
		"id": "crypt_knight",
		"name": "Fallen Knight",
		"title": "Cursed Guardian",
		"base_power": 6,
		"sprite": "res://assets/sprites/monsters/crypt_knight-pixel.png",
		"tint": [
			1,
			1,
			1,
			1
		],
		"flavor": "Rusted plate guards an oath of eternal service."
	},
	{
		"id": "abyss_demon",
		"name": "Abyss Demon",
		"title": "Winged Hunter",
		"base_power": 6,
		"sprite": "res://assets/sprites/monsters/boss_archon-pixel.png",
		"tint": [
			1,
			1,
			1,
			1
		],
		"flavor": "A horned hunter emerges from the dark with a searing blade."
	},
	{
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
		"flavor": "A cave spider emerges from the dark.",
		"base_power": 3
	},
	{
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
		"flavor": "A dungeon slime emerges from the dark.",
		"base_power": 3
	},
	{
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
		"flavor": "A restless ghost emerges from the dark.",
		"base_power": 4
	},
	{
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
		"flavor": "A wolfkin emerges from the dark.",
		"base_power": 5
	},
	{
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
		"flavor": "A goblin raider emerges from the dark.",
		"base_power": 4
	},
	{
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
		"flavor": "A stone golem emerges from the dark.",
		"base_power": 6
	},
	{
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
		"flavor": "A bound djinn emerges from the dark.",
		"base_power": 5
	}
]

var floor_bosses: Array[Dictionary] = [
	{
		"id": "boss_lich",
		"name": "Lich Lord Malgor",
		"title": "Lord of the Necropolis",
		"base_power": 9,
		"sprite": "res://assets/sprites/monsters/boss_lich.png",
		"tint": Color(1.0, 1.0, 1.0),
		"flavor": "An ancient necromancer who commands the souls of fallen adventurers."
	},
	{
		"id": "boss_archon",
		"name": "Archdemon of the Abyss",
		"title": "Devourer of Souls",
		"base_power": 12,
		"sprite": "res://assets/sprites/monsters/boss_archon-pixel.png",
		"tint": Color.WHITE,
		"flavor": "The true terror of the dungeon's deepest levels."
	}
]

func get_monster_for_room(floor_num: int, room_num: int) -> Dictionary:
	var monster: Dictionary = {}
	if room_num == 10:
		# Floor Boss!
		var boss_idx = (floor_num - 1) % floor_bosses.size()
		monster = floor_bosses[boss_idx].duplicate()
		monster["is_boss"] = true
		monster["power"] = monster["base_power"] + (floor_num - 1) * 4
	else:
		# Regular monster scaled by floor and room
		var template = regular_monsters.pick_random().duplicate()
		monster = template
		monster["is_boss"] = false
		var room_bonus = int(floori((room_num - 1) / 3.0))
		var floor_bonus = (floor_num - 1) * 2
		monster["power"] = maxi(2, monster["base_power"] + floor_bonus + room_bonus + randi_range(-1, 1))
	return monster

var curse_templates: Array[Dictionary] = [
	{
		"id": "spike_trap",
		"name": "Spike Trap",
		"title": "Hidden Mechanism",
		"type": "trap",
		"dc": 6, # Target dice roll to evade completely
		"damage_on_fail": 12,
		"flavor": "A floor plate clicks beneath you. Sharp steel spikes burst from the ground!",
		"sprite": "res://assets/sprites/dungeon/curse_trap.png"
	},
	{
		"id": "cursed_altar",
		"name": "Cursed Altar",
		"title": "Occult Whisper",
		"type": "curse",
		"dc": 7,
		"damage_on_fail": 8,
		"power_drain": 1,
		"flavor": "An ominous altar drains your life force and reduces your power by 1.",
		"sprite": "res://assets/sprites/dungeon/curse_trap.png"
	},
	{
		"id": "poison_gas",
		"name": "Plague Mist",
		"title": "Poisonous Fumes",
		"type": "trap",
		"dc": 5,
		"damage_on_fail": 10,
		"flavor": "Caustic green smoke fills the room, burning your lungs!",
		"sprite": "res://assets/sprites/dungeon/curse_trap.png"
	}
]

func get_random_curse(floor_num: int, depth: int = 1) -> Dictionary:
	var curse = curse_templates.pick_random().duplicate()
	var base_dc = int(curse.get("dc", 6))
	var base_dmg = int(curse.get("damage_on_fail", 10))
	var stats = DungeonProgression.calculate_trap_stats(base_dc, base_dmg, depth, floor_num)
	curse["dc"] = stats["dc"]
	curse["damage_on_fail"] = stats["raw_damage"]
	return curse
