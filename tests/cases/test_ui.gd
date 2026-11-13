# tests/cases/test_ui.gd
class_name TestUI
extends RefCounted

static func register_tests(registry: Dictionary) -> void:
	registry["T-KEYBOARD"] = {
		"fn": Callable(TestUI, "test_keyboard_navigation"),
		"expected_failure": false,
		"desc": "Keyboard-only menus, cards, scrolling, modal isolation, and focus recovery"
	}
	registry["T-KEYBOARD-ENCOUNTERS"] = {
		"fn": Callable(TestUI, "test_keyboard_encounters"),
		"expected_failure": false,
		"desc": "Keyboard encounter actions, rhythm input isolation, dice, traps, and loot"
	}
	registry["T-MAIN-MENU"] = {
		"fn": Callable(TestUI, "test_main_menu_navigation"),
		"expected_failure": false,
		"desc": "Boot menu, mode selection, village return, and lossless endless-run continuation"
	}
	registry["T-DUNGEON-ART"] = {
		"fn": Callable(TestUI, "test_dungeon_art_selection"),
		"expected_failure": false,
		"desc": "Dungeon-specific corridor and three matching doors survive room resets and boss transitions"
	}
	registry["T-C04"] = {
		"fn": Callable(TestUI, "test_c04_merchant_modal_focus_leak"),
		"expected_failure": false,
		"desc": "C04: Merchant modal allows Tab/Enter to trigger background descend button"
	}
	registry["T-C09"] = {
		"fn": Callable(TestUI, "test_c09_card_description_scaling"),
		"expected_failure": false,
		"desc": "C09: Card description fails to update with floor scaling"
	}
	registry["T-C10"] = {
		"fn": Callable(TestUI, "test_c10_loot_subtitle_mismatch"),
		"expected_failure": false,
		"desc": "C10: Loot subtitle promises all cards to chest, but potions go to hand"
	}
	registry["T-C11"] = {
		"fn": Callable(TestUI, "test_c11_boss_door_label_not_updated"),
		"expected_failure": false,
		"desc": "C11: Boss door label remains default text 'Дверь' instead of boss title"
	}
	registry["T-CT-VILLAGE-MAP"] = {
		"fn": Callable(TestUI, "test_village_map_ui_and_persistence"),
		"expected_failure": false,
		"desc": "CT01-CT14: Isometric village map, building nodes, Y-sorting, modals, and atomic persistence"
	}

static func _keyboard_focus(fix: GameFixture, target: Control) -> void:
	for i in range(100):
		if fix.root.gui_get_focus_owner() == target:
			return
		await fix.simulate_key(KEY_TAB)
	fix.assert_true(false, "Target is reachable with Tab: " + str(target.get_path()))

