class_name TestRhythmEquipment
extends RefCounted

static func register_tests(registry: Dictionary) -> void:
	registry["T-RHYTHM-AFFIX-GENERATION"] = {"fn": Callable(TestRhythmEquipment, "test_generation"), "expected_failure": false, "desc": "Rarity and slot pools, property counts, deterministic rolls, and consumable exclusion"}
	registry["T-RHYTHM-AFFIX-EFFECTS"] = {"fn": Callable(TestRhythmEquipment, "test_effects"), "expected_failure": false, "desc": "Six small equipment effects, capped stacking, dynamic windows, and anti-spam"}
	registry["T-RHYTHM-AFFIX-PERSISTENCE"] = {"fn": Callable(TestRhythmEquipment, "test_persistence"), "expected_failure": false, "desc": "Equipment swaps, upgrades, save/resume, campaign carry, descriptions, and actual combat settings"}

static func item(type: int, rarity: int, ids: Array) -> Dictionary:
	var affixes: Array[Dictionary] = []
	for id in ids:
		affixes.append({"id": id, "value": float(RhythmEquipment.PROPERTIES[id].values[rarity])})
	return {"id": "test_equipment", "type": type, "rarity": rarity, "rhythm_affixes": affixes}

static func test_generation(fix: GameFixture) -> void:
	var seen: Array[String] = []
	for rarity in range(4):
		for type in [0, 1, 4]:
			for seed_value in range(20):
				var rng := RandomNumberGenerator.new()
				rng.seed = seed_value
				var card := {"type": type, "rarity": rarity}
				RhythmEquipment.roll_for(card, rng)
				var affixes := RhythmEquipment.affixes_for(card)
				fix.assert_eq(affixes.size(), 1 if rarity < 2 else 2, "Rarity controls property count")
				var ids: Array[String] = []
				for affix in affixes:
					var rule: Dictionary = RhythmEquipment.PROPERTIES[affix.id]
					fix.assert_false(affix.id in ids, "No duplicate property on an item")
					fix.assert_true(rarity >= int(rule.min_rarity) and type in rule.slots, "Only unlocked and slot-compatible properties roll")
					fix.assert_eq(affix.value, float(rule.values[rarity]), "Magnitude belongs to item rarity")
					ids.append(affix.id)
					if not affix.id in seen:
						seen.append(affix.id)
				var original := card.duplicate(true)
				RhythmEquipment.roll_for(card, rng)
				fix.assert_eq(card, original, "Existing properties never reroll")
				var second := {"type": type, "rarity": rarity}
				rng.seed = seed_value
				RhythmEquipment.roll_for(second, rng)
				fix.assert_eq(second, original, "Seeded generation is repeatable")
	fix.assert_eq(seen.size(), RhythmEquipment.PROPERTIES.size(), "Every property is reachable in its rarity/slot pool")
	var cdb = fix.root.get_node("CardDatabase")
	for id in ["rusty_sword", "iron_blade", "radiant_broadsword", "leather_armor", "royal_plate", "lucky_dice_amulet", "golden_ring_reroll"]:
		var card: Dictionary = cdb.get_card_for_floor(20, id)
		fix.assert_eq(RhythmEquipment.affixes_for(card).size(), RhythmEquipment.property_count(int(card.rarity)), "New scaled equipment receives properties")
	for id in ["minor_health_potion", "scroll_of_might"]:
		fix.assert_false(cdb.get_card_data(id).has("rhythm_affixes"), "Consumables receive no equipment properties")
	fix.assert_true(RhythmEquipment.affixes_for({"type": 0, "rarity": 0}).is_empty(), "Legacy gear is valid without properties")
	fix.assert_true(RhythmEquipment.affixes_for({"type": 0, "rhythm_affixes": "invalid"}).is_empty(), "Malformed optional property list is ignored")
	await fix.teardown()

