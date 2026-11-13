class_name TestRhythm
extends RefCounted

class FailingStore extends SaveStore:
	func save_envelope(_envelope: Dictionary) -> bool:
		return false

static func register_tests(registry: Dictionary) -> void:
	registry["T-RHYTHM-ACTIONS"] = {"fn": Callable(TestRhythm, "test_actions"), "expected_failure": false, "desc": "Attack/guard patterns require the right input and cannot be won by a single repeated action"}
	registry["T-RHYTHM-PROGRESSION"] = {"fn": Callable(TestRhythm, "test_progression"), "expected_failure": false, "desc": "Demanding first floors, gradual progression, cross-dungeon depth, and legacy encounter fallback"}
	registry["T-RHYTHM-STAT-MATCHUPS"] = {"fn": Callable(TestRhythm, "test_stat_matchups"), "expected_failure": false, "desc": "Independent attack/defense deficits, gear upgrades, buffs and live preview/round agreement"}
	registry["T-RHYTHM-BOSS-PRESSURE"] = {"fn": Callable(TestRhythm, "test_boss_pressure"), "expected_failure": false, "desc": "Boss and final-boss bonuses apply at equal stats and with superior gear; extreme timing remains playable"}
	registry["T-RHYTHM-DYNAMIC-TARGET"] = {"fn": Callable(TestRhythm, "test_dynamic_target"), "expected_failure": false, "desc": "Signed stat deficits set a bounded victory target shared by forecast, live round, progress and outcome"}
	registry["T-RHYTHM-VARIATIONS"] = {"fn": Callable(TestRhythm, "test_variations"), "expected_failure": false, "desc": "Species-specific phrase pools create varied seeded songs with stable retries, exact forecasts, safe windows and mixed inputs"}
	registry["T-RHYTHM-RETRY"] = {"fn": Callable(TestRhythm, "test_retry"), "expected_failure": false, "desc": "Failed regular, boss and final-boss fights preserve doors, persist HP loss, allow retry, and roll back failed saves"}
	registry["T-RHYTHM-RULES"] = {"fn": Callable(TestRhythm, "test_rules"), "expected_failure": false, "desc": "Power scaling, hit windows, missed beats, anti-spam, attack/block inputs, and the equal-stat victory threshold"}
	registry["T-RHYTHM-COMBAT"] = {"fn": Callable(TestRhythm, "test_combat"), "expected_failure": false, "desc": "Real keyboard/mouse/gamepad hits, boss rewards, damage, death, and cancellation"}
	registry["T-RHYTHM-PATTERNS"] = {"fn": Callable(TestRhythm, "test_patterns"), "expected_failure": false, "desc": "Distinct enemy rhythms, power scaling, non-overlapping windows, pauses, and fallback IDs"}
	registry["T-RHYTHM-PATTERN-INPUT"] = {"fn": Callable(TestRhythm, "test_pattern_input"), "expected_failure": false, "desc": "Each enemy and boss pattern completes through actual keyboard/mouse/gamepad input"}

static func test_actions(fix: GameFixture) -> void:
	for id in RhythmRound.PATTERNS:
		for powers in [[10, 10], [100000, 1], [1, 100000]]:
			for action in [RhythmRound.ATTACK, RhythmRound.GUARD]:
				var round_state := RhythmRound.new(powers[0], powers[1], {"id": id})
				fix.assert_true(round_state.note_actions.has(RhythmRound.ATTACK) and round_state.note_actions.has(RhythmRound.GUARD), "Every enemy combines attacks and blocks")
				for i in range(round_state.note_times.size()):
					round_state.press_at(round_state.note_times[i], action)
				fix.assert_false(round_state.outcome().success, "Even at the 60% minimum, perfect timing on one button cannot replace reading the note types")
	var wrong := RhythmRound.new(10, 10)
	fix.assert_eq(wrong.press_at(wrong.note_times[0], RhythmRound.GUARD), "wrong", "Wrong action is rejected even at perfect timing")
	fix.assert_eq(wrong.hits, 0, "Wrong action grants no hit")
	fix.assert_eq(wrong.misses, 1, "Wrong action consumes the note as one miss")
	wrong.advance_to(wrong.note_times[1] - 0.1)
	fix.assert_eq(wrong.misses, 1, "Wrong-action miss is not charged twice")
	var equal := RhythmRound.settings_for(10, 10, {"q": 99})
	fix.assert_true(equal.bpm > 122 and equal.hit_window < 0.11 and equal.note_count > 14, "Equal-power combat is faster, tighter, and longer than the old rhythm")
	await fix.teardown()

