# scripts/domain/balance_config.gd
class_name BalanceConfig
extends RefCounted

var config_data: Dictionary = {}
var is_valid: bool = false
var version: String = ""
var last_error_path: String = ""
var last_error_message: String = ""

func _fail(path: String, message: String) -> bool:
	last_error_path = path
	last_error_message = message
	is_valid = false
	push_error("BalanceConfig [%s]: %s" % [path, message])
	return false

func load_from_file(path: String = "res://assets/data/game_balance.json") -> bool:
	if not FileAccess.file_exists(path):
		return _fail(path, "File not found")

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail(path, "Could not open file")

	var content = file.get_as_text()
	file.close()

	var parser = JSON.new()
	var err = parser.parse(content)
	if err != OK:
		return _fail(path, "JSON parse error: %s" % parser.get_error_message())

	var data = parser.get_data()
	if not (data is Dictionary):
		return _fail(path, "Root must be a Dictionary")

	return load_from_dict(data as Dictionary)

func load_from_dict(data: Dictionary) -> bool:
	last_error_path = ""
	last_error_message = ""
	is_valid = false

	# Validate essential top-level keys
	var required = ["schema_version", "hero", "modes", "dungeon_order", "enemies", "combat", "traps", "items", "floor"]
	for k in required:
		if not data.has(k):
			return _fail(k, "Missing required key '%s'" % k)

	if int(data.get("schema_version", 0)) != 1:
		return _fail("schema_version", "Unsupported schema version")

	for section in ["floor", "enemies", "traps", "economy", "village"]:
		var error = _validate_integer_tree(data.get(section, {}), section)
		if not error.is_empty():
			return _fail(error, "balance numbers must be finite integers")
	# 1. Floor configuration validation (Section 2.1)
	var floor_cfg = data.get("floor")
	if not (floor_cfg is Dictionary):
		return _fail("floor", "floor must be a Dictionary")

	var rooms_before_boss = int(floor_cfg.get("rooms_before_boss", -1))
	if rooms_before_boss <= 0:
		return _fail("floor.rooms_before_boss", "rooms_before_boss must be positive integer")

	var boss_room = int(floor_cfg.get("boss_room", -1))
	if boss_room != rooms_before_boss + 1:
		return _fail("floor.boss_room", "boss_room must follow rooms_before_boss (expected %d)" % (rooms_before_boss + 1))

	var normal_door_count = int(floor_cfg.get("normal_door_count", -1))
	if normal_door_count <= 0:
		return _fail("floor.normal_door_count", "normal_door_count must be positive integer")

	var boss_door_count = int(floor_cfg.get("boss_door_count", -1))
	if boss_door_count <= 0:
		return _fail("floor.boss_door_count", "boss_door_count must be positive integer")

	if int(floor_cfg.get("generation_version", 0)) != 2 or floor_cfg.get("choice_policy") != "remaining_counts":
		return _fail("floor.generation_version", "unsupported generation policy")
	if normal_door_count != 3 or boss_door_count != 1 or rooms_before_boss != 9:
		return _fail("floor", "this game requires 3 ordinary doors, 1 boss door and 9 ordinary rooms")
	var elite_min = int(floor_cfg.get("elite_room_min", -1))
	var elite_max = int(floor_cfg.get("elite_room_max", -1))
	if elite_min < 1 or elite_max > rooms_before_boss or elite_min > elite_max:
		return _fail("floor.elite_room_range", "elite room range [%d, %d] must be within [1, %d]" % [elite_min, elite_max, rooms_before_boss])

	var max_elite_slots = elite_max - elite_min + 1

	# first_floor
	var first_floor = floor_cfg.get("first_floor")
	if not (first_floor is Dictionary):
		return _fail("floor.first_floor", "first_floor must be a Dictionary")
	var f_reg = int(first_floor.get("regular", -1))
	var f_eli = int(first_floor.get("elite", -1))
	var f_trp = int(first_floor.get("trap", -1))
	if f_reg < 0 or f_eli < 0 or f_trp < 0:
		return _fail("floor.first_floor", "room counts must be non-negative integers")
	if f_reg + f_eli + f_trp != rooms_before_boss:
		return _fail("floor.first_floor", "sum of room counts (%d) must equal rooms_before_boss (%d)" % [f_reg + f_eli + f_trp, rooms_before_boss])
	if f_eli > max_elite_slots:
		return _fail("floor.first_floor.elite", "elite count (%d) exceeds allowable slots (%d)" % [f_eli, max_elite_slots])

	# later_floors
	var later_floors = floor_cfg.get("later_floors")
	if not (later_floors is Dictionary):
		return _fail("floor.later_floors", "later_floors must be a Dictionary")
	var l_reg = int(later_floors.get("regular", -1))
	var l_eli = int(later_floors.get("elite", -1))
	var l_trp = int(later_floors.get("trap", -1))
	if l_reg < 0 or l_eli < 0 or l_trp < 0:
		return _fail("floor.later_floors", "room counts must be non-negative integers")
	if l_reg + l_eli + l_trp != rooms_before_boss:
		return _fail("floor.later_floors", "sum of room counts (%d) must equal rooms_before_boss (%d)" % [l_reg + l_eli + l_trp, rooms_before_boss])
	if l_eli > max_elite_slots:
		return _fail("floor.later_floors.elite", "elite count (%d) exceeds allowable slots (%d)" % [l_eli, max_elite_slots])

	# 2. Enemies & scaling
	var enemies = data.get("enemies")
	if not (enemies is Dictionary):
		return _fail("enemies", "enemies must be a Dictionary")

	var reg_enemy = enemies.get("regular", {})
	if not (reg_enemy is Dictionary) or int(reg_enemy.get("room_bonus_divisor", 0)) <= 0:
		return _fail("enemies.regular.room_bonus_divisor", "divisor must be positive")

	var elite = enemies.get("elite", {})
	if not (elite is Dictionary) or int(elite.get("depth_extra_divisor", 0)) <= 0:
		return _fail("enemies.elite.depth_extra_divisor", "divisor must be positive")
	if int(elite.get("room_bonus_divisor", 0)) <= 0:
		return _fail("enemies.elite.room_bonus_divisor", "divisor must be positive")

	var floor_boss = enemies.get("floor_boss", {})
	if not (floor_boss is Dictionary) or int(floor_boss.get("depth_extra_divisor", 0)) <= 0:
		return _fail("enemies.floor_boss.depth_extra_divisor", "divisor must be positive")

	# Archetypes
	var archetypes = enemies.get("archetypes")
	if not (archetypes is Array) or archetypes.is_empty():
		return _fail("enemies.archetypes", "archetypes must be a non-empty Array")
	var sum_archetype_weight = 0
	for i in range(archetypes.size()):
		var arch = archetypes[i]
		if not (arch is Dictionary):
			return _fail("enemies.archetypes[%d]" % i, "archetype entry must be a Dictionary")
		var w = int(arch.get("weight", -1))
		if w < 0:
			return _fail("enemies.archetypes[%d].weight" % i, "weight must be non-negative")
		sum_archetype_weight += w
	if sum_archetype_weight <= 0:
		return _fail("enemies.archetypes", "sum of archetype weights must be positive")

	# 3. Traps
	var traps = data.get("traps")
	if not (traps is Dictionary):
		return _fail("traps", "traps must be a Dictionary")
	if int(traps.get("dc_depth_divisor", 0)) <= 0:
		return _fail("traps.dc_depth_divisor", "divisor must be positive")
	if int(traps.get("damage_depth_divisor", 0)) <= 0:
		return _fail("traps.damage_depth_divisor", "divisor must be positive")

	var trap_templates = traps.get("templates")
	if not (trap_templates is Dictionary) or trap_templates.is_empty():
		return _fail("traps.templates", "templates must be a non-empty Dictionary")
	var sum_trap_weight = 0
	for t_id in trap_templates:
		var tmpl = trap_templates[t_id]
		if not (tmpl is Dictionary):
			return _fail("traps.templates.%s" % t_id, "template must be a Dictionary")
		var tw = int(tmpl.get("weight", -1))
		if tw < 0:
			return _fail("traps.templates.%s.weight" % t_id, "weight must be non-negative")
		sum_trap_weight += tw
	if sum_trap_weight <= 0:
		return _fail("traps.templates", "sum of trap weights must be positive")

	# 4. Combat
	var combat = data.get("combat")
	if not (combat is Dictionary):
		return _fail("combat", "combat must be a Dictionary")
	if int(combat.get("damage_per_power_gap", 0)) <= 0:
		return _fail("combat.damage_per_power_gap", "must be positive")
	if int(combat.get("minimum_damaging_hit", -1)) < 0:
		return _fail("combat.minimum_damaging_hit", "must be non-negative")

	# 5. Hero
	var hero = data.get("hero")
	if not (hero is Dictionary):
		return _fail("hero", "hero must be a Dictionary")
	if int(hero.get("max_hp", 0)) <= 0:
		return _fail("hero.max_hp", "max_hp must be positive")
	if int(hero.get("base_power", 0)) <= 0:
		return _fail("hero.base_power", "base_power must be positive")
	if int(hero.get("starting_gold", -1)) < 0:
		return _fail("hero.starting_gold", "starting_gold must be non-negative")

	# 6. Modes
	var modes = data.get("modes")
	if not (modes is Dictionary):
		return _fail("modes", "modes must be a Dictionary")
	if not modes.has("timed") or not (modes["timed"] is Dictionary):
		return _fail("modes.timed", "modes.timed must be a Dictionary")
	if not modes.has("endless") or not (modes["endless"] is Dictionary):
		return _fail("modes.endless", "modes.endless must be a Dictionary")

	# 7. Dungeons & Dungeon Order
	var dungeon_order = data.get("dungeon_order")
	if not (dungeon_order is Array) or dungeon_order.is_empty():
		return _fail("dungeon_order", "dungeon_order must be a non-empty Array")

	var dungeons = data.get("dungeons", {})
	if dungeons is Dictionary:
		for d_key in dungeons:
			if not dungeon_order.has(d_key):
				return _fail("dungeons.%s" % d_key, "dungeon '%s' not present in dungeon_order" % d_key)
			var d_val = dungeons[d_key]
			if d_val is Dictionary and str(d_val.get("next", "")) == str(d_key):
				return _fail("dungeons.%s.next" % d_key, "dungeon cannot point next to itself")

	# 8. Upgrades (if present)
	var upgrades = data.get("upgrades", {})
	if upgrades is Dictionary and upgrades.has("max_per_item") and int(upgrades.get("max_per_item", 1)) <= 0:
		return _fail("upgrades.max_per_item", "max_per_item must be positive")

	# 9. Village
	var village = data.get("village", {})
	if village is Dictionary:
		var objects = village.get("objects", {})
		if objects is Dictionary:
			for obj_key in objects:
				var obj = objects[obj_key]
				if obj is Dictionary and obj.has("stage_prices"):
					var prices = obj["stage_prices"]
					if prices is Array:
						for p in prices:
							if int(p) < 0:
								return _fail("village.objects.%s.stage_prices" % obj_key, "stage price cannot be negative")

	# 10. Economy
	var economy = data.get("economy", {})
	if economy is Dictionary:
		var dpnr = economy.get("death_positive_net_retention", {})
		if dpnr is Dictionary and int(dpnr.get("denominator", 1)) <= 0:
			return _fail("economy.death_positive_net_retention.denominator", "denominator must be positive")
		var gold_rewards = economy.get("gold_rewards", {})
		if gold_rewards is Dictionary and gold_rewards.has("depth_divisor") and int(gold_rewards.get("depth_divisor", 1)) <= 0:
			return _fail("economy.gold_rewards.depth_divisor", "divisor must be positive")

	# 11. Items / cards
	var items = data.get("items", {})
	if items is Dictionary:
		var cards = items.get("cards", {})
		if cards is Dictionary and not cards.is_empty():
			var sum_loot_weight = 0
			for card_key in cards:
				var c = cards[card_key]
				if c is Dictionary and c.has("loot_weight"):
					var lw = int(c["loot_weight"])
					if lw < 0:
						return _fail("items.cards.%s.loot_weight" % card_key, "loot_weight cannot be negative")
					sum_loot_weight += lw
			if sum_loot_weight <= 0:
				return _fail("items.cards", "sum of card loot weights must be positive")

	config_data = data.duplicate(true)
	version = str(config_data.get("balance_version", "1.0"))
	is_valid = true
	return true

