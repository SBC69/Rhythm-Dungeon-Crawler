extends SceneTree

var failures: int = 0
var assertions: int = 0
var main: Node
var gm: Node

class FailingStore extends SaveStore:
	func save_envelope(_envelope: Dictionary) -> bool:
		return false

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	assertions += 1
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		print("FAIL: " + label)

func fresh() -> void:
	gm.player_profile["active_endless_run"] = false
	gm.start_new_game(RunMode.Mode.ENDLESS)
	main.last_defeated_encounter_id = ""

func select_regular() -> void:
	var slot = -1
	for choice in gm.floor_routes.current_choices:
		if choice.kind == "regular":
			slot = int(choice.door_slot)
			break
	if slot < 0:
		var random = RandomNumberGenerator.new()
		random.seed = 42
		gm.floor_routes = FloorRoutes.create(gm.floor_routes.context, gm.floor_routes.balance_snapshot, random)
		for choice in gm.floor_routes.current_choices:
			if choice.kind == "regular":
				slot = int(choice.door_slot)
	var request = main.encounter_ctrl.request_door(slot, gm.run_generation, gm.floor_routes.revision)
	check(request.get("success", false), "door accepted before animation")
	check(main.encounter_ctrl.apply_door_transition(int(request.get("transition_token", -1))), "accepted transition applied")

func _run() -> void:
	gm = root.get_node("GameManager")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._restore_screen()
	var mode = "core"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
	if mode == "core":
		await test_core()
	elif mode in ["escape-write", "escape-read", "legacy-write", "legacy-read"]:
		await test_process_state(mode)
	elif mode == "balance-ui":
		await test_balance_ui()
	elif mode == "final":
		await test_final_dungeon()
	elif mode == "edges":
		await test_edge_cases()
	elif mode == "devices":
		await test_device_input()
	elif mode == "village":
		await test_village()
	elif mode == "write":
		fresh()
		select_regular()
		check(main.encounter_ctrl.commit_monster_defeat(main.encounter_ctrl.encounter_id), "victory saved")
		check(gm.save_store.load_envelope().get("active_run", {}).get("phase") == "LOOT", "pending loot phase stored on disk")
		var file = FileAccess.open("res://expected-loot.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"gold": gm.player_gold, "options": main.encounter_ctrl.pending_loot, "encounter": main.encounter_ctrl.encounter_id}))
		file.close()
	elif mode == "read":
		var expected = JSON.parse_string(FileAccess.get_file_as_string("res://expected-loot.json"))
		check(main.encounter_ctrl.phase == EncounterController.RunPhase.LOOT, "second process restores LOOT")
		check(main.loot_picker.visible, "second process shows loot screen")
		check(JSON.stringify(main.encounter_ctrl.pending_loot) == JSON.stringify(expected.options), "second process restores identical loot")
		check(gm.player_gold == int(expected.gold), "second process restores exact gold")
		check(not main.encounter_ctrl.commit_monster_defeat(expected.encounter), "loaded victory cannot pay twice")
		check(gm.player_gold == int(expected.gold), "duplicate victory leaves gold unchanged")
		var card = main.encounter_ctrl.pending_loot[0].duplicate(true)
		check(main.encounter_ctrl.resolve_loot_selection(false, card), "loaded loot can be accepted")
		check(not main.encounter_ctrl.resolve_loot_selection(false, card), "loot cannot be accepted twice")
	elif mode == "negative":
		check(false, "intentional runner canary")
	print("RESULT assertions=%d failures=%d" % [assertions, failures])
	main.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)

