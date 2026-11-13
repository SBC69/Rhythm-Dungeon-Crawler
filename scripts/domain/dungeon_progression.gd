# Compatibility API: all calculations share the encounter factory and canonical balance file.
class_name DungeonProgression
extends RefCounted

static func _balance() -> Dictionary:
	var cfg = BalanceConfig.new()
	cfg.load_from_file()
	return cfg.config_data

static func calculate_q(depth: int, floor_num: int, is_timed: bool = true) -> int:
	return EncounterFactory.calculate_q_for_context({"dungeon_index": depth, "floor_number": floor_num, "mode": "timed" if is_timed else "endless"}, _balance())

static func calculate_normal_enemy_power(depth: int, floor_num: int, room_num: int, archetype_offset: int = 0, is_timed: bool = true) -> int:
	return EncounterFactory.enemy_power("regular", calculate_q(depth, floor_num, is_timed), room_num, archetype_offset, _balance())

static func calculate_elite_enemy_power(depth: int, floor_num: int, room_num: int, arg4 = 0, arg5: bool = true) -> int:
	var offset = 0 if arg4 is bool else int(arg4)
	var timed = arg4 if arg4 is bool else arg5
	return EncounterFactory.enemy_power("elite", calculate_q(depth, floor_num, timed), room_num, offset, _balance())

static func calculate_floor_boss_power(depth: int, floor_num: int, is_timed: bool = true) -> int:
	return EncounterFactory.enemy_power("floor_boss", calculate_q(depth, floor_num, is_timed), 1, 0, _balance())

static func calculate_final_boss_power(depth: int, is_timed: bool = true) -> int:
	var balance = _balance()
	return EncounterFactory.enemy_power("final_boss", calculate_q(depth, int(balance.modes.timed.floor_limit), is_timed), 1, 0, balance)

static func calculate_trap_stats(base_dc: int, base_damage: int, depth: int, floor_num: int, is_timed: bool = true) -> Dictionary:
	var q = calculate_q(depth, floor_num, is_timed)
	var rule = _balance().traps
	return {"dc": mini(int(rule.dc_cap), base_dc + int(q / int(rule.dc_depth_divisor))), "raw_damage": mini(int(rule.raw_damage_cap), base_damage + int(q / int(rule.damage_depth_divisor))), "q": q}