# Getters
func get_hero_max_hp() -> int:
	return int(config_data.get("hero", {}).get("max_hp", 50))

func get_hero_base_power() -> int:
	return int(config_data.get("hero", {}).get("base_power", 2))

func get_hero_starting_gold() -> int:
	return int(config_data.get("hero", {}).get("starting_gold", 40))

func get_starting_gold() -> int:
	return get_hero_starting_gold()

func get_minimum_effective_base_power() -> int:
	return int(config_data.get("hero", {}).get("minimum_effective_base_power", 1))

func get_timed_floor_limit() -> int:
	return int(config_data.get("modes", {}).get("timed", {}).get("floor_limit", 100))

func get_forge_power_gain(stage: int) -> int:
	var gains = config_data.get("upgrades", {}).get("power_gain_by_forge_stage", [2, 3, 4, 5])
	if stage >= 0 and stage < gains.size():
		return int(gains[stage])
	return 2 + stage

func get_dungeon_order() -> Array:
	return config_data.get("dungeon_order", ["crypts"]).duplicate()

func get_damage_per_power_gap() -> int:
	return int(config_data.get("combat", {}).get("damage_per_power_gap", 10))

func get_minimum_damaging_hit() -> int:
	return int(config_data.get("combat", {}).get("minimum_damaging_hit", 1))