func test_core() -> void:
	fresh()
	var saved = gm.save_store.load_envelope()
	check(saved.get("active_run", {}).has("floor_state"), "new run contains floor snapshot")
	select_regular()
	var ctrl = main.encounter_ctrl
	var quota = gm.floor_routes.remaining_counts.duplicate(true)
	check(ctrl.commit_monster_defeat(ctrl.encounter_id), "first victory accepted")
	var gold = gm.player_gold
	check(not ctrl.commit_monster_defeat(ctrl.encounter_id), "second victory rejected")
	check(gm.player_gold == gold, "victory gold paid once")
	check(gm.floor_routes.remaining_counts == quota, "victory waits for loot before quota")
	var card = ctrl.pending_loot[0].duplicate(true)
	check(ctrl.resolve_loot_selection(false, card), "loot accepted")
	check(gm.current_room == 2, "loot advances exactly one room")
	check(int(gm.floor_routes.remaining_counts.regular) == int(quota.regular) - 1 and int(gm.floor_routes.remaining_counts.trap) == int(quota.trap), "only completed kind consumes quota")
	check(not ctrl.resolve_loot_selection(false, card), "duplicate loot rejected")
	check(gm.current_room == 2, "duplicate loot does not advance")
	check(not SaveCodec.decode_envelope(FileAccess.get_file_as_string(gm.save_store.get_save_path())).has("error"), "completed room snapshot valid")
	fresh()
	select_regular()
	var real_store = gm.save_store
	var old_gold = gm.player_gold
	gm.save_store = FailingStore.new("res://failed-save")
	check(not ctrl.commit_monster_defeat(ctrl.encounter_id), "disk failure rejects victory publication")
	check(gm.player_gold == old_gold and ctrl.phase == EncounterController.RunPhase.COMBAT, "disk failure restores gold and phase")
	gm.save_store = real_store
	check(ctrl.commit_monster_defeat(ctrl.encounter_id), "victory retry succeeds")
	var snap = gm.floor_routes.serialize()
	snap.remaining_counts.regular = -1
	snap.remaining_counts.trap = 10
	check(not FloorRoutes.from_snapshot(snap).success, "negative quota rejected")
	snap = gm.floor_routes.serialize()
	snap.rng_state = "bad"
	check(not FloorRoutes.from_snapshot(snap).success, "invalid RNG rejected")
	fresh()
	for i in range(10):
		var choice = gm.floor_routes.current_choices[0]
		var request = ctrl.request_door(int(choice.door_slot), gm.run_generation, gm.floor_routes.revision)
		check(request.get("success", false), "floor room %d request" % (i + 1))
		ctrl.apply_door_transition(int(request.get("transition_token", -1)))
		if choice.kind == "trap":
			check(ctrl.resolve_curse(), "floor trap completion")
		else:
			check(ctrl.commit_monster_defeat(ctrl.encounter_id), "floor monster defeat")
			check(ctrl.resolve_loot_selection(choice.kind == "boss", ctrl.pending_loot[0]), "floor monster loot")
	check(ctrl.phase == EncounterController.RunPhase.REST, "boss reaches REST")
	check(gm.floor_routes.get_current_choices().is_empty(), "reading completed boss offers does not regenerate boss")
	check(gm.save_store.load_envelope().get("active_run", {}).get("floor_state", {}).get("completed_rooms", []).size() == 10, "boss completion durable")
	check(not SaveCodec.decode_envelope(FileAccess.get_file_as_string(gm.save_store.get_save_path())).has("error"), "boss and stash snapshot valid")
	check(not gm.floor_routes.commit_room_completion(ctrl.encounter_id).success, "boss cannot complete twice")

	var old = SaveCodec.encode_envelope(SaveCodec.create_default_profile(), {"floor": 2, "room": 4, "mode": "ENDLESS", "gold": 47, "hp": 31})
	old.schema_version = 1
	var old_copy = old.duplicate(true)
	var migrated = SaveCodec.validate_and_migrate(old)
	check(not migrated.has("error"), "legacy save migrates: " + str(migrated.get("error", "OK")))
	if migrated.has("error"):
		return
	check(old == old_copy, "migration leaves input untouched")
	var legacy = FloorRoutes.from_snapshot(migrated.active_run.floor_state).state
	check(not legacy.current_choices[0].data.is_empty(), "legacy encounter has full parameters")
	var legacy_choice = legacy.select_door(0)
	legacy.set_encounter_status(legacy_choice.encounter_id, "defeated_waiting_loot")
	check(legacy.commit_room_completion(legacy_choice.encounter_id).success, "legacy R4 completes")
	check(legacy.generation_version == 1 and legacy.current_depth == 5, "legacy stays legacy until descent")
	check(legacy.current_choices.all(func(c): return c.kind == "elite"), "legacy R5 preserves elite schedule")
	gm.floor_routes = legacy
	gm.current_floor = 2
	gm.current_room = 5
	check(gm.advance_to_next_floor(), "descent persists")
	check(gm.floor_routes.generation_version == 2 and gm.current_floor == 3 and gm.current_room == 1, "next floor uses generation2")
	main._show_dungeon_room(false)
	check(main.dungeon_view.door_left.visible and main.dungeon_view.door_center.visible and main.dungeon_view.door_right.visible, "descent restores all three doors")
	fresh()
	main._show_dungeon_room(false)
	var original_generation = gm.run_generation
	main.dungeon_view.door_left.open_door()
	check(ctrl.phase == EncounterController.RunPhase.TRANSITION, "actual door starts TRANSITION before animation")
	main.dungeon_view.door_right.open_door()
	var chosen_id = ctrl.encounter_id
	await create_timer(0.5).timeout
	fresh()
	main._show_dungeon_room(false)
	await create_timer(0.8).timeout
	check(gm.run_generation > original_generation and ctrl.phase == EncounterController.RunPhase.CORRIDOR, "stale walk cannot open new run")
	check(ctrl.encounter_id != chosen_id, "stale callback cannot restore old encounter")

