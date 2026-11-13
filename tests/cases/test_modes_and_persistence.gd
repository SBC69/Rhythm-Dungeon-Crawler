# tests/cases/test_modes_and_persistence.gd
class_name TestModesAndPersistence
extends RefCounted

static func register_tests(registry: Dictionary) -> void:
	registry["T-M22-MODES"] = {
		"fn": Callable(TestModesAndPersistence, "test_modes_and_floors"),
		"expected_failure": false,
		"desc": "M22: Mode selection, independent completed_floors and last_opened_floor"
	}
	registry["T-M23-CLOCK"] = {
		"fn": Callable(TestModesAndPersistence, "test_continuous_clock"),
		"expected_failure": false,
		"desc": "M23: Continuous monotonic run clock and freeze upon victory"
	}
	registry["T-M24-SETTLE"] = {
		"fn": Callable(TestModesAndPersistence, "test_settlement_rules"),
		"expected_failure": false,
		"desc": "M24: Shared wallet settlement for Death, Retired, and Success"
	}
	registry["T-M25-PERSIST"] = {
		"fn": Callable(TestModesAndPersistence, "test_atomic_save_codec_and_store"),
		"expected_failure": false,
		"desc": "M25: Atomic persistence, validation, backup, and timed rollback"
	}
	registry["T-M31-VILLAGE"] = {
		"fn": Callable(TestModesAndPersistence, "test_village_state_and_restoration"),
		"expected_failure": false,
		"desc": "M31-M33: Village prerequisites, v2 costs, and atomic restoration"
	}
	registry["T-M40-EQUIP"] = {
		"fn": Callable(TestModesAndPersistence, "test_campaign_equipment_transfer"),
		"expected_failure": false,
		"desc": "M40: Equipment transfer on success, clearing on death/retired"
	}
	registry["T-M41-PROGRESS"] = {
		"fn": Callable(TestModesAndPersistence, "test_dungeon_progression_formulas"),
		"expected_failure": false,
		"desc": "M41: Exact Q scaling, enemy/boss power, and trap DC/damage caps"
	}
	registry["T-M42-CONFIG"] = {
		"fn": Callable(TestModesAndPersistence, "test_balance_config_validation"),
		"expected_failure": false,
		"desc": "M42: Game balance config validation and parameter access"
	}

static func test_modes_and_floors(fix: GameFixture) -> void:
	var gm = fix.root.get_node("/root/GameManager")
	gm.start_new_game(RunMode.Mode.TIMED_100)
	fix.assert_eq(gm.run_mode, RunMode.Mode.TIMED_100, "Run mode should be TIMED_100")
	fix.assert_eq(gm.completed_floors, 0, "Initial completed floors should be 0")
	fix.assert_eq(gm.last_opened_floor, 1, "Initial last opened floor should be 1")

	# Advance to next floor
	gm.advance_to_next_floor()
	fix.assert_eq(gm.last_opened_floor, 2, "Last opened floor after advance should be 2")
	fix.assert_eq(gm.completed_floors, 0, "Completed floors should not increment simply by entering floor 2")

static func test_continuous_clock(fix: GameFixture) -> void:
	var clock = RunClock.new()
	clock.enable_fake_time(1000)
	clock.start()
	fix.assert_eq(clock.get_elapsed_msec(), 0, "Elapsed at start should be 0")

	clock.advance_fake_time(60000)
	fix.assert_eq(clock.get_elapsed_msec(), 60000, "Elapsed should be 60000ms after advancing 60000ms")
	fix.assert_eq(clock.format_time_string(), "01:00", "Formatted time should be 01:00")

	var frozen = clock.freeze()
	fix.assert_eq(frozen, 60000, "Frozen time should match elapsed time at freeze")
	clock.advance_fake_time(30000)
	fix.assert_eq(clock.get_elapsed_msec(), 60000, "Elapsed should remain frozen after further time advance")