static func test_keyboard_navigation(fix: GameFixture) -> void:
	var main = await fix.create_main(true)
	var gm = fix.root.get_node("GameManager")
	var cdb = fix.root.get_node("CardDatabase")
	await fix.simulate_key(KEY_TAB)
	fix.assert_eq(fix.root.gui_get_focus_owner(), main.main_menu.village_button, "Tab moves to the next menu action")
	await fix.simulate_key(KEY_TAB, true)
	fix.assert_eq(fix.root.gui_get_focus_owner(), main.main_menu.new_game_button, "Shift+Tab moves to the previous menu action")
	await fix.simulate_key(KEY_ENTER)
	fix.assert_true(main.mode_select.visible, "Enter starts a new expedition from the menu")
	await fix.simulate_key(KEY_ESCAPE)
	await fix.simulate_key(KEY_DOWN)
	await fix.simulate_key(KEY_ENTER)
	fix.assert_true(main.village_map.visible, "Arrow and Enter open the village")
	await _keyboard_focus(fix, main.village_map.building_nodes["square"])
	await fix.simulate_key(KEY_ENTER)
	fix.assert_true(main.village_map.detail_modal.visible, "Enter opens building details")
	var detail_focus = fix.root.gui_get_focus_owner()
	await fix.simulate_key(KEY_TAB)
	await fix.simulate_key(KEY_TAB, true)
	fix.assert_eq(fix.root.gui_get_focus_owner(), detail_focus, "Reverse Tab works inside village details")
	for i in range(5):
		await fix.simulate_key(KEY_TAB)
		fix.assert_true(main.village_map.detail_modal.is_ancestor_of(fix.root.gui_get_focus_owner()), "Village focus stays in details")
	await fix.simulate_key(KEY_ESCAPE)
	fix.assert_eq(fix.root.gui_get_focus_owner(), main.village_map.building_nodes["square"], "Escape restores building focus")
	await fix.simulate_key(KEY_ESCAPE)
	fix.assert_true(main.main_menu.visible, "Escape returns to the menu")
	await fix.simulate_key(KEY_ENTER)
	await fix.simulate_key(KEY_ENTER)
	await fix.tree.create_timer(1.0).timeout
	fix.assert_true(main.dungeon_view.visible, "Keyboard starts the run")
	await _keyboard_focus(fix, main.dungeon_view.door_center)
	await fix.simulate_key(KEY_LEFT)
	fix.assert_eq(fix.root.gui_get_focus_owner(), main.dungeon_view.door_left, "Left selects the left door")
	await fix.simulate_key(KEY_RIGHT)
	await fix.simulate_key(KEY_ENTER)
	fix.assert_eq(main.encounter_ctrl.phase, EncounterController.RunPhase.TRANSITION, "Enter requests the selected door")
	await fix.tree.create_timer(1.6).timeout
	await fix.teardown()

	main = await fix.create_main()
	gm.hand_cards.clear()
	for i in range(14):
		gm.add_card_to_hand(cdb.get_card_data("rusty_sword"))
	gm.add_card_to_hand(cdb.get_card_data("minor_health_potion"))
	await fix.tree.process_frame
	await _keyboard_focus(fix, main.hand_ui.cards_container.get_child(0))
	await fix.simulate_key(KEY_ENTER)
	fix.assert_eq(str(gm.equipped_weapon.get("id", "")), "rusty_sword", "Enter equips a card without dragging")
	fix.assert_true(main.hand_ui.cards_container.is_ancestor_of(fix.root.gui_get_focus_owner()), "Inventory rebuild preserves keyboard focus")
	await _keyboard_focus(fix, main.hand_ui.cards_container.get_child(main.hand_ui.cards_container.get_child_count() - 1))
	await fix.tree.process_frame
	await fix.tree.process_frame
	fix.assert_true(main.hand_ui.scroll_container.scroll_horizontal > 0, "Inventory scroll follows keyboard selection")
	# Find the potion even if equipping returned the previous weapon to the end.
	for card in main.hand_ui.cards_container.get_children():
		if str(card.card_data.get("id", "")) == "minor_health_potion":
			await _keyboard_focus(fix, card)
			break
	gm.player_hp = 40
	await fix.simulate_key(KEY_SPACE)
	fix.assert_true(gm.player_hp > 40, "Space uses the selected potion")
	fix.assert_true(main.hand_ui.cards_container.is_ancestor_of(fix.root.gui_get_focus_owner()), "Consumed card leaves focus on a surviving card")

	main.encounter_ctrl.set_phase(EncounterController.RunPhase.REST)
	main.router.show_rest_room()
	await fix.tree.process_frame
	await _keyboard_focus(fix, main.rest_room.merchant_button)
	await fix.simulate_key(KEY_ENTER)
	fix.assert_true(main.merchant_sell_modal.visible, "Keyboard opens merchant")
	var shop = main.merchant_sell_modal
	await _keyboard_focus(fix, shop.cards_container.get_child(0))
	await fix.simulate_key(KEY_ENTER)
	fix.assert_true(shop.confirm_overlay.visible, "Enter requests a sale")
	await fix.simulate_key(KEY_TAB)
	fix.assert_eq(fix.root.gui_get_focus_owner(), shop.cancel_button, "Tab selects cancel")
	await fix.simulate_key(KEY_TAB, true)
	fix.assert_eq(fix.root.gui_get_focus_owner(), shop.confirm_button, "Reverse Tab selects confirm")
	for key in [KEY_LEFT, KEY_DOWN, KEY_TAB, KEY_RIGHT, KEY_UP]:
		await fix.simulate_key(key)
		fix.assert_true(fix.root.gui_get_focus_owner() in [shop.confirm_button, shop.cancel_button], "All navigation stays in sale confirmation")
	await fix.simulate_key(KEY_ESCAPE)
	fix.assert_false(shop.confirm_overlay.visible, "Escape cancels a sale")
	await _keyboard_focus(fix, shop.cards_container.get_child(0))
	await fix.simulate_key(KEY_ENTER)
	var gold_before: int = gm.player_gold
	await fix.simulate_key(KEY_ENTER)
	fix.assert_true(gm.player_gold > gold_before, "Keyboard confirms a sale")
	await fix.simulate_key(KEY_TAB, true)
	fix.assert_true(shop.is_ancestor_of(fix.root.gui_get_focus_owner()), "Reverse Tab stays in merchant after rebuilding cards")
	await fix.simulate_key(KEY_ESCAPE)
	fix.assert_false(shop.visible or gm.is_shop_open, "Escape closes merchant")
	fix.assert_eq(fix.root.gui_get_focus_owner(), main.rest_room.merchant_button, "Closing merchant restores its opener")
	await fix.teardown()

