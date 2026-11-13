class_name RhythmRound
extends RefCounted

const BASE_REQUIRED_ACCURACY: float = 0.60
const MIN_REQUIRED_ACCURACY: float = 0.60
const MAX_REQUIRED_ACCURACY: float = 0.95
const STAT_ACCURACY_RANGE: float = 0.35
const ATTACK: String = "attack"
const GUARD: String = "guard"
# Rhythm tuning: deficits in either matchup raise pressure; gear advantages relieve it.
const STAT_GAP_SCALE: float = 6.0
const ADVANTAGE_RELIEF: float = 0.5
const DEPTH_RAMP: float = 28.0
const START_BPM: float = 128.0
const LATE_BPM: float = 148.0
const STAT_BPM_RANGE: float = 32.0
const BOSS_BPM_BONUS: float = 16.0
const FINAL_BOSS_BPM_BONUS: float = 24.0
const MIN_BPM: int = 96
const MAX_BPM: int = 204
const START_WINDOW: float = 0.135
const LATE_WINDOW: float = 0.100
const MIN_WINDOW: float = 0.060
const BOSS_WINDOW_PENALTY: float = 0.012
const FINAL_BOSS_WINDOW_PENALTY: float = 0.020
const START_NOTES: float = 14.0
const LATE_NOTES: float = 20.0
const BOSS_EXTRA_NOTES: int = 4
const FINAL_BOSS_EXTRA_NOTES: int = 6
# Inter-note gaps in beats. Patterns repeat, independent of the power scaling.
const PATTERNS: Dictionary = {
	"skeleton": {"name": "Marching Step", "hint": "Attacks with interruptions and guards.", "gaps": [1.0, 0.5, 0.5, 1.0, 1.5], "actions": [ATTACK, ATTACK, GUARD, ATTACK, GUARD]},
	"shadow_ghoul": {"name": "Predator's Lunge", "hint": "Three quick notes: attack, guard, attack; then a pause.", "gaps": [0.5, 0.5, 1.5], "actions": [ATTACK, GUARD, ATTACK, GUARD, ATTACK, GUARD]},
	"crypt_knight": {"name": "Knight's Combination", "hint": "Double attacks alternate with double guards.", "gaps": [1.0, 0.5, 0.5, 1.5], "actions": [ATTACK, ATTACK, GUARD, GUARD]},
	"abyss_demon": {"name": "Demonic Onslaught", "hint": "Lunges are interrupted by guards and a long pause.", "gaps": [0.5, 1.0, 0.5, 1.0, 2.0], "actions": [ATTACK, GUARD, GUARD, ATTACK, GUARD, ATTACK]},
	"cave_spider": {"name": "Spider's Lunge", "hint": "A quick pair gives way to uneven pauses.", "gaps": [0.5, 0.5, 1.25, 0.75, 1.75], "actions": [ATTACK, GUARD, ATTACK, GUARD, GUARD]},
	"dungeon_slime": {"name": "Slime Pulse", "hint": "A heavy opening and short counterattacks.", "gaps": [1.5, 1.0, 0.5, 0.5, 1.0], "actions": [GUARD, ATTACK, GUARD, ATTACK]},
	"restless_ghost": {"name": "Ghost Waltz", "hint": "Shifted accents and a lingering disappearance.", "gaps": [1.25, 0.75, 1.25, 0.5, 1.75], "actions": [GUARD, ATTACK, ATTACK, GUARD]},
	"werewolf": {"name": "Beast's Onslaught", "hint": "A quick pounce with a delay before the counter.", "gaps": [0.5, 0.5, 0.75, 1.25, 1.5, 0.5], "actions": [ATTACK, ATTACK, GUARD, ATTACK, GUARD, GUARD]},
	"goblin_raider": {"name": "Dirty Combination", "hint": "Deceptive delays between attacks and guards.", "gaps": [0.75, 1.0, 0.5, 1.5, 0.75, 1.25], "actions": [ATTACK, GUARD, GUARD, ATTACK, ATTACK, GUARD]},
	"stone_golem": {"name": "Stone Step", "hint": "Heavy accents with a short counterthrust.", "gaps": [1.5, 0.5, 1.5, 1.0, 1.0], "actions": [GUARD, ATTACK, GUARD, GUARD, ATTACK]},
	"bound_djinn": {"name": "Whirlwind Song", "hint": "The whirlwind alternates long gaps and short replies.", "gaps": [0.75, 1.5, 0.75, 1.0, 0.5, 1.5], "actions": [GUARD, ATTACK, ATTACK, GUARD, ATTACK, GUARD]},
	"boss_lich": {"name": "Lich Ritual", "hint": "Guards between single attacks and a triple sequence.", "gaps": [0.75, 1.25, 0.5, 0.5, 1.5], "actions": [GUARD, ATTACK, ATTACK, GUARD, ATTACK]},
	"boss_archon": {"name": "Abyss Onslaught", "hint": "Four quick notes alternating attack and guard.", "gaps": [0.5, 0.5, 0.5, 1.75], "actions": [ATTACK, GUARD, ATTACK, GUARD, GUARD, ATTACK, GUARD, ATTACK]},
	"final_boss_malgor": {"name": "Final Ritual", "hint": "Syncopation and quick sequences with frequent move changes.", "gaps": [0.75, 1.25, 0.5, 1.0, 0.5, 0.5, 1.75], "actions": [ATTACK, GUARD, GUARD, ATTACK, GUARD, ATTACK, ATTACK]},
}