# Floor config getters (v2)
func get_floor_generation_version() -> int:
	return int(config_data.get("floor", {}).get("generation_version", 2))

func get_floor_normal_door_count() -> int:
	return int(config_data.get("floor", {}).get("normal_door_count", 3))

func get_floor_boss_door_count() -> int:
	return int(config_data.get("floor", {}).get("boss_door_count", 1))

func get_floor_rooms_before_boss() -> int:
	return int(config_data.get("floor", {}).get("rooms_before_boss", 9))

func get_floor_boss_room() -> int:
	return int(config_data.get("floor", {}).get("boss_room", 10))

func get_floor_first_floor_counts() -> Dictionary:
	return config_data.get("floor", {}).get("first_floor", {"regular": 7, "elite": 0, "trap": 2}).duplicate(true)

func get_floor_later_floors_counts() -> Dictionary:
	return config_data.get("floor", {}).get("later_floors", {"regular": 6, "elite": 1, "trap": 2}).duplicate(true)

func get_floor_elite_room_min() -> int:
	return int(config_data.get("floor", {}).get("elite_room_min", 4))

func get_floor_elite_room_max() -> int:
	return int(config_data.get("floor", {}).get("elite_room_max", 9))

func get_floor_choice_policy() -> String:
	return str(config_data.get("floor", {}).get("choice_policy", "remaining_counts"))

func get_archetypes() -> Array:
	return config_data.get("enemies", {}).get("archetypes", []).duplicate(true)

func get_enemy_scaling(kind: String) -> Dictionary:
	return config_data.get("enemies", {}).get(kind, {}).duplicate(true)

func get_trap_scaling() -> Dictionary:
	return config_data.get("traps", {}).duplicate(true)

func get_village_object_prices(object_id: String) -> Array:
	var obj = config_data.get("village", {}).get("objects", {}).get(object_id, {})
	return obj.get("stage_prices", []).duplicate(true)

func get_village_object_prerequisites(object_id: String) -> Array:
	var obj = config_data.get("village", {}).get("objects", {}).get(object_id, {})
	return obj.get("prerequisites", []).duplicate(true)

func _validate_integer_tree(value: Variant, path: String) -> String:
	if value is float and (not is_finite(value) or value != floor(value)):
		return path
	if value is Dictionary:
		for key in value:
			var error = _validate_integer_tree(value[key], path + "." + str(key))
			if not error.is_empty():
				return error
	elif value is Array:
		for i in range(value.size()):
			var error = _validate_integer_tree(value[i], path + "[%d]" % i)
			if not error.is_empty():
				return error
	return ""