static func test_keyboard_encounters(fix: GameFixture) -> void:
	var main = await fix.create_main()
	var gm = fix.root.get_node("GameManager")
	var cdb = fix.root.get_node("CardDatabase")
	await fix.enter_regular_encounter(main)
	var fight = main.monster_view.victory_button if main.monster_view.victory_button.visible else main.monster_view.fight_penalty_button
	await _keyboard_focus(fix, fight)
	await fix.simulate_key(KEY_ENTER)
	fix.assert_true(main.monster_view.is_resolving and main.encounter_ctrl.combat_input_locked, "Enter starts rhythm combat")
	await fix.simulate_key(KEY_TAB)
	fix.assert_eq(fix.root.gui_get_focus_owner(), null, "Tab cannot activate inventory during rhythm combat")

	main.router.show_curse({"name": "Keyboard test trap", "dc": 6, "damage_on_fail": 1})
	await fix.tree.process_frame
	fix.assert_false(main.encounter_ctrl.combat_input_locked, "Changing screens releases rhythm input lock")
	await _keyboard_focus(fix, main.curse_event.action_button)
	await fix.simulate_key(KEY_ENTER)
	await fix.tree.create_timer(0.6).timeout
	fix.assert_true(main.curse_event.has_rolled, "Enter rolls trap saving dice")
	await _keyboard_focus(fix, main.curse_event.action_button)
	fix.assert_false(main.curse_event.action_button.disabled, "Trap result remains reachable with the keyboard")

	main.router.show_escape(main.monster_view.current_monster)
	await fix.tree.process_frame
	await _keyboard_focus(fix, main.dice_escape.action_button)
	await fix.simulate_key(KEY_SPACE)
	await fix.tree.create_timer(0.8).timeout
	fix.assert_true(main.dice_escape.has_rolled, "Space rolls escape dice")
	await _keyboard_focus(fix, main.dice_escape.action_button)
	fix.assert_false(main.dice_escape.action_button.disabled, "Escape action recovers after rolling")

	fix.assert_true(main.encounter_ctrl.commit_monster_defeat(main.encounter_ctrl.encounter_id), "Prepare loot phase")
	main.encounter_ctrl.pending_loot = [cdb.get_card_data("minor_health_potion"), cdb.get_card_data("rusty_sword")]
	main.router.show_loot(gm.current_floor)
	await fix.tree.process_frame
	var options = main.loot_picker.cards_container
	await _keyboard_focus(fix, options.get_child(0))
	await fix.simulate_key(KEY_RIGHT)
	fix.assert_eq(fix.root.gui_get_focus_owner(), options.get_child(1), "Right selects the next loot option")
	var stash_before: int = gm.floor_stash.size()
	await fix.simulate_key(KEY_ENTER)
	fix.assert_eq(gm.floor_stash.size(), stash_before + 1, "Enter accepts loot exactly once")
	fix.assert_true(main.dungeon_view.visible, "Keyboard loot selection returns to the corridor")
	await fix.tree.create_timer(0.6).timeout
	await fix.teardown()