# Each family has its original phrase and two alternatives, mixed within a round.
const PHRASE_VARIANTS: Dictionary = {
	"skeleton": [
		{"name": "Broken March", "hint": "A steady step gives way to a quick pair.", "gaps": [1.0, 1.5, 0.5, 0.5], "actions": [ATTACK, GUARD, ATTACK, GUARD]},
		{"name": "Guardian's Reply", "hint": "Guards frame single and double attacks.", "gaps": [0.75, 1.25, 1.0, 0.5, 1.5], "actions": [GUARD, ATTACK, GUARD, ATTACK, ATTACK]}
	],
	"shadow_ghoul": [
		{"name": "Feigned Leap", "hint": "A long pause precedes a quick sequence.", "gaps": [1.5, 0.5, 0.5, 1.0], "actions": [GUARD, ATTACK, GUARD, ATTACK]},
		{"name": "Ragged Hunt", "hint": "Uneven pairs with move changes.", "gaps": [0.75, 0.5, 1.75, 0.5, 1.0], "actions": [ATTACK, GUARD, GUARD, ATTACK, GUARD]}
	],
	"crypt_knight": [
		{"name": "Parry", "hint": "Two guards give way to a pair of counterattacks.", "gaps": [0.5, 1.5, 0.5, 1.0], "actions": [GUARD, GUARD, ATTACK, ATTACK]},
		{"name": "Delayed Thrust", "hint": "Single moves with a pause before the thrust.", "gaps": [1.25, 0.75, 1.5, 0.5, 0.5], "actions": [ATTACK, GUARD, ATTACK, GUARD, GUARD]}
	],
	"abyss_demon": [
		{"name": "Burning Wings", "hint": "Short wingbeats end with a lingering pause.", "gaps": [0.5, 0.75, 0.5, 1.25, 2.0], "actions": [GUARD, ATTACK, GUARD, ATTACK, ATTACK]},
		{"name": "Reverse Onslaught", "hint": "A sequence of guards and counters shifts the accent.", "gaps": [1.0, 0.5, 1.5, 0.5, 1.0], "actions": [GUARD, GUARD, ATTACK, ATTACK, GUARD]}
	],
	"cave_spider": [
		{"name": "Sticky Pause", "hint": "A long delay gives way to two short steps.", "gaps": [1.75, 0.5, 0.5, 1.0], "actions": [GUARD, ATTACK, GUARD, ATTACK]},
		{"name": "Dash", "hint": "Three short intervals with changing moves.", "gaps": [0.5, 0.75, 0.5, 1.5, 1.0], "actions": [ATTACK, GUARD, GUARD, ATTACK, GUARD]}
	],
	"dungeon_slime": [
		{"name": "Rebound", "hint": "A steady sway gives way to a short rebound.", "gaps": [1.0, 1.5, 0.5, 1.0], "actions": [ATTACK, GUARD, GUARD, ATTACK]},
		{"name": "Double Wave", "hint": "Two pairs are separated by a long pause.", "gaps": [0.5, 1.75, 0.5, 1.25], "actions": [GUARD, ATTACK, ATTACK, GUARD]}
	],
	"restless_ghost": [
		{"name": "Echo", "hint": "A single move echoes as a quick pair.", "gaps": [1.5, 0.75, 0.5, 1.25], "actions": [ATTACK, GUARD, ATTACK, GUARD]},
		{"name": "Lost Beat", "hint": "Shifted intervals break up the steady step.", "gaps": [0.75, 1.75, 0.5, 1.0, 1.25], "actions": [GUARD, GUARD, ATTACK, GUARD, ATTACK]}
	],
	"werewolf": [
		{"name": "Double Bite", "hint": "Quick attacks alternate with paired guards.", "gaps": [0.5, 1.0, 0.5, 1.5], "actions": [ATTACK, ATTACK, GUARD, GUARD]},
		{"name": "Hunter's Patience", "hint": "A long pause is followed by frequent move changes.", "gaps": [1.75, 0.5, 0.75, 0.5, 1.0], "actions": [GUARD, ATTACK, GUARD, ATTACK, GUARD]}
	],
	"goblin_raider": [
		{"name": "Feigned Swing", "hint": "The expected attack is delayed by half a beat.", "gaps": [1.5, 0.75, 0.5, 1.25], "actions": [GUARD, ATTACK, ATTACK, GUARD]},
		{"name": "Crooked Sequence", "hint": "Uneven pairs alternate defense and attack.", "gaps": [0.5, 1.25, 0.75, 1.5, 0.5], "actions": [ATTACK, GUARD, ATTACK, GUARD, GUARD]}
	],
	"stone_golem": [
		{"name": "Cave-In", "hint": "A quick pair cuts between heavy accents.", "gaps": [2.0, 0.5, 0.5, 1.5], "actions": [GUARD, ATTACK, GUARD, ATTACK]},
		{"name": "Stone Reply", "hint": "Counterattacks arrive with uneven delays.", "gaps": [1.0, 1.75, 0.75, 1.0, 0.5], "actions": [ATTACK, GUARD, GUARD, ATTACK, GUARD]}
	],
	"bound_djinn": [
		{"name": "Headwind", "hint": "A short reply gives way to a lingering whirlwind.", "gaps": [0.5, 1.5, 0.75, 1.25], "actions": [ATTACK, GUARD, GUARD, ATTACK]},
		{"name": "Twisted Beat", "hint": "Syncopation with move changes within the sequence.", "gaps": [1.25, 0.5, 0.75, 1.5, 0.5], "actions": [GUARD, ATTACK, GUARD, ATTACK, ATTACK]}
	],
	"boss_lich": [
		{"name": "Seal of Silence", "hint": "A pause before a short defensive sequence.", "gaps": [1.75, 0.5, 0.5, 0.75, 1.0], "actions": [ATTACK, GUARD, GUARD, ATTACK, GUARD]},
		{"name": "Reply of the Dead", "hint": "Shifted accents and two quick replies.", "gaps": [0.5, 1.25, 0.75, 0.5, 1.5], "actions": [GUARD, ATTACK, GUARD, ATTACK, ATTACK]}
	],
	"boss_archon": [
		{"name": "Rift", "hint": "Three quick transitions and a heavy ending.", "gaps": [0.5, 0.75, 0.5, 2.0], "actions": [GUARD, ATTACK, GUARD, ATTACK]},
		{"name": "Reverse Wave", "hint": "Paired guards give way to an uneven counter.", "gaps": [1.25, 0.5, 0.5, 1.0, 0.75], "actions": [GUARD, GUARD, ATTACK, ATTACK, GUARD]}
	],
	"final_boss_malgor": [
		{"name": "Broken Ritual", "hint": "Uneven pairs, a quick triple and a long pause.", "gaps": [0.5, 1.25, 0.5, 0.75, 0.5, 1.75], "actions": [GUARD, ATTACK, GUARD, GUARD, ATTACK, ATTACK]},
		{"name": "Final Reply", "hint": "Syncopation with frequent attack and guard changes.", "gaps": [1.5, 0.5, 0.75, 0.5, 1.25, 0.5], "actions": [ATTACK, GUARD, ATTACK, GUARD, GUARD, ATTACK]}
	]
}