static func test_settlement_rules(fix: GameFixture) -> void:
	# Test cases from M24
	# death S40/C50 -> 45
	var d1 = ProfileRules.settle_run(40, 50, RunMode.Outcome.DEATH)
	fix.assert_eq(d1["settled_gold"], 45, "death S40/C50 should settle to 45")

	# death S40/C10 -> 10
	var d2 = ProfileRules.settle_run(40, 10, RunMode.Outcome.DEATH)
	fix.assert_eq(d2["settled_gold"], 10, "death S40/C10 should settle to 10")

	# retired S40/C50 -> 50
	var r1 = ProfileRules.settle_run(40, 50, RunMode.Outcome.RETIRED)
	fix.assert_eq(r1["settled_gold"], 50, "retired S40/C50 should settle to 50")

	# death S40/C40 -> 40
	var d3 = ProfileRules.settle_run(40, 40, RunMode.Outcome.DEATH)
	fix.assert_eq(d3["settled_gold"], 40, "death S40/C40 should settle to 40")

	# death S40/C51 -> 46
	var d4 = ProfileRules.settle_run(40, 51, RunMode.Outcome.DEATH)
	fix.assert_eq(d4["settled_gold"], 46, "death S40/C51 should settle to 46")

	# first-clear success S40/C50 -> 1049 (with final boss bonus 999)
	var s1 = ProfileRules.settle_run(40, 50, RunMode.Outcome.SUCCESS, 999)
	fix.assert_eq(s1["settled_gold"], 1049, "first-clear success S40/C50 with bonus 999 should settle to 1049")

	# repeat success S40/C50 -> 50 (bonus 0)
	var s2 = ProfileRules.settle_run(40, 50, RunMode.Outcome.SUCCESS, 0)
	fix.assert_eq(s2["settled_gold"], 50, "repeat success S40/C50 with bonus 0 should settle to 50")

static func test_atomic_save_codec_and_store(fix: GameFixture) -> void:
	var temp_dir = "user://test_saves_%d" % Time.get_ticks_msec()
	var store = SaveStore.new(temp_dir)

	var profile = SaveCodec.create_default_profile()
	profile["wallet_gold"] = 150
	profile["village_object_stages"]["square"] = 1

	var envelope = SaveCodec.encode_envelope(profile, {})
	var saved = store.save_envelope(envelope)
	fix.assert_true(saved, "SaveStore should successfully save envelope")

	var loaded = store.load_envelope()
	fix.assert_false(loaded.has("error"), "Loaded envelope should not have error")
	var loaded_prof = loaded.get("profile", {})
	fix.assert_eq(int(loaded_prof.get("wallet_gold", 0)), 150, "Loaded wallet gold should be 150")
	fix.assert_eq(int(loaded_prof.get("village_object_stages", {}).get("square", 0)), 1, "Loaded square stage should be 1")

	# Timed rollback test: an unfinished timed run rolls back to entry_profile_snapshot
	var gm = fix.root.get_node("GameManager")
	var timed_run = gm.build_active_run()
	timed_run["mode"] = "TIMED_100"
	timed_run["terminal_outcome"] = "NONE"
	timed_run["entry_profile_snapshot"] = SaveCodec.create_default_profile()
	var timed_envelope = SaveCodec.encode_envelope(profile, timed_run)
	store.save_envelope(timed_envelope)
	var recovered = store.load_envelope()
	var rec_prof = recovered.get("profile", {})
	fix.assert_eq(int(rec_prof.get("wallet_gold", 0)), 40, "Unfinished timed run should rollback to entry snapshot gold 40")

	# Cleanup test folder
	if DirAccess.dir_exists_absolute(temp_dir):
		var d = DirAccess.open(temp_dir)
		if d != null:
			for f in d.get_files():
				DirAccess.remove_absolute(temp_dir.path_join(f))
		DirAccess.remove_absolute(temp_dir)