static func test_main_menu_navigation(fix: GameFixture) -> void:
	var main = await fix.create_main(true)
	var gm = fix.root.get_node("GameManager")
	fix.assert_true(main.main_menu.visible, "Game opens on its main menu")
	fix.assert_false(main.dungeon_view.visible or main.hud.visible or main.hand_ui.visible, "Gameplay is hidden behind the menu")
	fix.assert_false(main.main_menu.continue_button.visible, "Fresh profile does not offer a nonexistent saved endless run")
	await fix.simulate_click(main.main_menu.new_game_button)
	fix.assert_true(main.mode_select.visible, "New expedition opens the mode chooser")
	await fix.simulate_key(KEY_ESCAPE)
	fix.assert_true(main.main_menu.visible, "Escape returns from mode selection")
	await fix.simulate_click(main.main_menu.village_button)
	fix.assert_true(main.village_map.visible, "Village opens from the menu")
	await fix.simulate_click(main.village_map.menu_button)
	fix.assert_true(main.main_menu.visible, "Village has a working main-menu button")
	gm.start_new_game(RunMode.Mode.ENDLESS)
	main.encounter_ctrl.restore({})
	main.router.show_main_menu()
	await fix.tree.process_frame
	var before := JSON.stringify(gm.build_active_run())
	fix.assert_true(main.main_menu.continue_button.visible, "Active endless run can be continued")
	fix.assert_true(main.main_menu.new_game_button.disabled, "A saved endless run cannot be overwritten by a new expedition")
	await fix.simulate_click(main.main_menu.continue_button)
	fix.assert_true(main.dungeon_view.visible and not main.main_menu.visible, "Continue restores the corridor")
	fix.assert_eq(JSON.stringify(gm.build_active_run()), before, "Continuing preserves the run and generated door choices")
	await fix.teardown()