const ENEMY_STYLES: Dictionary = {
	"abyss_demon": {
		"pattern": "abyss_demon",
		"name": "Demonic Onslaught"
	},
	"cave_spider": {
		"pattern": "cave_spider",
		"name": "Spider's Lunge"
	},
	"dungeon_slime": {
		"pattern": "dungeon_slime",
		"name": "Slime Pulse"
	},
	"restless_ghost": {
		"pattern": "restless_ghost",
		"name": "Ghost Waltz"
	},
	"werewolf": {
		"pattern": "werewolf",
		"name": "Beast's Onslaught"
	},
	"goblin_raider": {
		"pattern": "goblin_raider",
		"name": "Dirty Combination"
	},
	"stone_golem": {
		"pattern": "stone_golem",
		"name": "Stone Step"
	},
	"bound_djinn": {
		"pattern": "bound_djinn",
		"name": "Whirlwind Song"
	}
}

var settings: Dictionary
var equipment_bonuses: Dictionary
var note_times: Array[float] = []
var judged: Array[bool] = []
var accented: Array[bool] = []
var note_actions: Array[String] = []
var hits: int = 0
var misses: int = 0
var stray_presses: int = 0
var elapsed: float = 0.0
var finished: bool = false
var recovery_note: int = -1

static func pattern_id_for(monster: Dictionary) -> String:
	if monster.get("is_final", false):
		return "final_boss_malgor"
	var id := str(monster.get("id", ""))
	if ENEMY_STYLES.has(id):
		return str(ENEMY_STYLES[id].pattern)
	if PATTERNS.has(id):
		return id
	return "boss_lich" if monster.get("is_boss", false) else "skeleton"