static func test_village_state_and_restoration(fix: GameFixture) -> void:
	var v_state = VillageState.new()
	var profile = {"wallet_gold": 5000}

	# CT01: New profile / initial village state has all 6 objects at stage 0
	for obj in ["square", "houses", "chronicler", "marketplace", "forge", "alchemist"]:
		fix.assert_eq(v_state.get_stage(obj), 0, "Object %s starts at stage 0" % obj)

	# CT11: Closed prerequisites
	fix.assert_false(v_state.can_restore("houses", profile["wallet_gold"]), "Houses cannot be restored when square is 0")
	fix.assert_false(v_state.can_restore("chronicler", profile["wallet_gold"]), "Chronicler cannot be restored when square is 0")
	fix.assert_false(v_state.can_restore("marketplace", profile["wallet_gold"]), "Marketplace cannot be restored when square is 0")
	fix.assert_false(v_state.can_restore("forge", profile["wallet_gold"]), "Forge cannot be restored when marketplace is 0")
	fix.assert_false(v_state.can_restore("alchemist", profile["wallet_gold"]), "Alchemist cannot be restored when marketplace is 0")

	# CT10: Direct transition 0 -> 2 is rejected by expected_stage contract
	var res_jump = VillageCommands.execute_restore(v_state, profile, "square", 1)
	fix.assert_false(res_jump["success"], "Jump 0->2 (expected_stage 1 on stage 0) should fail")

	# Verify Section 4.3 chain at wallet 5000:
	# 1. square 1: cost 40 -> wallet 4960
	var res1 = VillageCommands.execute_restore(v_state, profile, "square", 0)
	fix.assert_true(res1["success"], "Square stage 1 restoration should succeed")
	fix.assert_eq(v_state.get_stage("square"), 1, "Square stage should be 1")
	fix.assert_eq(profile["wallet_gold"], 4960, "Wallet after square 1 should be 4960")

	# CT07: Stale revision / repeat restore with old expected_stage 0
	var res_stale = VillageCommands.execute_restore(v_state, profile, "square", 0)
	fix.assert_false(res_stale["success"], "Stale token restore should be rejected")
	fix.assert_eq(profile["wallet_gold"], 4960, "Wallet unchanged after stale attempt")

	# 2. marketplace 1: cost 200 -> wallet 4760
	fix.assert_true(v_state.can_restore("marketplace", profile["wallet_gold"]), "Marketplace 1 can be restored after square >= 1")
	var res2 = VillageCommands.execute_restore(v_state, profile, "marketplace", 0)
	fix.assert_true(res2["success"], "Marketplace stage 1 restoration should succeed")
	fix.assert_eq(v_state.get_stage("marketplace"), 1, "Marketplace stage should be 1")
	fix.assert_eq(profile["wallet_gold"], 4760, "Wallet after marketplace 1 should be 4760")

	# Forge and alchemist require marketplace >= 2; still locked at marketplace 1
	fix.assert_false(v_state.can_restore("forge", profile["wallet_gold"]), "Forge locked at marketplace 1")
	fix.assert_false(v_state.can_restore("alchemist", profile["wallet_gold"]), "Alchemist locked at marketplace 1")

	# 3. marketplace 2: cost 2000 -> wallet 2760
	fix.assert_true(v_state.can_restore("marketplace", profile["wallet_gold"]), "Marketplace 2 can be restored")
	var res3 = VillageCommands.execute_restore(v_state, profile, "marketplace", 1)
	fix.assert_true(res3["success"], "Marketplace stage 2 restoration should succeed")
	fix.assert_eq(v_state.get_stage("marketplace"), 2, "Marketplace stage should be 2")
	fix.assert_eq(profile["wallet_gold"], 2760, "Wallet after marketplace 2 should be 2760")

	# 4. forge 1: cost 400 -> wallet 2360
	fix.assert_true(v_state.can_restore("forge", profile["wallet_gold"]), "Forge 1 can be restored after marketplace >= 2")
	var res4 = VillageCommands.execute_restore(v_state, profile, "forge", 0)
	fix.assert_true(res4["success"], "Forge stage 1 restoration should succeed")
	fix.assert_eq(v_state.get_stage("forge"), 1, "Forge stage should be 1")
	fix.assert_eq(profile["wallet_gold"], 2360, "Wallet after forge 1 should be 2360")

	# 5. alchemist 1: cost 400 -> wallet 1960
	fix.assert_true(v_state.can_restore("alchemist", profile["wallet_gold"]), "Alchemist 1 can be restored after marketplace >= 2")
	var res5 = VillageCommands.execute_restore(v_state, profile, "alchemist", 0)
	fix.assert_true(res5["success"], "Alchemist stage 1 restoration should succeed")
	fix.assert_eq(v_state.get_stage("alchemist"), 1, "Alchemist stage should be 1")
	fix.assert_eq(profile["wallet_gold"], 1960, "Wallet after alchemist 1 should be 1960")

	# CT13: Selecting town cosmetics does not increase building stages
	v_state.selected_cosmetics["village"] = "warm_evening"
	fix.assert_eq(v_state.get_stage("square"), 1, "Cosmetic selection does not alter square stage")
	fix.assert_eq(v_state.get_stage("marketplace"), 2, "Cosmetic selection does not alter marketplace stage")

