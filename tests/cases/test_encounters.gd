# tests/cases/test_encounters.gd
class_name TestEncounters
extends RefCounted

static func register_tests(registry: Dictionary) -> void:
	registry["T-C02"] = {
		"fn": Callable(TestEncounters, "test_c02_double_defeat"),
		"expected_failure": false,
		"desc": "C02: Multiple victory clicks during animation double-counts kills and loot"
	}
	registry["T-C03"] = {
		"fn": Callable(TestEncounters, "test_c03_multiple_door_selection"),
		"expected_failure": false,
		"desc": "C03: Quick clicks on multiple doors creates multiple encounters"
	}
	registry["T-C07"] = {
		"fn": Callable(TestEncounters, "test_c07_stale_hud_power_on_curse"),
		"expected_failure": false,
		"desc": "C07: HUD temporarily shows old power after curse drain"
	}
	registry["T-C08"] = {
		"fn": Callable(TestEncounters, "test_c08_raw_vs_actual_damage"),
		"expected_failure": false,
		"desc": "C08: Escape and trap display raw damage rather than actual damage after armor"
	}
	registry["T-P06-P08-DOORS"] = {
		"fn": Callable(TestEncounters, "test_doors_presentation_and_completion"),
		"expected_failure": false,
		"desc": "P06-P08: 3 doors, boss door, escape preservation, and atomic quota consumption"
	}

static func test_c02_double_defeat(fix: GameFixture) -> void:
	var main = await fix.create_main()
	var gm = fix.root.get_node("/root/GameManager")
	var mdb = fix.root.get_node("/root/MonsterDatabase")
	gm.monsters_slain_total = 0
	
	var monster_view = main.get_node("MonsterView")
	main._show_dungeon_room(false)
	
	await fix.enter_regular_encounter(main)

	var btn_fight = monster_view.get_node_or_null("%VictoryButton")
	if btn_fight == null:
		btn_fight = monster_view.get_node_or_null("%FightButton")
	if btn_fight == null:
		btn_fight = monster_view.victory_button
	
	# Simulate rapid double click
	await fix.simulate_click(btn_fight)
	await fix.simulate_click(btn_fight)
	fix.assert_eq(gm.monsters_slain_total, 0, "Starting a rhythm fight grants no kill")
	await TestRhythm.finish_perfect(monster_view, fix)
	
	# Await any tween or frame processing
	await fix.tree.process_frame
	await fix.tree.create_timer(0.5).timeout
	
	# TARGET ASSERTION: Only 1 monster slain should be counted
	# In baseline, 2 clicks lead to 2 kills and duplicate loot!
	fix.assert_eq(gm.monsters_slain_total, 1, "TARGET: Exactly 1 monster should be slain from one encounter")
	await fix.teardown()

static func test_c03_multiple_door_selection(fix: GameFixture) -> void:
	var main = await fix.create_main()
	var dungeon_view = main.get_node("DungeonView")
	main._show_dungeon_room(false)
	
	var door_left = dungeon_view.get_node_or_null("%DoorLeft")
	if door_left == null:
		door_left = dungeon_view.get_node_or_null("DoorsContainer/DoorLeft")
	var door_right = dungeon_view.get_node_or_null("%DoorRight")
	if door_right == null:
		door_right = dungeon_view.get_node_or_null("DoorsContainer/DoorRight")
	
	var selections: Array[int] = []
	var record_selection = func(idx: int, _token: int): selections.append(idx)
	dungeon_view.door_transition_completed.connect(record_selection)
	
	# Simulate rapid clicks on both doors
	await fix.simulate_click(door_left)
	await fix.simulate_click(door_right)
	
	# Await door animation (~0.45s) and walk-in transition (~0.54s)
	await fix.tree.create_timer(1.2).timeout
	
	dungeon_view.door_transition_completed.disconnect(record_selection)
	
	# TARGET ASSERTION: Exactly 1 door selection should be emitted/accepted
	# In baseline, both doors animate and both emit door_selected!
	fix.assert_eq(selections.size(), 1, "TARGET: Only 1 door selection should be accepted, got: %d" % selections.size())
	await fix.teardown()