static func test_effects(fix: GameFixture) -> void:
	var plain := RhythmRound.new(10, 10)
	var precision := RhythmRound.new(10, 10, {}, [item(0, 2, ["precision"])])
	fix.assert_true(precision.settings.hit_window > plain.settings.hit_window, "Precision expands timing tolerance")
	var late_time := plain.note_times[0] + float(plain.settings.hit_window) * 1.02
	fix.assert_eq(precision.press_at(late_time), "hit", "Small formerly late press is accepted")
	fix.assert_ne(plain.press_at(late_time), "hit", "Same press misses without the property")
	var tempo := RhythmRound.new(10, 10, {}, [item(4, 2, ["tempo"])])
	fix.assert_true(tempo.settings.bpm < plain.settings.bpm and tempo.settings.bpm >= plain.settings.bpm * 0.97, "Tempo effect is small")
	var foresight := RhythmRound.new(10, 10, {}, [item(1, 2, ["foresight"])])
	fix.assert_true(foresight.settings.preview_multiplier > 1.0, "Foresight increases preview travel time")
	fix.assert_eq(foresight.note_times, plain.note_times, "Preview does not change attack timings")
	var opening := RhythmRound.new(10, 10, {}, [item(1, 2, ["opening"])])
	fix.assert_true(opening.hit_window_for_note(2) > opening.hit_window_for_note(3), "Opening applies only to the first three notes")
	var recovery := RhythmRound.new(10, 10, {}, [item(1, 2, ["recovery"])])
	recovery.advance_to(recovery.note_times[0] + float(recovery.settings.hit_window) + 0.001)
	fix.assert_true(recovery.hit_window_for_note(1) > recovery.hit_window_for_note(2), "Miss helps only the following note")
	fix.assert_eq(recovery.press_at(recovery.note_times[1] + float(recovery.settings.hit_window) * 1.02), "hit", "Recovery accepts a slightly late next note")
	fix.assert_eq(recovery.hit_window_for_note(2), float(recovery.settings.hit_window), "Recovery does not spread to later hits")
	var restraint := RhythmRound.new(10, 10, {}, [item(0, 2, ["restraint"])])
	var control := RhythmRound.new(10, 10)
	for round_state in [restraint, control]:
		for i in range(round_state.note_times.size()):
			round_state.press_at(round_state.note_times[i], round_state.note_actions[i])
			if not round_state.finished:
				round_state.press_at(round_state.note_times[i], round_state.note_actions[i])
	fix.assert_true(restraint.accuracy() > control.accuracy(), "Restraint slightly reduces extra-press penalties")
	fix.assert_false(restraint.outcome().success, "Reduced penalty still cannot brute-force a win")
	var gear := [item(0, 3, ["precision", "tempo"]), item(1, 3, ["opening", "restraint"]), item(4, 3, ["precision", "recovery"])]
	var bonuses := RhythmEquipment.bonuses_for(gear)
	fix.assert_eq(bonuses.precision, 0.06, "Identical properties across slots obey the global cap")
	for id in RhythmRound.PATTERNS:
		for powers in [[1, 1000], [10, 10], [1000, 1]]:
			var round_state := RhythmRound.new(powers[0], powers[1], {"id": id}, gear)
			round_state.advance_to(round_state.note_times[0] + round_state.hit_window_for_note(0) + 0.001)
			for i in range(1, round_state.note_times.size()):
				fix.assert_true(round_state.hit_window_for_note(i) <= float(round_state.settings.base_hit_window) * 1.100001, "Even combined conditional bonuses stay within 10%")
				fix.assert_true(round_state.note_times[i] - round_state.note_times[i - 1] > round_state.hit_window_for_note(i) + round_state.hit_window_for_note(i - 1), "Bonus windows never overlap burst notes")
			round_state.advance_to(100)
			fix.assert_false(round_state.outcome().success, "Equipment cannot win without hitting notes")
	await fix.teardown()