static func variation_seed_for(monster: Dictionary) -> int:
	if monster.has("rhythm_seed"):
		return int(monster.rhythm_seed) & 0x7fffffff
	var encounter_id := str(monster.get("encounter_id", ""))
	# Encounter IDs are saved already: retries and reloads must not reroll the song.
	# Mix the entire ID: a short string hash overweights their shared _s0 suffix.
	return 0 if encounter_id.is_empty() else (encounter_id.sha256_text().left(8).hex_to_int() & 0x7fffffff)

static func phrase_plan_for(pattern_id: String, monster: Dictionary, note_count: int, minimum_gap: float, required_accuracy: float) -> Dictionary:
	var phrases: Array = [PATTERNS[pattern_id]]
	phrases.append_array(PHRASE_VARIANTS.get(pattern_id, []))
	var seed_value := variation_seed_for(monster)
	var phrase_rng := RandomNumberGenerator.new()
	phrase_rng.seed = seed_value
	var phrase_index := seed_value % phrases.size()
	var first_phrase: Dictionary = phrases[phrase_index]
	var gaps: Array[float] = []
	var actions: Array[String] = []
	var phrase_order: Array[int] = []
	while actions.size() < note_count:
		var phrase: Dictionary = phrases[phrase_index]
		phrase_order.append(phrase_index)
		var length := maxi(phrase.gaps.size(), phrase.actions.size())
		for index in range(length):
			if actions.size() == note_count:
				break
			gaps.append(maxf(float(phrase.gaps[index % phrase.gaps.size()]), minimum_gap))
			actions.append(str(phrase.actions[index % phrase.actions.size()]))
		if phrases.size() > 1:
			# Change phrase after each block, without touching the floor/global RNG.
			phrase_index = (phrase_index + 1 + phrase_rng.randi_range(0, phrases.size() - 2)) % phrases.size()
	_balance_actions_for_target(actions, required_accuracy)
	return {"gaps": gaps, "actions": actions, "phrase_order": phrase_order,
		"variation_name": TranslationServer.translate(first_phrase.name), "variation_hint": TranslationServer.translate(first_phrase.hint)}

static func matchup_for(player_power: int, monster_power: int, monster: Dictionary = {}, player_stats: Dictionary = {}) -> Dictionary:
	# Legacy callers/saves with only power remain playable without rewriting their data.
	var player_attack := maxi(1, int(player_stats.get("attack", player_power)))
	var player_defense := maxi(1, int(player_stats.get("defense", player_power)))
	var monster_attack := maxi(1, int(monster.get("attack", monster_power)))
	var monster_defense := maxi(1, int(monster.get("defense", monster_power)))
	var attack_gap := monster_defense - player_attack
	var defense_gap := monster_attack - player_defense
	var attack_pressure := float(attack_gap) / (absf(float(attack_gap)) + STAT_GAP_SCALE)
	var defense_pressure := float(defense_gap) / (absf(float(defense_gap)) + STAT_GAP_SCALE)
	# A very strong weapon cannot completely cancel a serious lack of armor, or vice versa.
	var pressure := (maxf(0.0, attack_pressure) + maxf(0.0, defense_pressure)
		+ ADVANTAGE_RELIEF * (minf(0.0, attack_pressure) + minf(0.0, defense_pressure))) * 0.5
	return {"player_attack": player_attack, "player_defense": player_defense,
		"monster_attack": monster_attack, "monster_defense": monster_defense,
		"attack_gap": attack_gap, "defense_gap": defense_gap, "matchup_pressure": pressure}

