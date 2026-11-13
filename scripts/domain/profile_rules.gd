# scripts/domain/profile_rules.gd
class_name ProfileRules
extends RefCounted

static func settle_run(starting_gold: int, current_gold: int, outcome: RunMode.Outcome, final_boss_bonus: int = 0) -> Dictionary:
	var s = maxi(0, starting_gold)
	var c = maxi(0, current_gold)
	var settled_gold = c
	var eligible_bonus = 0

	match outcome:
		RunMode.Outcome.RETIRED:
			settled_gold = c
		RunMode.Outcome.DEATH:
			if c > s:
				var gain = c - s
				var preserved = int(round(float(gain) / 2.0))
				settled_gold = s + preserved
			else:
				settled_gold = c
		RunMode.Outcome.SUCCESS:
			eligible_bonus = maxi(0, final_boss_bonus)
			settled_gold = c + eligible_bonus
		_:
			# Unknown outcome rejected with no mutation
			return {
				"starting_gold": s,
				"current_gold": c,
				"outcome": outcome,
				"settled_gold": s,
				"eligible_bonus": 0,
				"net_gain": 0,
				"valid": false
			}

	return {
		"starting_gold": s,
		"current_gold": c,
		"outcome": outcome,
		"settled_gold": settled_gold,
		"eligible_bonus": eligible_bonus,
		"net_gain": settled_gold - s,
		"valid": true
	}