static func test_progression(fix: GameFixture) -> void:
	for id in RhythmRound.PATTERNS:
		var previous: Dictionary = {}
		for depth in [0, 1, 4, 9, 19, 24, 49, 99, 100, 199, 499]:
			var round_state := RhythmRound.new(10, 10, {"id": id, "q": depth})
			var settings: Dictionary = round_state.settings
			if not previous.is_empty():
				fix.assert_true(settings.bpm >= previous.bpm, "Tempo grows with depth for every pattern")
				fix.assert_true(settings.hit_window <= previous.hit_window, "Timing gradually tightens")
				fix.assert_true(settings.note_count >= previous.note_count, "Rounds gradually gain notes")
				fix.assert_true(settings.preview_multiplier <= previous.preview_multiplier, "Extra early preview gradually tapers")
			previous = settings
			for index in range(1, round_state.note_times.size()):
				fix.assert_true(round_state.note_times[index] - round_state.note_times[index - 1] > round_state.hit_window_for_note(index) + round_state.hit_window_for_note(index - 1), "Progression never overlaps hit windows")
		var first := RhythmRound.new(10, 10, {"id": id, "q": 0})
		fix.assert_eq(first.settings.bpm, 128, "First-floor equal-stat combat starts at a demanding 128 BPM")
		fix.assert_eq(first.note_times.size(), 14, "First-floor fights already require a sustained sequence")
		fix.assert_true(first.settings.hit_window >= 0.12 and first.settings.hit_window <= 0.14, "First floor requires precision instead of the old 200ms allowance")
		for index in range(1, first.note_times.size()):
			fix.assert_true(first.note_times[index] - first.note_times[index - 1] >= 0.75 * float(first.settings.interval) - 0.000001, "Ordinary early species introduce shorter beats without immediate half-beat bursts")
	for depth in range(100):
		var current := RhythmRound.settings_for(10, 10, {"q": depth})
		var next := RhythmRound.settings_for(10, 10, {"q": depth + 1})
		fix.assert_true(next.bpm - current.bpm <= 2, "No sudden tempo jump between floors")
		fix.assert_true(current.hit_window - next.hit_window < 0.015, "No sudden timing-window cliff")
		var easy := RhythmRound.settings_for(30, 10, {"q": depth})
		var hard := RhythmRound.settings_for(10, 30, {"q": depth})
		fix.assert_true(easy.bpm < hard.bpm and easy.hit_window > hard.hit_window, "Power advantage still matters at every depth")
	var early_hard := RhythmRound.settings_for(1, 100000, {"q": 0})
	fix.assert_true(early_hard.bpm >= 155 and early_hard.bpm <= RhythmRound.MAX_BPM, "A huge early deficit is already threatening while tempo remains bounded")
	var main = await fix.create_main()
	var gm = fix.root.get_node("GameManager")
	gm.current_floor = 7
	gm.current_dungeon_id = "ash_forges"
	var legacy := {"id": "shadow_ghoul", "power": 10}
	main.router.show_combat(legacy)
	fix.assert_eq(main.monster_view.current_monster.q, 106, "Old encounters infer global depth from dungeon and floor")
	var preview := RhythmRound.settings_for(gm.get_total_player_power(), 10, main.monster_view.current_monster, main.monster_view._rhythm_equipment(), gm.get_combat_stats())
	main.monster_view._start_rhythm()
	fix.assert_eq(main.monster_view.rhythm_game.round_state.settings.bpm, preview.bpm, "Battle tempo matches the depth-aware pre-fight forecast")
	await fix.teardown()

static func test_stat_matchups(fix: GameFixture) -> void:
	var monster := {"id": "skeleton", "attack": 10, "defense": 10, "q": 0}
	var equal := RhythmRound.settings_for(10, 10, monster, [], {"attack": 10, "defense": 10})
	var weak_attack := RhythmRound.settings_for(10, 10, monster, [], {"attack": 4, "defense": 10})
	var weak_defense := RhythmRound.settings_for(10, 10, monster, [], {"attack": 10, "defense": 4})
	var both_weak := RhythmRound.settings_for(10, 10, monster, [], {"attack": 4, "defense": 4})
	var superior := RhythmRound.settings_for(10, 10, monster, [], {"attack": 16, "defense": 16})
	for deficient in [weak_attack, weak_defense]:
		fix.assert_true(deficient.bpm > equal.bpm and deficient.hit_window < equal.hit_window, "Either attack or defense deficit independently makes rhythm harder at the same aggregate power")
	fix.assert_true(both_weak.bpm > weak_attack.bpm and both_weak.hit_window < weak_attack.hit_window, "Both deficits compound")
	fix.assert_true(superior.bpm < equal.bpm and superior.hit_window > equal.hit_window, "Better stats ease the fight rather than being punished as an absolute difference")
	var unarmored := RhythmRound.settings_for(10, 10, monster, [], {"attack": 100000, "defense": 1})
	fix.assert_true(unarmored.matchup_pressure > 0, "Extreme weapon strength cannot erase an armor deficit")
	var previous: Dictionary = equal
	for gap in [1, 2, 4, 8, 16, 1000]:
		var stronger := {"attack": 10 + gap, "defense": 10 + gap}
		var next := RhythmRound.settings_for(10, 10, stronger, [], {"attack": 10, "defense": 10})
		fix.assert_true(next.matchup_pressure > previous.matchup_pressure and next.bpm >= previous.bpm and next.hit_window <= previous.hit_window, "Increasing deficits never make combat easier")
		previous = next
	var legacy := RhythmRound.settings_for(7, 9, {})
	fix.assert_eq([legacy.player_attack, legacy.player_defense, legacy.monster_attack, legacy.monster_defense], [7, 7, 9, 9], "Old callers and saved enemies fall back to their frozen power")
	var main = await fix.create_main()
	var gm = fix.root.get_node("GameManager")
	var before: Dictionary = gm.get_combat_stats()
	gm.equipped_weapon.power += 3
	var weapon_upgrade: Dictionary = gm.get_combat_stats()
	fix.assert_eq(weapon_upgrade.attack, before.attack + 3, "Weapon upgrade increases attack")
	fix.assert_eq(weapon_upgrade.defense, before.defense, "Weapon upgrade does not masquerade as armor")
	gm.equipped_armor.power += 4
	var armor_upgrade: Dictionary = gm.get_combat_stats()
	fix.assert_eq(armor_upgrade.defense, before.defense + 4, "Armor upgrade increases defense")
	fix.assert_eq(armor_upgrade.attack, weapon_upgrade.attack, "Armor does not masquerade as weapon attack")
	gm.temp_combat_power_buff = 3
	var buffed: Dictionary = gm.get_combat_stats()
	fix.assert_eq(buffed.attack, armor_upgrade.attack + 3, "Combat buff helps attack")
	fix.assert_eq(buffed.defense, armor_upgrade.defense, "Attack buff does not inflate defense")
	await fix.enter_regular_encounter(main, 14)
	var preview := RhythmRound.settings_for(gm.get_total_player_power(), 14, main.monster_view.current_monster, main.monster_view._rhythm_equipment(), gm.get_combat_stats())
	main.monster_view._start_rhythm()
	fix.assert_eq(main.monster_view.rhythm_game.round_state.settings, preview, "Live fight freezes exactly the four-stat settings shown in its preview")
	var frozen: Dictionary = main.monster_view.rhythm_game.round_state.settings.duplicate(true)
	gm.equipped_weapon.power += 100
	fix.assert_eq(main.monster_view.rhythm_game.round_state.settings, frozen, "Later item mutation cannot change an active rhythm")
	await fix.teardown()