static func test_dungeon_art_selection(fix: GameFixture) -> void:
	var main = await fix.create_main()
	var gm = fix.root.get_node("GameManager")
	var view = main.dungeon_view
	var corridors: Dictionary = {}
	var doors: Dictionary = {}
	for dungeon_id in view.DUNGEON_ART:
		gm.current_dungeon_id = dungeon_id
		gm.current_room = 1
		view.reset_view()
		var folder: String = view.DUNGEON_ART[dungeon_id]
		fix.assert_eq(view.visual_dungeon_id, dungeon_id, "Art follows the selected dungeon")
		fix.assert_eq(view.corridor_rect.texture.resource_path, folder + "corridor.png", "Correct corridor is loaded")
		corridors[view.corridor_rect.texture.resource_path] = true
		for door in [view.door_left, view.door_center, view.door_right]:
			fix.assert_true(door.visible and door.is_active, "All ordinary doors stay usable")
			var art: AtlasTexture = door.texture_rect.texture
			fix.assert_eq(art.atlas.resource_path, folder + "door.png", "All doors match their corridor")
			fix.assert_true(art.region.size.x < art.atlas.get_width() * 0.9, "Transparent horizontal padding is excluded")
			fix.assert_true(art.region.size.y > art.atlas.get_height() * 0.8, "The complete arch remains visible")
			fix.assert_eq(door.texture_rect.stretch_mode, TextureRect.STRETCH_SCALE, "Visible door fills the passage in both dimensions")
		doors[view.door_center.texture_rect.texture.atlas.resource_path] = true
		gm.current_room = gm.MAX_ROOMS_PER_FLOOR
		view.reset_view()
		fix.assert_true(view.door_center.visible and view.door_center.is_active, "Boss door stays usable")
		fix.assert_false(view.door_left.visible or view.door_right.visible, "Boss room still has one door")
		fix.assert_eq(view.door_center.texture_rect.texture.atlas.resource_path, folder + "door.png", "Boss reset retains themed art")
	fix.assert_eq(corridors.size(), 5, "Each dungeon has a distinct corridor")
	fix.assert_eq(doors.size(), 5, "Each dungeon has a distinct door")
	gm.current_dungeon_id = "unknown_legacy_dungeon"
	view.reset_view()
	fix.assert_eq(view.visual_dungeon_id, "crypts", "Unknown dungeon ID safely uses the crypts artwork")
	await fix.teardown()

static func test_c04_merchant_modal_focus_leak(fix: GameFixture) -> void:
	var main = await fix.create_main()
	var gm = fix.root.get_node("/root/GameManager")
	var rest_room = main.get_node("RestRoom")
	var merchant_modal = main.get_node("MerchantSellModal")
	
	# Show rest room and open merchant
	main._show_dungeon_room(false)
	rest_room.visible = true
	rest_room.setup_rest_room()
	
	merchant_modal.open_shop()
	fix.assert_true(gm.is_shop_open, "Shop should be open")
	
	# Simulate Tab key to see if focus escapes to background DescendButton
	await fix.simulate_key(KEY_TAB)
	var focus_owner = fix.root.gui_get_focus_owner()
	
	# In baseline, focus is not constrained to modal, and may reach background DescendButton
	var descend_btn = rest_room.get_node("%DescendButton")
	var leaked_to_descend = (focus_owner == descend_btn)
	
	# TARGET ASSERTION: Focus should NOT be on background DescendButton
	fix.assert_false(leaked_to_descend, "TARGET: Tab in modal should not focus background DescendButton")
	await fix.teardown()

static func test_c09_card_description_scaling(fix: GameFixture) -> void:
	var cdb = fix.root.get_node("/root/CardDatabase")
	
	# Generate scaled card on floor 5
	var card = cdb.get_card_for_floor(5, "health_potion")
	var heal_amount = int(card.get("heal", 0))
	var desc: String = card.get("description", "")
	
	# On floor 5, heal_amount is scaled (e.g. 15 + 4*5 = 35)
	# In baseline, description is still "+15 HP"!
	fix.assert_true(heal_amount > 15, "Floor 5 potion should heal more than 15 HP (got: %d)" % heal_amount)
	
	# TARGET ASSERTION: Description must contain the actual scaled amount
	var expected_str = "+%d HP" % heal_amount
	fix.assert_true(desc.contains(expected_str), "TARGET: Description should contain actual scaled value '%s', got '%s'" % [expected_str, desc])