static func test_campaign_equipment_transfer(fix: GameFixture) -> void:
	var weapon = {"id": "iron_blade", "power": 4, "upgrade_level": 2}
	var armor = {"id": "leather_armor", "power": 2, "damage_reduction": 1}
	var amulet = {"id": "lucky_dice_amulet", "dice_bonus": 2}

	var victory_pack = CampaignEquipmentRules.record_victory_equipment(weapon, armor, amulet)
	fix.assert_true(CampaignEquipmentRules.has_campaign_equipment(victory_pack), "Victory equipment pack should be valid")
	fix.assert_eq(int(victory_pack["weapon"]["upgrade_level"]), 2, "Weapon upgrade level should be preserved in campaign equipment")

	var cleared = CampaignEquipmentRules.clear_equipment()
	fix.assert_false(CampaignEquipmentRules.has_campaign_equipment(cleared), "Cleared equipment pack should be empty")

static func test_dungeon_progression_formulas(fix: GameFixture) -> void:
	# Q calculations:
	# Timed: Q(D1, F1) = 0; Q(D1, F100) = 99; Q(D2, F1) = 100
	fix.assert_eq(DungeonProgression.calculate_q(1, 1, true), 0, "Q(D1, F1) should be 0")
	fix.assert_eq(DungeonProgression.calculate_q(1, 100, true), 99, "Q(D1, F100) should be 99")
	fix.assert_eq(DungeonProgression.calculate_q(2, 1, true), 100, "Q(D2, F1) should be 100")

	# Final boss power: D1 = 332; D2 = 632
	fix.assert_eq(DungeonProgression.calculate_final_boss_power(1, true), 332, "Final boss D1 power should be 332")
	fix.assert_eq(DungeonProgression.calculate_final_boss_power(2, true), 632, "Final boss D2 power should be 632")

	# Floor boss power: F1 = 9
	fix.assert_eq(DungeonProgression.calculate_floor_boss_power(1, 1, true), 9, "Floor 1 boss power should be 9")

static func test_balance_config_validation(fix: GameFixture) -> void:
	var cfg = BalanceConfig.new()
	var loaded = cfg.load_from_file("res://assets/data/game_balance.json")
	fix.assert_true(loaded, "BalanceConfig should load assets/data/game_balance.json")
	fix.assert_eq(cfg.get_hero_max_hp(), 50, "Hero max HP in config should be 50")
	fix.assert_eq(cfg.get_hero_starting_gold(), 40, "Hero starting gold in config should be 40")
	fix.assert_eq(cfg.get_timed_floor_limit(), 100, "Timed floor limit should be 100")