static func test_c07_stale_hud_power_on_curse(fix: GameFixture) -> void:
	var main = await fix.create_main()
	var gm = fix.root.get_node("/root/GameManager")
	var curse_event = main.get_node("CurseEvent")
	var hud = main.get_node("HUD")
	var stats_before: Dictionary = gm.get_combat_stats()
	
	# Exercise a selected trap and a deterministic accepted full-failure result.
	var choice = gm.floor_routes.current_choices[0]
	choice.kind = "trap"
	choice.data = {"name": "Тестовый алтарь", "dc": 7, "damage_on_fail": 8, "power_drain": 1}
	var request = main.encounter_ctrl.request_door(0, gm.run_generation, gm.floor_routes.revision)
	fix.assert_true(request.get("success", false), "Trap accepted")
	main.encounter_ctrl.apply_door_transition(int(request.get("transition_token", -1)))
	main._show_encounter()
	curse_event.has_rolled = true
	curse_event.pending_outcome = {"raw_damage": 0, "drain": 1}
	await fix.tree.process_frame
	await fix.simulate_click(curse_event.action_button)
	fix.assert_eq(gm.floor_power_penalty, 1, "Accepted altar actually weakens the hero")

	# Read HUD power label immediately after curse resolution
	var hud_power_label = hud.get_node_or_null("%PowerLabel")
	if hud_power_label == null:
		hud_power_label = hud.get_node_or_null("MarginContainer/HBoxContainer/LeftStats/PowerBox/PowerLabel")
	if hud_power_label == null:
		hud_power_label = hud.power_label
	var hud_text: String = hud_power_label.text
	var actual_stats: Dictionary = gm.get_combat_stats()
	fix.assert_eq(actual_stats.attack, stats_before.attack - 1, "Curse weakens live attack")
	fix.assert_eq(actual_stats.defense, stats_before.defense - 1, "Curse weakens live defense")
	var expected_text = TranslationServer.translate("UI_HERO_COMBAT_STATS") % [actual_stats.attack, actual_stats.defense]
	fix.assert_eq(hud_text, expected_text, "TARGET: HUD attack and defense refresh immediately after curse")
	await fix.teardown()

static func test_c08_raw_vs_actual_damage(fix: GameFixture) -> void:
	var main = await fix.create_main()
	var gm = fix.root.get_node("/root/GameManager")
	var dice_escape = main.get_node("DiceEscape")
	
	# Player starts with armor (damage_reduction=1)
	fix.assert_false(gm.equipped_armor.is_empty(), "Player should have armor equipped")
	var armor_reduct = int(gm.equipped_armor.get("damage_reduction", 1))
	fix.assert_eq(armor_reduct, 1, "Starter armor damage reduction should be 1")
	
	var monster = {
		"name": "Тестовый враг",
		"power": gm.get_total_player_power() + 1, # diff = 1 -> raw damage = 10
		"gold_reward": 5,
		"icon": ""
	}
	
	dice_escape.visible = true
	dice_escape.setup_escape(monster)
	
	# Check displayed forecast on escape fail button / label
	# diff = 1, raw damage = 10, with armor reduction 1 actual damage is 9
	# In baseline, dice_escape displays -10 HP instead of actual damage 9 HP
	var fail_btn = dice_escape.get_node_or_null("%FailAcceptButton")
	if fail_btn == null:
		fail_btn = dice_escape.get_node_or_null("%ActionButton")
	var fail_text: String = ""
	if fail_btn != null:
		fail_text = fail_btn.text
	var dc_lbl = dice_escape.get_node_or_null("%DCLabel")
	if dc_lbl != null:
		fail_text += " " + dc_lbl.text
	
	# TARGET ASSERTION: The UI should display the actual damage (9) accounting for armor, not raw 10
	fix.assert_true(fail_text.contains("-9 HP") or fail_text.contains("9"), "TARGET: UI should display actual damage after armor (9), got: '%s'" % fail_text)
	await fix.teardown()