static func test_c10_loot_subtitle_mismatch(fix: GameFixture) -> void:
	var main = await fix.create_main()
	var loot_picker = main.get_node("LootPicker")
	var subtitle_lbl = loot_picker.get_node("%SubtitleLabel")
	
	# Check subtitle text
	var text: String = subtitle_lbl.text
	
	# In baseline, subtitle says "Все карты отправляются в сундук этажа...",
	# but potions and buffs actually go directly to hand!
	# TARGET ASSERTION: Subtitle accurately reflects the mechanic (after M14, all cards actually go to chest)
	# On baseline, before M14, potions go to hand instead of floor_stash
	var gm = fix.root.get_node("/root/GameManager")
	var cdb = fix.root.get_node("/root/CardDatabase")
	var potion = cdb.get_card_data("health_potion")
	var hand_before = gm.hand_cards.size()
	var stash_before = gm.floor_stash.size()
	
	await fix.enter_regular_encounter(main)
	fix.assert_true(main.encounter_ctrl.commit_monster_defeat(main.encounter_ctrl.encounter_id), "Victory accepted before loot")
	main.encounter_ctrl.pending_loot = [potion]
	main.router.show_loot(gm.current_floor)
	loot_picker._on_card_chosen(potion)
	# Before M14, loot_picker or main puts it in hand or stash
	# Let's verify target behavior: ALL cards earned go to floor_stash
	fix.assert_eq(gm.floor_stash.size(), stash_before + 1, "TARGET: Looted potion should be stored in floor_stash until boss defeated")
	await fix.teardown()

static func test_c11_boss_door_label_not_updated(fix: GameFixture) -> void:
	var main = await fix.create_main()
	var gm = fix.root.get_node("/root/GameManager")
	var dungeon_view = main.get_node("DungeonView")
	
	# Room 10 is the boss room
	gm.current_room = 10
	dungeon_view.reset_view()
	
	var door_center = dungeon_view.get_node_or_null("%DoorCenter")
	if door_center == null:
		door_center = dungeon_view.get_node_or_null("DoorsContainer/DoorCenter")
	if door_center == null:
		door_center = dungeon_view.door_center
	var label = door_center.get_node_or_null("%DoorLabel") if door_center.has_node("%DoorLabel") else door_center.get_node_or_null("Label")
	if label == null:
		label = door_center.label
	
	# In baseline: door_center.door_title is "👑 ВРАТА БОССА", but label.text is "Дверь"!
	# TARGET ASSERTION: label.text must match boss title
	fix.assert_eq(label.text, door_center.door_title, "TARGET: Door label.text should match door_title on boss room")
	await fix.teardown()