static func test_boss_pressure(fix: GameFixture) -> void:
	for hero in [{"attack": 10, "defense": 10}, {"attack": 1000, "defense": 1000}]:
		var normal := RhythmRound.settings_for(10, 10, {"id": "skeleton", "attack": 10, "defense": 10}, [], hero)
		var boss := RhythmRound.settings_for(10, 10, {"id": "skeleton", "attack": 10, "defense": 10, "is_boss": true}, [], hero)
		var final := RhythmRound.settings_for(10, 10, {"attack": 10, "defense": 10, "is_final": true}, [], hero)
		fix.assert_eq(boss.pattern_id, normal.pattern_id, "Boss bonus does not depend on picking a different species pattern")
		fix.assert_true(boss.bpm > normal.bpm and boss.hit_window < normal.hit_window and boss.note_count > normal.note_count, "Boss is faster, stricter and longer even with identical stats or superior player gear")
		fix.assert_true(final.bpm > boss.bpm and final.hit_window <= boss.hit_window and final.note_count > boss.note_count, "Final boss adds a stronger bonus")
		fix.assert_true(boss.preview_multiplier < normal.preview_multiplier, "Boss gives less advance preview")
	for depth in [0, 99, 499]:
		for flags in [{}, {"is_boss": true}, {"is_final": true}]:
			var monster := {"id": "shadow_ghoul", "attack": 1000000, "defense": 1000000, "q": depth}
			monster.merge(flags)
			var round_state := RhythmRound.new(1, 1000000, monster, [], {"attack": 1, "defense": 1})
			fix.assert_true(round_state.settings.bpm <= 204 and round_state.settings.hit_window >= 0.06, "Extreme matches retain a finite playable tempo and at least 60ms timing")
			for index in range(1, round_state.note_times.size()):
				fix.assert_true(round_state.note_times[index] - round_state.note_times[index - 1] > round_state.hit_window_for_note(index) + round_state.hit_window_for_note(index - 1), "Boss bonuses never overlap adjacent note windows")
			for index in range(round_state.note_times.size()):
				round_state.press_at(round_state.note_times[index], round_state.note_actions[index])
			fix.assert_true(round_state.outcome().success, "Hard boss rhythms can still be won with correct inputs")
	await fix.teardown()

static func test_dynamic_target(fix: GameFixture) -> void:
	var cases := [
		{"hero": {"attack": 10, "defense": 10}, "enemy": {"attack": 10, "defense": 10}, "target": 60},
		{"hero": {"attack": 16, "defense": 16}, "enemy": {"attack": 10, "defense": 10}, "target": 60},
		{"hero": {"attack": 4, "defense": 10}, "enemy": {"attack": 10, "defense": 10}, "target": 69},
		{"hero": {"attack": 10, "defense": 4}, "enemy": {"attack": 10, "defense": 10}, "target": 69},
		{"hero": {"attack": 4, "defense": 4}, "enemy": {"attack": 10, "defense": 10}, "target": 78},
		{"hero": {"attack": 1, "defense": 1}, "enemy": {"attack": 1000000, "defense": 1000000}, "target": 95},
		{"hero": {"attack": 1000000, "defense": 1000000}, "enemy": {"attack": 1, "defense": 1}, "target": 60}
	]
	for entry in cases:
		for good in [true, false]:
			var round_state := RhythmRound.new(10, 10, entry.enemy, [], entry.hero)
			var target := float(round_state.settings.required_accuracy)
			fix.assert_eq(roundi(target * 100.0), entry.target, "Signed deficits determine the visible whole-percent target, bounded at 60-95%")
			var hits_needed := ceili(round_state.note_times.size() * target)
			for index in range(hits_needed - (0 if good else 1)):
				round_state.press_at(round_state.note_times[index], round_state.note_actions[index])
			round_state.advance_to(100.0)
			fix.assert_eq(round_state.outcome().success, good, "Meeting the actual target wins; one fewer hit fails at every threshold")
			fix.assert_eq(round_state.outcome().required_accuracy, target, "Result reports the exact target used for victory")
	var previous := 0.60
	for gap in [0, 1, 2, 4, 8, 16, 1000]:
		var settings := RhythmRound.settings_for(10, 10, {"attack": 10 + gap, "defense": 10 + gap}, [], {"attack": 10, "defense": 10})
		fix.assert_true(settings.required_accuracy >= previous, "A larger disadvantage cannot lower the victory target")
		previous = settings.required_accuracy
	var restraint_gear := [
		{"type": 0, "rarity": 3, "rhythm_affixes": [{"id": "restraint", "value": 0.15}]},
		{"type": 1, "rarity": 3, "rhythm_affixes": [{"id": "restraint", "value": 0.15}]}
	]
	var spam := RhythmRound.new(1000000, 1, {}, restraint_gear)
	for index in range(spam.note_times.size()):
		spam.press_at(spam.note_times[index], spam.note_actions[index])
		if not spam.finished:
			spam.press_at(spam.note_times[index], spam.note_actions[index])
	fix.assert_false(spam.outcome().success, "Even maximum restraint cannot beat the minimum 60% target by double-tapping every note")
	var main = await fix.create_main()
	var gm = fix.root.get_node("GameManager")
	await fix.enter_regular_encounter(main, gm.get_total_player_power() + 3)
	main.monster_view.current_monster.attack = 20
	main.monster_view.current_monster.defense = 18
	main.monster_view.update_combat_evaluation()
	var forecast := RhythmRound.settings_for(gm.get_total_player_power(), int(main.monster_view.current_monster.power), main.monster_view.current_monster, main.monster_view._rhythm_equipment(), gm.get_combat_stats())
	var target_text := "%d%%" % roundi(float(forecast.required_accuracy) * 100.0)
	fix.assert_true(main.monster_view.status_hint_label.text.contains(target_text), "Pre-fight forecast shows the computed victory target")
	main.monster_view._start_rhythm()
	var rhythm = main.monster_view.rhythm_game
	fix.assert_eq(rhythm.round_state.settings.required_accuracy, forecast.required_accuracy, "Live round uses the forecast target")
	fix.assert_true(rhythm.stats.text.contains(target_text), "Live score text shows the round-specific target")
	gm.equipped_weapon.power += 100
	gm.equipped_armor.power += 100
	fix.assert_eq(rhythm.round_state.settings.required_accuracy, forecast.required_accuracy, "An active round's threshold stays frozen")
	await fix.teardown()