static func test_persistence(fix: GameFixture) -> void:
	var main = await fix.create_main()
	var gm = fix.root.get_node("GameManager")
	var cdb = fix.root.get_node("CardDatabase")
	var sword: Dictionary = cdb.get_card_data("radiant_broadsword")
	sword.rhythm_affixes = item(0, 2, ["precision", "tempo"]).rhythm_affixes
	var expected: Array = sword.rhythm_affixes.duplicate(true)
	gm.add_card_to_hand(sword)
	fix.assert_true(gm.equip_card_to_slot(gm.hand_cards.back(), 0), "Equip item with properties using the live inventory revision")
	fix.assert_true(gm.upgrade_equipped_weapon(), "Upgrade item with properties")
	fix.assert_eq(gm.equipped_weapon.rhythm_affixes, expected, "Upgrading does not reroll or scale rhythm properties")
	var instance_id: String = gm.equipped_weapon.instance_id
	fix.assert_true(gm.unequip_slot(0), "Unequip item with properties")
	var returned: Dictionary = {}
	for card in gm.hand_cards:
		if str(card.get("instance_id", "")) == instance_id:
			returned = card
	fix.assert_eq(returned.get("rhythm_affixes", []), expected, "Returning to inventory retains properties")
	fix.assert_true(gm.equip_card_to_slot(returned, 0), "Re-equip same item")
	var description := CardPresenter.get_description(gm.equipped_weapon)
	fix.assert_true(description.contains(TranslationServer.translate("Steady Grip")) and description.contains("3%") and description.contains("1.5%"), "Tooltip shows exact stored effects after an upgrade")
	fix.assert_eq(description.count(TranslationServer.translate("Steady Grip")), 1, "Properties are not duplicated in descriptions")
	var compact := CardPresenter.get_compact_description(gm.equipped_weapon)
	fix.assert_true(compact.contains(TranslationServer.translate("Steady Grip")) and compact.contains(TranslationServer.translate("Steady Pulse")), "Both properties appear on the compact card")
	fix.assert_eq(compact.count("\n"), 1, "Two property lines fit the fixed-height hand card")
	var profile: Dictionary = gm.player_profile.duplicate(true)
	profile.campaign_equipment = CampaignEquipmentRules.record_victory_equipment(gm.equipped_weapon, gm.equipped_armor, gm.equipped_amulet)
	var active: Dictionary = gm.build_active_run()
	active.mode = "ENDLESS"
	var decoded := SaveCodec.decode_envelope(JSON.stringify(SaveCodec.encode_envelope(profile, active)))
	fix.assert_false(decoded.has("error"), "Save codec accepts equipment properties")
	if decoded.has("error"):
		await fix.teardown()
		return
	fix.assert_eq(decoded.profile.campaign_equipment.weapon.rhythm_affixes, expected, "Campaign equipment retains properties")
	gm.resume_endless_run(decoded.active_run)
	fix.assert_eq(gm.equipped_weapon.rhythm_affixes, expected, "Resume retains the exact properties")
	main.encounter_ctrl.restore({"phase": "CORRIDOR"})
	await fix.enter_regular_encounter(main, gm.get_total_player_power() + 3)
	var gear: Array = [gm.equipped_weapon, gm.equipped_armor, gm.equipped_amulet]
	var forecast := RhythmRound.settings_for(gm.get_total_player_power(), int(main.monster_view.current_monster.power), main.monster_view.current_monster, gear, gm.get_combat_stats())
	main.monster_view._on_fight_penalty_pressed()
	var rhythm = main.monster_view.rhythm_game
	fix.assert_eq(rhythm.round_state.settings.bpm, forecast.bpm, "Actual rhythm uses equipped tempo effects")
	fix.assert_eq(rhythm.round_state.settings.hit_window, forecast.hit_window, "Actual timing matches the equipment forecast")
	var frozen: Dictionary = rhythm.round_state.equipment_bonuses.duplicate(true)
	gm.equipped_weapon.rhythm_affixes[0].value = 0.0
	fix.assert_eq(rhythm.round_state.equipment_bonuses, frozen, "Active round freezes its equipment effects")
	await fix.teardown()
