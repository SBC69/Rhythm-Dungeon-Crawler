# scripts/domain/combat_rules.gd
class_name CombatRules
extends RefCounted

static func calculate_damage(raw_damage: int, armor_reduction: int, current_hp: int) -> Dictionary:
	if raw_damage <= 0:
		return {
			"raw_damage": 0,
			"armor_reduction": armor_reduction,
			"resolved_damage": 0,
			"hp_lost": 0,
			"remaining_hp": current_hp,
			"is_lethal": false
		}
	
	var resolved = maxi(1, raw_damage - armor_reduction)
	var lost = mini(current_hp, resolved)
	var lethal = (current_hp <= resolved)
	
	return {
		"raw_damage": raw_damage,
		"armor_reduction": armor_reduction,
		"resolved_damage": resolved,
		"hp_lost": lost,
		"remaining_hp": maxi(0, current_hp - resolved),
		"is_lethal": lethal
	}

static func calculate_combat_comparison(player_pow: int, monster_pow: int, armor_reduction: int, current_hp: int) -> Dictionary:
	var diff = monster_pow - player_pow
	var is_auto_win = (player_pow >= monster_pow)
	var raw_penalty = maxi(0, diff * 10)
	var dmg_forecast = calculate_damage(raw_penalty, armor_reduction, current_hp)
	
	return {
		"player_power": player_pow,
		"monster_power": monster_pow,
		"difference": diff,
		"is_auto_win": is_auto_win,
		"damage_forecast": dmg_forecast
	}

static func calculate_escape_dc(power_diff: int) -> int:
	return clampi(6 + power_diff, 7, 11)

static func evaluate_escape_roll(d1: int, d2: int, dice_bonus: int, target_dc: int) -> Dictionary:
	var is_doubles = (d1 == d2)
	var sum = d1 + d2 + dice_bonus
	var is_critical = is_doubles or (d1 + d2 == 12)
	var is_success = is_critical or (sum >= target_dc)
	
	return {
		"d1": d1,
		"d2": d2,
		"dice_bonus": dice_bonus,
		"sum": sum,
		"target_dc": target_dc,
		"is_doubles": is_doubles,
		"is_critical": is_critical,
		"is_success": is_success
	}