static func test_variations(fix: GameFixture) -> void:
	fix.assert_eq(RhythmRound.PATTERNS.size(), 14, "Eleven ordinary species and three bosses have their own rhythmic families")
	var species_patterns: Array[String] = []
	for id in EncounterFactory.MONSTER_TEMPLATES:
		var pattern_id := RhythmRound.pattern_id_for({"id": id})
		fix.assert_false(pattern_id in species_patterns, "Ordinary species no longer share a copied rhythm")
		species_patterns.append(pattern_id)
	for id in RhythmRound.PATTERNS:
		fix.assert_eq(RhythmRound.PHRASE_VARIANTS[id].size(), 2, "Every family has three musical phrases including its original")
		for depth in [0, 24]:
			var seen: Dictionary = {}
			var introductions: Dictionary = {}
			var reference: Array = []
			for seed_value in range(32):
				var monster := {"id": id, "q": depth, "encounter_id": "variation-run_f1_r%d_s0" % seed_value,
					"is_boss": str(id).begins_with("boss_") or id == "final_boss_malgor", "is_final": id == "final_boss_malgor"}
				var forecast := RhythmRound.settings_for(10, 10, monster)
				var round_state := RhythmRound.new(10, 10, monster)
				var repeated := RhythmRound.new(10, 10, JSON.parse_string(JSON.stringify(monster)))
				fix.assert_eq(round_state.note_times, repeated.note_times, "Retry/reload keeps the encounter's exact timings")
				fix.assert_eq(round_state.note_actions, repeated.note_actions, "Retry/reload keeps its exact attacks and blocks")
				fix.assert_eq(round_state.note_actions, forecast.note_actions, "Preview contains the actual balanced action plan")
				fix.assert_eq(round_state.settings, forecast, "Preview and live round resolve the same seeded phrases")
				fix.assert_true(round_state.settings.phrase_order.size() >= 2, "A fight changes phrase rather than looping one short pattern")
				for index in range(1, round_state.settings.phrase_order.size()):
					fix.assert_ne(round_state.settings.phrase_order[index], round_state.settings.phrase_order[index - 1], "Adjacent phrases do not repeat")
				for index in range(1, round_state.note_times.size()):
					var gap: float = round_state.note_times[index] - round_state.note_times[index - 1]
					fix.assert_true(gap > round_state.hit_window_for_note(index) + round_state.hit_window_for_note(index - 1), "Phrase transitions leave separated timing windows")
					fix.assert_true(absf(gap - float(forecast.note_gaps[index - 1]) * float(forecast.interval)) < 0.000001, "Planned gaps exactly drive the played timeline")
				for action in [RhythmRound.ATTACK, RhythmRound.GUARD]:
					fix.assert_true(float(round_state.note_actions.count(action)) / round_state.note_actions.size() < float(forecast.required_accuracy), "No varied sequence can be won by using only one button")
				var fixed_difficulty: Array = [forecast.bpm, forecast.required_accuracy, forecast.note_count, forecast.raw_damage_on_fail]
				if reference.is_empty():
					reference = fixed_difficulty
				fix.assert_eq(fixed_difficulty, reference, "Variation does not reroll tempo, victory target, note count or damage")
				seen[JSON.stringify([round_state.note_times, round_state.note_actions])] = true
				introductions[round_state.settings.phrase_order[0]] = true
				for index in range(round_state.note_times.size()):
					round_state.press_at(round_state.note_times[index], round_state.note_actions[index])
				fix.assert_true(round_state.outcome().success, "Every generated phrase combination is playable")
			fix.assert_eq(introductions.size(), 3, "Similar encounter IDs can select all three opening phrases")
			fix.assert_true(seen.size() >= 6, "New encounters offer multiple distinct full sequences for %s at depth %d (observed %d)" % [id, depth, seen.size()])
	var main = await fix.create_main()
	var gm = fix.root.get_node("GameManager")
	await fix.enter_regular_encounter(main, gm.get_total_player_power() + 3)
	var rng_before: String = gm.floor_routes.rng_state
	var choices_before := JSON.stringify(gm.floor_routes.current_choices)
	main.monster_view._start_rhythm()
	var times: Array = main.monster_view.rhythm_game.round_state.note_times.duplicate()
	var actions: Array = main.monster_view.rhythm_game.round_state.note_actions.duplicate()
	main.monster_view._cancel_rhythm()
	main.monster_view.setup_monster(main.encounter_ctrl.current_encounter.duplicate(true))
	main.monster_view._start_rhythm()
	fix.assert_eq(main.monster_view.rhythm_game.round_state.note_times, times, "Restarting the real encounter cannot fish for another rhythm")
	fix.assert_eq(main.monster_view.rhythm_game.round_state.note_actions, actions, "Real retry preserves the action sequence")
	fix.assert_eq(gm.floor_routes.rng_state, rng_before, "Phrase selection never consumes the dungeon RNG")
	fix.assert_eq(JSON.stringify(gm.floor_routes.current_choices), choices_before, "Rhythm generation does not mutate saved door offers")
	await fix.teardown()