static func settings_for(player_power: int, monster_power: int, monster: Dictionary = {}, equipment: Array = [], player_stats: Dictionary = {}) -> Dictionary:
	var bonuses := RhythmEquipment.bonuses_for(equipment)
	var deficit := maxi(0, monster_power - player_power)
	var matchup := matchup_for(player_power, monster_power, monster, player_stats)
	var pressure: float = matchup.matchup_pressure
	# Use whole percentages so the visible target is exactly the rule used for victory.
	var base_percent := roundi(BASE_REQUIRED_ACCURACY * 100.0)
	var stat_percent := roundi(STAT_ACCURACY_RANGE * 100.0)
	var target_percent := clampi(roundi(base_percent + pressure * stat_percent), roundi(MIN_REQUIRED_ACCURACY * 100.0), roundi(MAX_REQUIRED_ACCURACY * 100.0))
	var is_final := bool(monster.get("is_final", false))
	var is_boss := bool(monster.get("is_boss", false)) or is_final
	# q is the existing global depth: D1/F1 = 0, D1/F100 = 99, D2/F1 = 100.
	var depth := maxi(0, int(monster.get("q", 0)))
	var progression := 1.0 - exp(-float(depth) / DEPTH_RAMP)
	var boss_bpm := FINAL_BOSS_BPM_BONUS if is_final else (BOSS_BPM_BONUS if is_boss else 0.0)
	var base_bpm := lerpf(START_BPM, LATE_BPM, progression)
	var bpm := clampi(roundi((base_bpm + pressure * STAT_BPM_RANGE + boss_bpm) * (1.0 - float(bonuses.tempo))), MIN_BPM, MAX_BPM)
	var interval := 60.0 / float(bpm)
	var pattern_id := pattern_id_for(monster)
	var pattern: Dictionary = PATTERNS[pattern_id]
	var style: Dictionary = ENEMY_STYLES.get(str(monster.get("id", "")), {})
	# Ordinary enemies already mix shorter beats early; bosses use their full pattern immediately.
	var minimum_gap := 0.5 if is_boss else lerpf(0.75, 0.5, clampf(float(depth) / 12.0, 0.0, 1.0))
	var extra_notes := FINAL_BOSS_EXTRA_NOTES if is_final else (BOSS_EXTRA_NOTES if is_boss else 0)
	var note_count := clampi(roundi(lerpf(START_NOTES, LATE_NOTES, progression) + pressure * 6.0) + extra_notes, 10, 34)
	var required_accuracy := float(target_percent) / 100.0
	var plan := phrase_plan_for(pattern_id, monster, note_count, minimum_gap, required_accuracy)
	var note_gaps: Array[float] = plan.gaps
	var shortest_gap: float = note_gaps.min()
	# Separate adjacent hit windows so a double tap cannot claim both notes at once.
	var boss_window := FINAL_BOSS_WINDOW_PENALTY if is_final else (BOSS_WINDOW_PENALTY if is_boss else 0.0)
	var window := maxf(MIN_WINDOW, lerpf(START_WINDOW, LATE_WINDOW, progression) - pressure * lerpf(0.045, 0.030, progression) - boss_window)
	var base_hit_window := minf(window, shortest_gap * interval * 0.42)
	var max_hit_window := shortest_gap * interval * 0.49
	var hit_window := minf(base_hit_window * (1.0 + float(bonuses.precision)), max_hit_window)
	var result := {
		"deficit": deficit,
		"required_accuracy": required_accuracy,
		"bpm": bpm,
		"interval": interval,
		"note_count": note_count,
		"hit_window": hit_window,
		"base_hit_window": base_hit_window,
		"max_hit_window": max_hit_window,
		"preview_multiplier": lerpf(1.05, 0.90, progression) * (1.0 - maxf(pressure, 0.0) * 0.08 - (0.08 if is_final else (0.05 if is_boss else 0.0))) * (1.0 + float(bonuses.foresight)),
		"boss_bpm_bonus": boss_bpm,
		"progression": progression,
		"note_gaps": note_gaps,
		"note_actions": plan.actions,
		"phrase_order": plan.phrase_order,
		"variation_name": plan.variation_name,
		"pattern_id": pattern_id,
		"pattern_name": TranslationServer.translate(style.get("name", pattern.name)),
		"pattern_hint": str(plan.variation_hint) + " " + TranslationServer.translate("UI_RHYTHM_PHRASE_CHANGES"),
		"raw_damage_on_fail": maxi(1, deficit) * 10,
	}
	result.merge(matchup)
	return result