func test_village() -> void:
	fresh()
	gm.player_profile.wallet_gold = 5000
	main.router.show_village_map()
	var village = main.village_map
	village.open_detail_modal("square")
	village._on_restore_pressed()
	village._on_confirm_ok_pressed()
	check(village.village_state.get_stage("square") == 1, "first confirm buys stage1")
	check(gm.player_profile.wallet_gold == 4960, "first confirm costs40")
	village._on_confirm_ok_pressed()
	check(village.village_state.get_stage("square") == 1 and gm.player_profile.wallet_gold == 4960, "second callback cannot buy stage2")
	village._on_restore_pressed()
	village._on_confirm_cancel_pressed()
	village._on_confirm_ok_pressed()
	check(gm.player_profile.wallet_gold == 4960, "confirm after cancel is no-op")
	village._on_restore_pressed()
	village.village_state.revisions.square += 1
	village._on_confirm_ok_pressed()
	check(village.village_state.get_stage("square") == 1 and gm.player_profile.wallet_gold == 4960, "stale revision rejected")
	village._on_restore_pressed()
	var store = gm.save_store
	gm.save_store = FailingStore.new("res://failed-village-save")
	village._on_confirm_ok_pressed()
	check(village.village_state.get_stage("square") == 1 and gm.player_profile.wallet_gold == 4960, "failed disk write does not publish village")
	check(village.last_restore_error == "UI_SAVE_FAILED", "disk failure displays actionable error")
	gm.save_store = store
	village._on_restore_pressed()
	village._on_confirm_ok_pressed()
	check(village.village_state.get_stage("square") == 2 and gm.player_profile.wallet_gold == 4560, "fresh confirmation retries successfully")
	var saved = gm.save_store.load_envelope()
	check(int(saved.profile.village_object_stages.square) == 2 and int(saved.profile.wallet_gold) == 4560, "village purchase durable")
	check(village.building_nodes.square.current_stage == 2, "map stage changes immediately")