static func test_retry(fix: GameFixture) -> void:
	for floor_number in [0, 2, 100]:
		var main = await fix.create_main()
		var gm = fix.root.get_node("GameManager")
		if floor_number != 100:
			gm.start_new_game(RunMode.Mode.ENDLESS)
		if floor_number == 0:
			await fix.enter_regular_encounter(main, gm.get_total_player_power() + 1)
		else:
			gm.current_floor = floor_number
			gm._create_floor_routes_for_current_floor()
			for _room in range(9):
				var choice: Dictionary = gm.floor_routes.current_choices[0]
				gm.floor_routes.select_door(int(choice.door_slot))
				if choice.kind != "trap":
					gm.floor_routes.set_encounter_status(str(choice.encounter_id), "defeated_waiting_loot")
				fix.assert_true(gm.floor_routes.commit_room_completion(str(choice.encounter_id)).success, "Prepare actual boss room")
				gm.current_room += 1
			gm.floor_routes.current_choices[0].data.power = gm.get_total_player_power() + 1
			var request: Dictionary = main.encounter_ctrl.request_door(1, gm.run_generation, gm.floor_routes.revision)
			fix.assert_true(request.success, "Boss door opens")
			main.encounter_ctrl.apply_door_transition(int(request.transition_token))
			main._show_encounter()
		var view = main.monster_view
		var enc_id: String = view.current_encounter_id
		var door_slot: int = int(main.encounter_ctrl.current_encounter.door_slot)
		var choices: Array = gm.floor_routes.current_choices.duplicate(true)
		for choice in choices:
			choice.status = "pending"
		var quotas: Dictionary = gm.floor_routes.remaining_counts.duplicate(true)
		var completed: Array = gm.floor_routes.completed_rooms.duplicate(true)
		var rng_state: String = gm.floor_routes.rng_state
		var room: int = gm.current_room
		var hp: int = gm.player_hp
		var gold: int = gm.player_gold
		var kills: int = gm.monsters_slain_total
		var stash: Array = gm.floor_stash.duplicate(true)
		view._start_rhythm()
		if floor_number == 0:
			# A partial attempt below this round's dynamic target must remain a defeat.
			var rhythm = view.rhythm_game
			var partial_hits := ceili(rhythm.round_state.note_times.size() * float(rhythm.round_state.settings.required_accuracy)) - 1
			for index in range(partial_hits):
				rhythm.started_usec = Time.get_ticks_usec() - int(rhythm.round_state.note_times[index] * 1000000)
				rhythm._press(rhythm.round_state.note_actions[index])
		view.rhythm_game.started_usec = Time.get_ticks_usec() - 100000000
		await fix.tree.process_frame
		await fix.tree.process_frame
		if floor_number == 0:
			fix.assert_true(view.rhythm_game.round_state.hits > 0 and view.rhythm_game.round_state.accuracy() < float(view.rhythm_game.round_state.settings.required_accuracy), "Partial success below the round-specific target is a defeat")
		var expected := CombatRules.calculate_damage(10, int(gm.equipped_armor.get("damage_reduction", 0)), hp)
		fix.assert_eq(gm.player_hp, expected.remaining_hp, "Failed attempt applies armor once")
		fix.assert_eq(main.encounter_ctrl.phase, EncounterController.RunPhase.CORRIDOR, "Failure returns to corridor")
		fix.assert_true(main.dungeon_view.visible and main.dungeon_view.door_center.is_active, "Doors are visible and usable again")
		fix.assert_eq(gm.current_room, room, "Room does not advance")
		fix.assert_eq(gm.floor_routes.current_depth, room, "Route depth does not advance")
		fix.assert_eq(JSON.stringify(gm.floor_routes.current_choices), JSON.stringify(choices), "The exact same enemies, powers, IDs and slots remain")
		fix.assert_eq(gm.floor_routes.rng_state, rng_state, "Failure does not roll new choices")
		fix.assert_eq(gm.floor_routes.remaining_counts, quotas, "Room quotas are unchanged")
		fix.assert_eq(gm.floor_routes.completed_rooms, completed, "Failure does not complete a room")
		fix.assert_eq(gm.floor_stash, stash, "No loot enters the stash")
		fix.assert_eq(gm.player_gold, gold, "No gold reward")
		fix.assert_eq(gm.monsters_slain_total, kills, "No defeated monster is counted")
		fix.assert_true(main.encounter_ctrl.pending_loot.is_empty() and gm.floor_routes.selected_encounter_id.is_empty(), "No pending reward or door selection")
		# Read the bytes without invoking the timed-mode rollback-on-launch policy.
		var envelope := SaveCodec.decode_envelope(FileAccess.get_file_as_string(gm.save_store.get_save_path()))
		fix.assert_false(envelope.has("error"), "Defeat snapshot is valid on disk")
		var saved: Dictionary = envelope.active_run
		fix.assert_eq(saved.hp, gm.player_hp, "HP loss is persisted")
		fix.assert_eq(saved.controller.phase, "CORRIDOR", "Return to corridor is persisted with HP loss")
		var decoded := FloorRoutes.from_snapshot(saved.floor_state)
		var persisted_choices: Array = JSON.parse_string(JSON.stringify(choices))
		fix.assert_true(decoded.success, "Retry state survives save decoding")
		fix.assert_eq(decoded.state.current_choices, persisted_choices, "Save retains the same pending doors")
		fix.assert_false(main.encounter_ctrl.resolve_rhythm_failure(enc_id, 10), "Duplicate failure callback is ignored")
		fix.assert_eq(gm.player_hp, expected.remaining_hp, "Duplicate callback cannot apply damage twice")
		if floor_number == 0:
			gm.resume_endless_run(saved)
			main.encounter_ctrl.restore(saved.controller)
			main._restore_screen()
			fix.assert_eq(gm.player_hp, expected.remaining_hp, "Resuming keeps the lost health")
			fix.assert_eq(gm.floor_routes.current_choices, persisted_choices, "Resuming returns to the same pending doors")
		var retry: Dictionary = main.encounter_ctrl.request_door(door_slot, gm.run_generation, gm.floor_routes.revision)
		fix.assert_true(retry.success, "The failed door can be selected again")
		fix.assert_eq(retry.encounter.encounter_id, enc_id, "Retry opens the same enemy")
		main.encounter_ctrl.apply_door_transition(int(retry.transition_token))
		main._show_encounter()
		view._start_rhythm()
		await finish_perfect(view, fix)
		await fix.tree.create_timer(0.5).timeout
		fix.assert_eq(main.encounter_ctrl.phase, EncounterController.RunPhase.LOOT, "Winning the retry unlocks loot")
		fix.assert_eq(gm.monsters_slain_total, kills + 1, "Only the successful attempt counts as victory")
		if floor_number == 0:
			main._on_loot_selected(main.encounter_ctrl.pending_loot[0])
			fix.assert_eq(gm.current_room, room + 1, "Only victory and taking loot advance the room")
		await fix.teardown()
	var main = await fix.create_main()
	var gm = fix.root.get_node("GameManager")
	await fix.enter_regular_encounter(main, gm.get_total_player_power() + 1)
	var hp: int = gm.player_hp
	var routes: Dictionary = gm.floor_routes.serialize()
	var real_store: SaveStore = gm.save_store
	gm.save_store = FailingStore.new("user://failed-rhythm-save")
	fix.assert_false(main.encounter_ctrl.resolve_rhythm_failure(main.encounter_ctrl.encounter_id, 10), "Failed persistence rejects the defeat command")
	fix.assert_eq(gm.player_hp, hp, "Save failure restores HP")
	fix.assert_eq(gm.floor_routes.serialize(), routes, "Save failure restores selected door and choices")
	fix.assert_eq(main.encounter_ctrl.phase, EncounterController.RunPhase.COMBAT, "Save failure keeps the encounter active")
	gm.save_store = real_store
	gm.persistence_error = ""
	await fix.teardown()