func _init(player_power: int, monster_power: int, monster: Dictionary = {}, equipment: Array = [], player_stats: Dictionary = {}) -> void:
	# Freeze the equipped effects for this round, independent of later item mutations.
	equipment_bonuses = RhythmEquipment.bonuses_for(equipment)
	settings = settings_for(player_power, monster_power, monster, equipment, player_stats)
	var interval: float = settings.interval
	var gaps: Array = settings.note_gaps
	var actions: Array = settings.note_actions
	var beat := 4.0
	for i in range(int(settings.note_count)):
		note_times.append(beat * interval)
		note_actions.append(str(actions[i % actions.size()]))
		judged.append(false)
		accented.append(i == 0 or float(gaps[(i - 1) % gaps.size()]) >= 1.5)
		beat += float(gaps[i % gaps.size()])

static func _balance_actions_for_target(actions: Array[String], required_accuracy: float) -> void:
	# A lower target must not turn an attack-heavy pattern into a one-button win.
	# Keep the opening phrase and timing, changing only excess actions at the tail.
	var maximum_same_action := ceili(actions.size() * required_accuracy) - 1
	for action in [ATTACK, GUARD]:
		var excess := actions.count(action) - maximum_same_action
		if excess <= 0:
			continue
		for index in range(actions.size() - 1, -1, -1):
			if actions[index] == action:
				actions[index] = GUARD if action == ATTACK else ATTACK
				excess -= 1
				if excess == 0:
					break

func hit_window_for_note(index: int) -> float:
	var bonus := float(equipment_bonuses.precision)
	if index < 3:
		bonus += float(equipment_bonuses.opening)
	if index == recovery_note:
		bonus += float(equipment_bonuses.recovery)
	return minf(float(settings.base_hit_window) * (1.0 + minf(RhythmEquipment.MAX_WINDOW_BONUS, bonus)), float(settings.max_hit_window))

func next_hit_window() -> float:
	for i in range(judged.size()):
		if not judged[i]:
			return hit_window_for_note(i)
	return float(settings.hit_window)

func advance_to(time: float) -> void:
	if finished:
		return
	elapsed = maxf(elapsed, time)
	for i in range(note_times.size()):
		if not judged[i] and elapsed > note_times[i] + hit_window_for_note(i):
			judged[i] = true
			misses += 1
			recovery_note = -1
			for j in range(i + 1, judged.size()):
				if not judged[j]:
					recovery_note = j
					break
	finished = hits + misses == note_times.size()

func press_at(time: float, action: String = ATTACK) -> String:
	advance_to(time)
	if finished:
		return "finished"
	for i in range(note_times.size()):
		if not judged[i] and absf(elapsed - note_times[i]) <= hit_window_for_note(i):
			judged[i] = true
			if action != note_actions[i]:
				misses += 1
				recovery_note = i + 1 if i + 1 < note_times.size() else -1
				finished = hits + misses == note_times.size()
				return "wrong"
			hits += 1
			finished = hits + misses == note_times.size()
			return "perfect" if absf(elapsed - note_times[i]) <= hit_window_for_note(i) * 0.4 else "hit"
	# The four count-in beats are practice, without a penalty.
	if elapsed < note_times[0] - hit_window_for_note(0):
		return "wait"
	stray_presses += 1
	return "miss"

func accuracy() -> float:
	return float(hits) / (float(note_times.size()) + float(stray_presses) * (1.0 - float(equipment_bonuses.restraint)))

func outcome() -> Dictionary:
	var success := finished and accuracy() >= float(settings.required_accuracy)
	return {"success": success, "accuracy": accuracy(), "required_accuracy": float(settings.required_accuracy), "hits": hits, "misses": misses,
		"stray_presses": stray_presses, "raw_damage": 0 if success else int(settings.raw_damage_on_fail)}