func test_balance_ui() -> void:
	fresh()
	var cfg = gm.balance_config.config_data.duplicate(true)
	cfg.enemies.regular.base = 400
	var random = RandomNumberGenerator.new()
	random.seed = 1
	var ctx = {"mode": "timed", "dungeon_index": 1, "floor_number": 1, "room_number": 1}
	var enemy = EncounterFactory.create_encounter("regular", ctx, random, cfg)
	check(enemy.power == 400 + int(enemy.archetype_offset), "factory reads changed config base")
	check(EncounterFactory.enemy_power("regular", 100, 1, 0, gm.balance_config.config_data) == 204, "D2 F1 regular204")
	check(EncounterFactory.enemy_power("elite", 100, 4, 0, gm.balance_config.config_data) == 312, "D2 F1 elite312")
	check(EncounterFactory.enemy_power("floor_boss", 100, 10, 0, gm.balance_config.config_data) == 319, "D2 F1 boss319")
	for trap_id in cfg.traps.templates:
		cfg.traps.templates[trap_id].weight = 1 if trap_id == "cursed_altar" else 0
	var altar = EncounterFactory.create_encounter("trap", ctx, random, cfg)
	check(altar.power_drain == 1, "altar translates configured drain")
	gm.floor_power_penalty = 1
	check(gm.advance_to_next_floor() and gm.floor_power_penalty == 0, "descent removes floor curse")
	var custom = BalanceConfig.new()
	cfg.village.objects.square.stage_prices[0] = 77
	custom.load_from_dict(cfg)
	check(VillageState.new(custom).get_next_cost("square") == 77, "village prices read config")
	gm.player_profile.wallet_gold = 5000
	main.router.show_village_map()
	var village = main.village_map
	village.open_detail_modal("square")
	await process_frame
	var outside = 0
	for i in range(35):
		var key = InputEventKey.new()
		key.keycode = KEY_TAB
		key.pressed = true
		root.push_input(key)
		await process_frame
		var focus = root.gui_get_focus_owner()
		if focus == null or not village.detail_modal.is_ancestor_of(focus):
			outside += 1
		key = InputEventKey.new()
		key.keycode = KEY_TAB
		key.pressed = false
		root.push_input(key)
	check(outside == 0, "35 Tab presses remain inside detail modal")
	check(village.building_nodes.values().all(func(b): return b.disabled), "modal blocks map buttons")
	village._on_restore_pressed()
	var action = InputEventAction.new()
	action.action = "ui_right"
	action.pressed = true
	root.push_input(action)
	await process_frame
	check(village.confirm_modal.is_ancestor_of(root.gui_get_focus_owner()), "directional navigation stays inside confirm")
	village._on_confirm_cancel_pressed()
	village.close_detail_modal()
	check(root.gui_get_focus_owner() == village.building_nodes.square, "closing panel returns building focus")
	TranslationServer.set_locale("en")
	await process_frame
	village.open_detail_modal("square")
	check(village.detail_title.text == "Village Square", "English building title")
	var expected_description = ["Rubble", "Cleared", "A well", "Restored"][village.village_state.get_stage("square")]
	check(village.detail_cur_desc.text.begins_with("Current state:") and village.detail_cur_desc.text.contains(expected_description), "English catalog description")
	TranslationServer.set_locale("ru")
	await process_frame
	for viewport in [Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.content_scale_size = Vector2i.ZERO
		root.size = viewport
		for factor in [1.0, 2.0, 3.0]:
			village.set_text_scale(factor)
			await process_frame
			await process_frame
			village._adapt_layout()
			await process_frame
			var card = village.detail_modal.get_node("Card")
			var bounds = Rect2(Vector2.ZERO, Vector2(viewport))
			check(bounds.encloses(card.get_global_rect()), "detail fits %s scale%s" % [viewport, factor])
			check(bounds.encloses(village.detail_close_button.get_global_rect()), "close button fits %s scale%s" % [viewport, factor])
			check(village.wallet_label.size.x > 50 and bounds.encloses(village.wallet_label.get_global_rect()), "wallet visible %s scale%s" % [viewport, factor])

func test_process_state(mode: String) -> void:
	if mode == "escape-write":
		fresh()
		var before_choices = JSON.stringify(gm.floor_routes.current_choices)
		select_regular()
		var ctrl = main.encounter_ctrl
		gm.temp_combat_power_buff = 9
		check(ctrl.request_escape(ctrl.encounter_id), "escape request accepted")
		check(ctrl.resolve_escape(true), "escape persisted")
		check(gm.temp_combat_power_buff == 0, "escape removes temporary buff")
		var file = FileAccess.open("res://expected-escape.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"choices": gm.floor_routes.current_choices, "rng": gm.floor_routes.rng_state, "remaining": gm.floor_routes.remaining_counts}))
		file.close()
	elif mode == "escape-read":
		var expected = JSON.parse_string(FileAccess.get_file_as_string("res://expected-escape.json"))
		check(main.encounter_ctrl.phase == EncounterController.RunPhase.CORRIDOR, "escape restores corridor in second process")
		check(JSON.stringify(gm.floor_routes.current_choices) == JSON.stringify(expected.choices), "escape preserves all door parameters across processes")
		check(gm.floor_routes.rng_state == expected.rng, "escape preserves RNG across processes")
		check(gm.floor_routes.remaining_counts == expected.remaining, "escape preserves quota across processes")
		var original = {}
		for choice in gm.floor_routes.current_choices:
			if choice.kind == "regular":
				original = choice.duplicate(true)
				break
		var ctrl = main.encounter_ctrl
		var request = ctrl.request_door(int(original.door_slot), gm.run_generation, gm.floor_routes.revision)
		check(request.get("success", false), "re-entry after escape accepted")
		check(ctrl.apply_door_transition(int(request.transition_token)), "re-entry opens encounter")
		check(ctrl.encounter_id == original.encounter_id and int(ctrl.current_encounter.power) == int(original.data.power), "re-entry keeps original monster and power")
		ctrl.request_escape(ctrl.encounter_id)
		check(ctrl.resolve_escape(true), "second escape preserves choices")
		var other = gm.floor_routes.get_choice_by_slot((int(original.door_slot) + 1) % 3)
		request = ctrl.request_door(int(other.door_slot), gm.run_generation, gm.floor_routes.revision)
		check(request.get("success", false), "different door after escape accepted")
		check(ctrl.current_encounter.encounter_id == other.encounter_id and ctrl.current_encounter.get("id") == other.data.get("id"), "different door uses saved encounter")
	elif mode == "legacy-write":
		var old = SaveCodec.encode_envelope(SaveCodec.create_default_profile(), {"mode": "ENDLESS", "floor": 2, "room": 4, "hp": 31, "gold": 47})
		old.schema_version = 1
		check(gm.save_store.save_envelope(old), "legacy fixture written to actual store")
	elif mode == "legacy-read":
		check(gm.floor_routes.generation_version == 1 and gm.current_room == 4, "second process restores legacy current floor")
		check(gm.player_gold == 47 and gm.player_hp == 31, "migration preserves hero state")
		var disk = JSON.parse_string(FileAccess.get_file_as_string(gm.save_store.get_save_path()))
		check(int(disk.schema_version) == 3, "migration saved once before input")
		check(gm.save_store.load_envelope().active_run.floor_state == disk.active_run.floor_state, "reloading migration does not change proposals")

func test_device_input() -> void:
	fresh()
	gm.player_profile.wallet_gold = 5000
	main.router.show_village_map()
	var village = main.village_map
	await process_frame
	var fixture = GameFixture.new(self)
	await fixture.simulate_click(village.building_nodes.square)
	check(village.detail_modal.visible and village.selected_object_id == "square", "mouse opens map building")
	await fixture.simulate_click(village.detail_restore_button)
	check(village.confirm_modal.visible, "mouse opens restoration confirmation")
	var selected_before = village.selected_object_id
	await fixture.simulate_click(village.building_nodes.houses)
	check(village.selected_object_id == selected_before, "modal blocks actual background map click")
	village.confirm_cancel_button.grab_focus()
	var joy = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	root.push_input(joy, true)
	await process_frame
	joy = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = false
	root.push_input(joy, true)
	await process_frame
	check(not village.confirm_modal.visible and gm.player_profile.wallet_gold == 5000, "gamepad cancel leaves gold unchanged")
	var stage_before = village.village_state.get_stage("square")
	var expected_gold = 5000 - village.village_state.get_next_cost("square")
	village._on_restore_pressed()
	village.confirm_ok_button.grab_focus()
	joy = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	root.push_input(joy, true)
	await process_frame
	joy = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = false
	root.push_input(joy, true)
	await process_frame
	check(village.village_state.get_stage("square") == stage_before + 1 and gm.player_profile.wallet_gold == expected_gold, "gamepad confirms actual purchase")
	await fixture.simulate_key(KEY_ESCAPE)
	check(not village.detail_modal.visible, "keyboard closes top panel")

func test_edge_cases() -> void:
	fresh()
	var ctrl = main.encounter_ctrl
	var snapshot = gm.floor_routes.serialize()
	check(JSON.stringify(gm.floor_routes.get_current_choices()) == JSON.stringify(gm.floor_routes.get_current_choices()) and JSON.stringify(gm.floor_routes.serialize()) == JSON.stringify(snapshot), "reading offers twice does not mutate state or RNG")
	check(gm.floor_routes.remaining_counts == gm.floor_routes.initial_counts, "creating proposals does not consume quota")
	var bad = snapshot.duplicate(true)
	bad.current_choices[1].encounter_id = bad.current_choices[0].encounter_id
	check(not FloorRoutes.from_snapshot(bad).success, "duplicate offer ID rejected")
	bad = snapshot.duplicate(true)
	bad.current_choices[1].door_slot = bad.current_choices[0].door_slot
	check(not FloorRoutes.from_snapshot(bad).success, "duplicate door slot rejected")
	bad = snapshot.duplicate(true)
	bad.selected_encounter_id = "unknown"
	check(not FloorRoutes.from_snapshot(bad).success, "unknown selected encounter rejected")
	bad = snapshot.duplicate(true)
	bad.remaining_counts.regular = 6.5
	check(not FloorRoutes.from_snapshot(bad).success, "fractional quota rejected")
	bad = snapshot.duplicate(true)
	bad.current_choices[0].data = {}
	check(not FloorRoutes.from_snapshot(bad).success, "empty encounter data rejected")
	var large = snapshot.duplicate(true)
	large.rng_state = "9223372036854775807"
	var roundtrip = FloorRoutes.from_snapshot(JSON.parse_string(JSON.stringify(large)))
	check(roundtrip.success and str(roundtrip.state.rng.state) == large.rng_state, "large RNG string restores exactly")
	var store = gm.save_store
	gm.save_store = FailingStore.new("res://failed-door")
	var req = ctrl.request_door(0, gm.run_generation, gm.floor_routes.revision)
	check(not req.get("success", false), "unsaved door request rejected")
	check(ctrl.phase == EncounterController.RunPhase.CORRIDOR and gm.floor_routes.selected_encounter_id.is_empty(), "door save failure restores corridor")
	gm.save_store = store
	select_regular()
	check(ctrl.commit_monster_defeat(ctrl.encounter_id), "loot failure fixture victory")
	var card = ctrl.pending_loot[0].duplicate(true)
	var gold_before = gm.player_gold
	gm.save_store = FailingStore.new("res://failed-loot")
	check(not ctrl.resolve_loot_selection(false, card), "loot save failure rejects completion")
	check(ctrl.phase == EncounterController.RunPhase.LOOT and gm.current_room == 1 and gm.floor_stash.is_empty() and gm.player_gold == gold_before, "loot save failure restores full state")
	gm.save_store = store
	check(ctrl.resolve_loot_selection(false, card), "loot retry accepted exactly once")
	check(gm.floor_stash.size() == 1 and gm.current_room == 2, "loot retry produces one card and one room")
	fresh()
	select_regular()
	ctrl.request_escape(ctrl.encounter_id)
	var hp_before = gm.player_hp
	store = gm.save_store
	gm.save_store = FailingStore.new("res://failed-escape")
	check(not ctrl.resolve_escape(false, 10), "failed escape write rejected")
	check(gm.player_hp == hp_before and ctrl.phase == EncounterController.RunPhase.ESCAPE, "failed escape write restores HP")
	gm.save_store = store
	check(ctrl.resolve_escape(false, 10) and gm.player_hp == hp_before - 9, "escape retry applies damage once")
	fresh()
	var choice = gm.floor_routes.current_choices[0]
	choice.kind = "trap"
	choice.data = {"id": "test_trap", "dc": 7, "damage_on_fail": 20, "power_drain": 0}
	req = ctrl.request_door(0, gm.run_generation, gm.floor_routes.revision)
	ctrl.apply_door_transition(int(req.transition_token))
	var quota = gm.floor_routes.remaining_counts.duplicate(true)
	gm.player_hp = 5
	check(ctrl.resolve_curse(20), "lethal trap accepted")
	check(gm.terminal_outcome == RunMode.Outcome.DEATH, "lethal trap settles death")
	check(gm.current_room == 1 and gm.floor_routes.remaining_counts == quota and gm.floor_routes.completed_rooms.is_empty(), "lethal trap does not consume room quota")
	fresh()
	var config = gm.balance_config.config_data
	var context = {"run_id": "repeat", "mode": "timed", "dungeon_id": "crypts", "dungeon_index": 1, "floor_number": 100, "final_boss_defeated": true}
	var repeat_floor = FloorRoutes.create(context, config)
	check(repeat_floor.boss_encounter.is_empty(), "permanently dead final boss has no offer")
	for i in range(9):
		var selected = repeat_floor.select_door(0)
		if selected.kind != "trap":
			repeat_floor.set_encounter_status(selected.encounter_id, "defeated_waiting_loot")
		check(repeat_floor.commit_room_completion(selected.encounter_id).success, "repeat-final ordinary room completion")
	check(repeat_floor.current_choices.is_empty() and FloorRoutes.from_snapshot(repeat_floor.serialize()).success, "repeat final ends after R9 without boss screen")

func test_final_dungeon() -> void:
	fresh()
	gm.run_mode = RunMode.Mode.TIMED_100
	gm.current_dungeon_id = "ash_forges"
	gm.current_floor = 100
	gm._create_floor_routes_for_current_floor()
	for i in range(9):
		var chosen = gm.floor_routes.select_door(0)
		if chosen.kind != "trap":
			gm.floor_routes.set_encounter_status(chosen.encounter_id, "defeated_waiting_loot")
		check(gm.floor_routes.commit_room_completion(chosen.encounter_id).success, "final fixture ordinary completion")
	gm.current_room = 10
	var ctrl = main.encounter_ctrl
	var request = ctrl.request_door(1, gm.run_generation, gm.floor_routes.revision)
	check(request.get("success", false), "D2 final boss accepted")
	ctrl.apply_door_transition(int(request.get("transition_token", -1)))
	check(ctrl.commit_monster_defeat(ctrl.encounter_id), "D2 final victory accepted")
	var gold = gm.player_gold
	main._on_loot_selected(ctrl.pending_loot[0])
	check(gm.terminal_outcome == RunMode.Outcome.SUCCESS, "D2 completes successfully")
	check("ash_forges" in gm.player_profile.defeated_final_boss_ids, "D2 boss permanent death recorded for D2")
	check("drowned_temple" in gm.player_profile.unlocked_dungeon_ids, "D2 opens D3 from configured chain")
	check(gm.player_profile.wallet_gold == gold + 999, "final bonus paid exactly once")
	main._on_restart_requested()
	check(main.village_map.visible, "result button returns to village")