static func test_patterns(fix: GameFixture) -> void:
	var seen_timelines: Array[String] = []
	for id in RhythmRound.PATTERNS:
		var monster := {"id": id}
		var round_state := RhythmRound.new(10, 10, monster)
		fix.assert_eq(round_state.settings.pattern_id, id, "Enemy ID chooses its own rhythm")
		fix.assert_eq(round_state.note_times[0], 4.0 * float(round_state.settings.interval), "Each rhythm has four count-in beats")
		var timeline := JSON.stringify(round_state.note_times)
		fix.assert_false(seen_timelines.has(timeline), "Each enemy has a distinct timeline at the same power")
		seen_timelines.append(timeline)
		var easy := RhythmRound.settings_for(30, 10, monster)
		var hard := RhythmRound.settings_for(10, 30, monster)
		fix.assert_true(easy.bpm < hard.bpm and easy.hit_window > hard.hit_window, "Power scaling applies to every pattern")
		fix.assert_eq(easy.pattern_id, hard.pattern_id, "Power does not replace the enemy's rhythm")
		for powers in [[1000, 1], [10, 10], [1, 1000]]:
			var check := RhythmRound.new(powers[0], powers[1], monster)
			for i in range(1, check.note_times.size()):
				fix.assert_true(check.note_times[i] - check.note_times[i - 1] > 2.0 * float(check.settings.hit_window), "Adjacent notes have separate hit windows at every difficulty")
		for i in range(round_state.note_times.size()):
			fix.assert_eq(round_state.press_at(round_state.note_times[i], round_state.note_actions[i]), "perfect", "A pattern can be played perfectly")
		fix.assert_true(round_state.outcome().success, "Every complete pattern wins")
		var failed := RhythmRound.new(10, 15, monster)
		failed.advance_to(100)
		fix.assert_eq(failed.outcome().raw_damage, 50, "Rhythm choice preserves damage rules")
	var ghoul := RhythmRound.new(10, 10, {"id": "shadow_ghoul"})
	for i in range(3):
		ghoul.press_at(ghoul.note_times[i], ghoul.note_actions[i])
	var pause_time := (ghoul.note_times[2] + ghoul.note_times[3]) * 0.5
	ghoul.advance_to(pause_time)
	fix.assert_eq(ghoul.misses, 0, "Rest between bursts does not create phantom misses")
	fix.assert_eq(ghoul.press_at(pause_time), "miss", "Pressing during a rest is an extra press")
	fix.assert_eq(ghoul.stray_presses, 1, "Rest spam is penalized")
	fix.assert_eq(RhythmRound.pattern_id_for({"id": "unknown"}), "skeleton", "Unknown regular enemy has a safe fallback")
	fix.assert_eq(RhythmRound.pattern_id_for({"id": "unknown", "is_boss": true}), "boss_lich", "Unknown boss uses a boss rhythm")
	fix.assert_eq(RhythmRound.pattern_id_for({"id": "boss_lich", "is_final": true}), "final_boss_malgor", "Final flag takes priority")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for floor_num in [1, 2, 100]:
		var boss := EncounterFactory.create_encounter("boss", {"floor_number": floor_num, "room_number": 10, "mode": "timed"}, rng)
		fix.assert_eq(RhythmRound.pattern_id_for(boss), boss.id, "Generated floor and final bosses resolve to their own pattern")
	await fix.teardown()