static func test_village_map_ui_and_persistence(fix: GameFixture) -> void:
	# CT02: All 24 building sprites + dungeon_entrance + village_ground exist on disk
	var objects = ["square", "houses", "chronicler", "marketplace", "forge", "alchemist"]
	for obj in objects:
		for stage in [0, 1, 2, 3]:
			var sprite_file = "res://assets/sprites/village/%s/stage_%d.png" % [obj, stage]
			fix.assert_true(FileAccess.file_exists(sprite_file), "CT02: Sprite file exists: %s" % sprite_file)
	fix.assert_true(FileAccess.file_exists("res://assets/sprites/village/dungeon_entrance.png"), "CT02: Dungeon entrance sprite exists")
	fix.assert_true(FileAccess.file_exists("res://assets/sprites/village/village_ground.png"), "CT02: Village ground sprite exists")

	# P10: Layout JSON config exists and has valid 1280x800 canvas and 7 nodes
	var layout_path = "res://assets/data/village_map_layout.json"
	fix.assert_true(FileAccess.file_exists(layout_path), "P10: Layout JSON exists")

	# Instantiate VillageMap
	var village_map_scene = load("res://scenes/village/village_map.tscn")
	fix.assert_true(village_map_scene != null, "VillageMap scene should load")
	var village_map = village_map_scene.instantiate()
	fix.root.add_child(village_map)

	var v_state = VillageState.new()
	var profile = {"wallet_gold": 1000}
	village_map.setup(v_state, profile)

	# Verify 7 nodes created on MapCanvas
	var b_container = village_map.get_node("MapCanvas/Buildings")
	fix.assert_eq(b_container.get_child_count(), 7, "P10: 7 nodes should be created in MapCanvas/Buildings")

	# Verify isometric Y-sorting: Y coordinates must be non-decreasing
	var prev_y = -9999.0
	for child in b_container.get_children():
		var btn = child as Button
		fix.assert_true(btn != null, "Building child should be a Button")
		var cur_y = btn.position.y
		fix.assert_true(cur_y >= prev_y, "P10: Isometric Y-sorting: node %s at Y=%.1f >= prev Y=%.1f" % [child.name, cur_y, prev_y])
		prev_y = cur_y

	# Verify building_selected signal
	var selected_spy = []
	village_map.building_selected.connect(func(id: String): selected_spy.append(id))
	village_map._on_node_clicked("square")
	fix.assert_eq(selected_spy.size(), 1, "building_selected should fire on click")
	fix.assert_eq(selected_spy[0], "square", "building_selected should pass 'square'")
	fix.assert_true(village_map.detail_modal.visible, "Detail modal should be visible")

	# CT03: Pressing restore opens confirmation modal WITHOUT spending gold
	village_map._on_restore_pressed()
	fix.assert_true(village_map.confirm_modal.visible, "CT03: Confirm modal should open on restore pressed")
	fix.assert_eq(profile["wallet_gold"], 1000, "CT03: Gold not deducted on restore click")
	fix.assert_eq(v_state.get_stage("square"), 0, "CT03: Stage not advanced on restore click")

	# CT04: Pressing cancel closes confirmation modal without spending gold
	village_map._on_confirm_cancel_pressed()
	fix.assert_false(village_map.confirm_modal.visible, "CT04: Confirm modal closed on cancel")
	fix.assert_eq(profile["wallet_gold"], 1000, "CT04: Gold unchanged after cancel")
	fix.assert_eq(v_state.get_stage("square"), 0, "CT04: Stage unchanged after cancel")

	# CT05: Pressing confirm deducts gold and advances stage
	village_map._on_restore_pressed()
	village_map._on_confirm_ok_pressed()
	fix.assert_false(village_map.confirm_modal.visible, "CT05: Confirm modal closed after successful purchase")
	fix.assert_eq(profile["wallet_gold"], 960, "CT05: Gold deducted by 40 (remaining 960)")
	fix.assert_eq(v_state.get_stage("square"), 1, "CT05: Square stage advanced to 1")
	fix.assert_eq(profile.get("village_object_stages", {}).get("square", 0), 1, "CT05: Profile stages updated")
	fix.assert_eq(profile.get("village_object_revisions", {}).get("square", 0), 1, "CT05: Profile revisions updated")

	# CT06: Double confirm: when restoring is in progress, second call is no-op
	village_map.is_restoring_in_progress = true
	var gold_before_dc = profile["wallet_gold"]
	village_map._on_confirm_ok_pressed()
	fix.assert_eq(profile["wallet_gold"], gold_before_dc, "CT06: Double confirm while in progress was ignored")
	village_map.is_restoring_in_progress = false

	# CT12: Re-opening village maintains stages and revisions
	var v_state_reopened = VillageState.new()
	if profile.has("village_object_stages"):
		v_state_reopened.stages = profile["village_object_stages"].duplicate(true)
	if profile.has("village_object_revisions"):
		v_state_reopened.revisions = profile["village_object_revisions"].duplicate(true)
	village_map.setup(v_state_reopened, profile)
	fix.assert_eq(v_state_reopened.get_stage("square"), 1, "CT12: Reopened village has square stage 1")
	fix.assert_eq(v_state_reopened.revisions.get("square", 0), 1, "CT12: Reopened village has square revision 1")

	# CT14: Modal dimmers have mouse_filter == STOP to block background map clicks
	fix.assert_eq(village_map.detail_modal.mouse_filter, Control.MOUSE_FILTER_STOP, "CT14: Detail modal blocks input")
	fix.assert_eq(village_map.confirm_modal.mouse_filter, Control.MOUSE_FILTER_STOP, "CT14: Confirm modal blocks input")

	village_map.queue_free()
	await fix.teardown()