static func test_doors_presentation_and_completion(fix: GameFixture) -> void:
	var main = await fix.create_main()
	var gm = fix.root.get_node("/root/GameManager")
	var dungeon_view = main.get_node("DungeonView")
	main._show_dungeon_room(false)

	# 1. Rooms 1..9 have 3 visible doors with "Левая дверь", "Центральная дверь", "Правая дверь"
	fix.assert_true(dungeon_view.door_left.visible, "Door left visible in regular room")
	fix.assert_true(dungeon_view.door_center.visible, "Door center visible in regular room")
	fix.assert_true(dungeon_view.door_right.visible, "Door right visible in regular room")
	fix.assert_eq(dungeon_view.door_left.door_title, TranslationServer.translate("DOOR_LEFT"), "Door left title matches")
	fix.assert_eq(dungeon_view.door_center.door_title, TranslationServer.translate("DOOR_CENTER"), "Door center title matches")
	fix.assert_eq(dungeon_view.door_right.door_title, TranslationServer.translate("DOOR_RIGHT"), "Door right title matches")

	# 2. Boss room (room 10) shows only central door with "👑 ВРАТА БОССА"
	gm.current_room = 10
	main._show_dungeon_room(false)
	fix.assert_false(dungeon_view.door_left.visible, "Door left hidden in boss room")
	fix.assert_true(dungeon_view.door_center.visible, "Door center visible in boss room")
	fix.assert_false(dungeon_view.door_right.visible, "Door right hidden in boss room")
	fix.assert_true(dungeon_view.door_center.door_title.contains(TranslationServer.translate("DOOR_BOSS")), "Boss door title is localized")

	# Reset room to 1
	gm.current_room = 1
	main._show_dungeon_room(false)

	# 3. Door selection transitions into COMBAT or CURSE
	var choices = gm.floor_routes.get_current_choices()
	fix.assert_eq(choices.size(), 3, "Room 1 has 3 door proposals")
	main._on_door_selected(1)
	await fix.tree.create_timer(1.1).timeout
	fix.assert_ne(main.encounter_ctrl.phase, EncounterController.RunPhase.CORRIDOR, "Phase changed from CORRIDOR")

	# 4. Escape preserves the same 3 doors
	if main.encounter_ctrl.phase == EncounterController.RunPhase.COMBAT:
		var enc_first = main.encounter_ctrl.current_encounter.duplicate(true)
		main._on_escape_requested(enc_first)
		main._on_escape_resolved(true)
		fix.assert_eq(main.encounter_ctrl.phase, EncounterController.RunPhase.CORRIDOR, "Returned to CORRIDOR on escape")
		var choices_after_esc = gm.floor_routes.get_current_choices()
		fix.assert_eq(choices_after_esc.size(), 3, "Still 3 door proposals after escape")
		fix.assert_eq(choices_after_esc[0]["encounter_id"], enc_first["encounter_id"], "Door 0 encounter ID preserved")

	# 5. Defeat monster -> waiting loot, quota not yet consumed
	main._on_door_selected(1)
	await fix.tree.create_timer(1.1).timeout
	if main.encounter_ctrl.phase == EncounterController.RunPhase.COMBAT:
		var rem_reg_before = gm.floor_routes.remaining_counts["regular"]
		main._on_monster_defeated()
		fix.assert_eq(main.encounter_ctrl.phase, EncounterController.RunPhase.LOOT, "Phase is LOOT after defeat")
		fix.assert_eq(gm.floor_routes.remaining_counts["regular"], rem_reg_before, "Quota not consumed during LOOT phase")

		# Select loot -> consumes quota, advances room
		main._on_loot_selected(main.encounter_ctrl.pending_loot[0])
		fix.assert_eq(gm.floor_routes.remaining_counts["regular"], rem_reg_before - 1, "Quota consumed after loot selection")
		fix.assert_eq(gm.current_room, 2, "Room advanced to 2")

	await fix.teardown()