static func test_pattern_input(fix: GameFixture) -> void:
	for id in RhythmRound.PATTERNS:
		var main = await fix.create_main()
		var gm = fix.root.get_node("GameManager")
		await fix.enter_regular_encounter(main, gm.get_total_player_power() + 3)
		var monster: Dictionary = main.encounter_ctrl.current_encounter
		monster.id = id
		monster.is_boss = str(id).begins_with("boss_") or id == "final_boss_malgor"
		monster.is_final = id == "final_boss_malgor"
		main.monster_view.setup_monster(monster)
		main.monster_view._on_fight_penalty_pressed()
		var rhythm = main.monster_view.rhythm_game
		fix.assert_eq(rhythm.round_state.settings.pattern_id, id, "Monster view passes enemy identity into the rhythm game")
		fix.assert_true(rhythm.controls_hint.is_visible_in_tree() and rhythm.timing_hint.is_visible_in_tree(), "Active combat instructions remain visible on the rhythm screen")
		await finish_perfect(main.monster_view, fix)
		fix.assert_eq(rhythm.round_state.hits, rhythm.round_state.note_times.size(), "All single and burst notes accepted through real input")
		await fix.tree.create_timer(0.5).timeout
		fix.assert_eq(main.encounter_ctrl.phase, EncounterController.RunPhase.LOOT, "Each enemy rhythm grants loot exactly once")
		await fix.teardown()

static func test_rules(fix: GameFixture) -> void:
	var easy := RhythmRound.settings_for(30, 10)
	var equal := RhythmRound.settings_for(10, 10)
	var hard := RhythmRound.settings_for(10, 30)
	fix.assert_true(easy.bpm < equal.bpm and equal.bpm < hard.bpm, "Tempo follows signed power gap")
	fix.assert_true(easy.note_count < equal.note_count and equal.note_count < hard.note_count, "Stronger enemies require more hits")
	fix.assert_true(easy.hit_window > equal.hit_window and equal.hit_window > hard.hit_window, "Timing gets tighter")
	var extreme := RhythmRound.settings_for(1, 100000)
	fix.assert_true(extreme.bpm <= 176 and extreme.hit_window >= 0.06 and extreme.note_count <= 26, "Extreme gaps stay playable")
	var perfect := RhythmRound.new(10, 15)
	for i in range(perfect.note_times.size()):
		fix.assert_eq(perfect.press_at(perfect.note_times[i], perfect.note_actions[i]), "perfect", "On-time note")
	fix.assert_true(perfect.outcome().success, "All hits win even against stronger enemies")
	fix.assert_eq(perfect.outcome().raw_damage, 0, "Success avoids damage")
	var missed := RhythmRound.new(10, 15)
	missed.advance_to(100)
	fix.assert_eq(missed.misses, missed.note_times.size(), "Missed notes expire")
	fix.assert_eq(missed.outcome().raw_damage, 50, "Failed round keeps power-gap penalty")
	var spam := RhythmRound.new(10, 15)
	fix.assert_eq(spam.press_at(0.1), "wait", "Count-in allows practice")
	for i in range(spam.note_times.size()):
		spam.press_at(spam.note_times[i], spam.note_actions[i])
		if not spam.finished:
			spam.press_at(spam.note_times[i], spam.note_actions[i])
	fix.assert_false(spam.outcome().success, "Repeated extra presses cannot brute-force a win")
	var boundary := RhythmRound.new(10, 10)
	fix.assert_eq(boundary.press_at(boundary.note_times[0] + float(boundary.settings.hit_window) * 0.99), "hit", "Late hit within window counts")
	boundary.advance_to(boundary.note_times[1] + float(boundary.settings.hit_window) + 0.001)
	fix.assert_eq(boundary.misses, 1, "Just beyond window is a miss")
	for good in [true, false]:
		var threshold := RhythmRound.new(10, 10)
		var hit_count := ceili(float(threshold.note_times.size()) * float(threshold.settings.required_accuracy)) - (0 if good else 1)
		for i in range(hit_count):
			threshold.press_at(threshold.note_times[i], threshold.note_actions[i])
		threshold.advance_to(100)
		fix.assert_eq(threshold.outcome().success, good, "The equal-stat 60% threshold is enforced")
	await fix.teardown()

static func finish_perfect(view: Node, fix: GameFixture) -> void:
	# Drive the real input path against the monotonic clock, without waiting a full song.
	var times: Array = view.rhythm_game.round_state.note_times.duplicate()
	for i in range(times.size()):
		view.rhythm_game.started_usec = Time.get_ticks_usec() - int(float(times[i]) * 1000000.0)
		if i % 3 == 0:
			await fix.simulate_key(KEY_SHIFT if view.rhythm_game.round_state.note_actions[i] == RhythmRound.GUARD else KEY_SPACE)
		elif i % 3 == 1:
			await fix.simulate_click(view.rhythm_game.guard_button if view.rhythm_game.round_state.note_actions[i] == RhythmRound.GUARD else view.rhythm_game.hit_button)
		else:
			var press := InputEventJoypadButton.new()
			press.button_index = JOY_BUTTON_B if view.rhythm_game.round_state.note_actions[i] == RhythmRound.GUARD else JOY_BUTTON_A
			press.pressed = true
			fix.root.push_input(press, true)
			press = InputEventJoypadButton.new()
			press.button_index = JOY_BUTTON_B if view.rhythm_game.round_state.note_actions[i] == RhythmRound.GUARD else JOY_BUTTON_A
			press.pressed = false
			fix.root.push_input(press, true)
			await fix.tree.process_frame

static func test_combat(fix: GameFixture) -> void:
	var main = await fix.create_main()
	var gm = fix.root.get_node("GameManager")
	await fix.enter_regular_encounter(main, gm.get_total_player_power() + 3)
	var view = main.monster_view
	view.current_monster.is_boss = true
	view.current_monster.id = "boss_lich"
	main.encounter_ctrl.current_encounter.is_boss = true
	var hp_before: int = gm.player_hp
	var kills_before: int = gm.monsters_slain_total
	var gold_before: int = gm.player_gold
	await fix.simulate_click(view.fight_penalty_button)
	fix.assert_true(view.rhythm_game.running, "Fight starts rhythm instead of immediate damage")
	fix.assert_false(main.encounter_ctrl.can_interact_with_cards(), "Cards locked during round")
	fix.assert_false(gm.unequip_slot(CardDatabase.CardType.ARMOR), "Armor cannot change mid-round")
	fix.assert_eq(gm.player_hp, hp_before, "No damage on start")
	view._on_fight_penalty_pressed()
	await finish_perfect(view, fix)
	fix.assert_true(view.rhythm_game.round_state.outcome().success, "Keyboard, mouse and gamepad all hit notes")
	await fix.tree.create_timer(0.5).timeout
	fix.assert_eq(gm.player_hp, hp_before, "Perfect boss fight costs no HP")
	fix.assert_eq(gm.monsters_slain_total, kills_before + 1, "Exactly one boss defeated")
	fix.assert_true(gm.player_gold > gold_before, "Boss reward granted")
	fix.assert_eq(main.encounter_ctrl.phase, EncounterController.RunPhase.LOOT, "Boss enters loot phase")
	fix.assert_false(main.encounter_ctrl.combat_input_locked, "Input unlocked after resolution")
	await fix.teardown()

	main = await fix.create_main()
	await fix.enter_regular_encounter(main, gm.get_total_player_power() + 2)
	view = main.monster_view
	hp_before = gm.player_hp
	var expected: Dictionary = CombatRules.calculate_damage(20, int(gm.equipped_armor.get("damage_reduction", 0)), hp_before)
	view._on_fight_penalty_pressed()
	view.rhythm_game.started_usec = Time.get_ticks_usec() - 100000000
	await fix.tree.process_frame
	await fix.tree.create_timer(0.5).timeout
	fix.assert_eq(gm.player_hp, expected.remaining_hp, "Failed rhythm applies armor once")
	fix.assert_eq(main.encounter_ctrl.phase, EncounterController.RunPhase.CORRIDOR, "Surviving failed round returns to the same doors")
	await fix.teardown()

	main = await fix.create_main()
	await fix.enter_regular_encounter(main, gm.get_total_player_power() + 20)
	view = main.monster_view
	gm.player_hp = 1
	kills_before = gm.monsters_slain_total
	view._on_fight_penalty_pressed()
	view.rhythm_game.started_usec = Time.get_ticks_usec() - 100000000
	await fix.tree.process_frame
	await fix.tree.create_timer(0.5).timeout
	fix.assert_true(gm.is_game_over, "Lethal failure ends run")
	fix.assert_eq(gm.monsters_slain_total, kills_before, "Death does not grant a kill")
	fix.assert_false(view.rhythm_game.running, "Rhythm stops on game over")
	await fix.teardown()

	main = await fix.create_main()
	await fix.enter_regular_encounter(main)
	view = main.monster_view
	view._on_victory_pressed()
	view.visible = false
	fix.assert_false(view.rhythm_game.running, "Hidden screen cancels rhythm")
	fix.assert_false(main.encounter_ctrl.combat_input_locked, "Cancellation unlocks cards")
	view.visible = true
	view.setup_monster(main.encounter_ctrl.current_encounter)
	view._on_victory_pressed()
	gm.run_generation += 1
	await fix.tree.process_frame
	fix.assert_false(view.rhythm_game.running, "Stale run cancels rhythm")
	await fix.teardown()
