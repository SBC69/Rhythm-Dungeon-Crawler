class_name TestRunInventory
extends RefCounted

class FailingStore extends SaveStore:
	func save_envelope(_envelope: Dictionary) -> bool:
		return false

static func register_tests(registry: Dictionary) -> void:
	registry["T-RUN-INVENTORY"] = {"fn": Callable(TestRunInventory, "test_inventory_ui"), "desc": "Run inventory opens by mouse or keyboard and equips real loot before the boss"}
	registry["T-INVENTORY-TRANSACTIONS"] = {"fn": Callable(TestRunInventory, "test_inventory_commands"), "desc": "Owned stash equipment, identity, upgrades, persistence, stale input and failed-save rollback"}

static func _item_button(inventory: Control, card: Dictionary, from_stash: bool) -> Button:
	for button in inventory.item_buttons:
		if button.get_meta("instance_id") == str(card.get("instance_id", "")) and button.get_meta("from_stash") == from_stash:
			return button
	return null

static func test_inventory_ui(fix: GameFixture) -> void:
	var main = await fix.create_main()
	var gm = fix.root.get_node("GameManager")
	var cdb = fix.root.get_node("CardDatabase")
	var settings = fix.root.get_node("UserSettings")
	var inventory = main.inventory_panel
	await fix.tree.process_frame
	await fix.tree.process_frame
	await fix.simulate_click(main.hud.inventory_button)
	fix.assert_true(inventory.visible, "HUD button opens the inventory")
	await fix.simulate_key(KEY_I)
	fix.assert_false(inventory.visible, "I closes the inventory")
	await fix.enter_regular_encounter(main)
	fix.assert_true(main.encounter_ctrl.commit_monster_defeat(main.encounter_ctrl.encounter_id), "Prepare a real victory reward")
	var reward: Dictionary = cdb.get_card_for_floor(1, "iron_blade")
	main.encounter_ctrl.pending_loot = [reward]
	main.router.show_loot(gm.current_floor)
	await TestUI._keyboard_focus(fix, main.loot_picker.cards_container.get_child(0))
	await fix.simulate_key(KEY_ENTER)
	await fix.tree.create_timer(0.6).timeout
	fix.assert_true(gm.floor_stash.has(reward), "Chosen loot enters the floor chest")
	var potion: Dictionary = cdb.get_card_data("minor_health_potion")
	gm.floor_stash.append(potion)
	await fix.simulate_key(KEY_I)
	fix.assert_true(inventory.visible, "I opens inventory between rooms")
	for i in range(10):
		await fix.simulate_key(KEY_TAB)
		fix.assert_true(inventory.is_ancestor_of(fix.root.gui_get_focus_owner()), "Inventory traps keyboard focus")
	fix.assert_true(_item_button(inventory, potion, true).disabled, "Stashed consumables clearly remain locked until the boss")
	var old_weapon: Dictionary = gm.equipped_weapon.duplicate(true)
	var attack_before: int = gm.get_combat_stats().attack
	await TestUI._keyboard_focus(fix, _item_button(inventory, reward, true))
	await fix.simulate_key(KEY_ENTER)
	await fix.tree.process_frame
	fix.assert_eq(str(gm.equipped_weapon.instance_id), str(reward.instance_id), "Found gear can be worn before defeating the floor boss")
	fix.assert_eq(gm.floor_stash.size(), 1, "Only the equipped item leaves the chest")
	fix.assert_true(gm.get_combat_stats().attack > attack_before, "New equipment immediately improves live combat stats")
	var previous_returned := false
	for card in gm.hand_cards:
		previous_returned = previous_returned or str(card.instance_id) == str(old_weapon.instance_id)
	fix.assert_true(previous_returned, "Previous equipment returns to the backpack")
	await TestUI._keyboard_focus(fix, inventory.unequip_buttons[cdb.CardType.WEAPON])
	await fix.simulate_key(KEY_ENTER)
	await fix.tree.process_frame
	fix.assert_true(gm.equipped_weapon.is_empty(), "Unequip works from the inventory")
	await fix.simulate_click(_item_button(inventory, reward, false))
	await fix.tree.process_frame
	fix.assert_eq(str(gm.equipped_weapon.instance_id), str(reward.instance_id), "Mouse can re-equip the backpack item")
	await fix.simulate_key(KEY_ESCAPE)
	fix.assert_false(inventory.visible, "Escape closes inventory")
	await fix.teardown()
	main = await fix.create_main()
	inventory = main.inventory_panel
	await fix.enter_regular_encounter(main)
	await fix.simulate_key(KEY_I)
	fix.assert_true(inventory.visible, "Inventory is available before starting a fight")
	await fix.simulate_key(KEY_I)
	main.monster_view._start_rhythm()
	await fix.simulate_key(KEY_I)
	fix.assert_false(inventory.visible, "Inventory cannot cover active rhythm combat")
	fix.assert_false(gm.unequip_inventory_slot(cdb.CardType.WEAPON), "Equipment stays locked during rhythm combat")
	main.monster_view._cancel_rhythm()
	main.router.show_corridor()
	var original_keys: Array = settings.keyboard_events("inventory")
	var original_path: String = settings.config_path
	settings.config_path = "user://inventory-key-test.cfg"
	settings.rebind("inventory", settings.key_event(KEY_B))
	await fix.simulate_key(KEY_I)
	fix.assert_false(inventory.visible, "Old inventory key no longer opens it")
	await fix.simulate_key(KEY_B)
	fix.assert_true(inventory.visible and main.hud.inventory_button.text.contains("B"), "Inventory shortcut is remappable and its hint updates")
	await fix.simulate_key(KEY_B)
	settings._replace_keys("inventory", original_keys)
	settings.config_path = original_path
	settings.changed.emit()
	main.router.show_main_menu()
	await fix.simulate_key(KEY_I)
	fix.assert_false(inventory.visible, "Inventory stays hidden outside the run")
	await fix.teardown()

static func test_inventory_commands(fix: GameFixture) -> void:
	var main = await fix.create_main()
	var gm = fix.root.get_node("GameManager")
	var cdb = fix.root.get_node("CardDatabase")
	var gear: Dictionary = cdb.get_card_for_floor(3, "iron_blade")
	gear.upgrade_level = 2
	var power: int = gear.power
	gm.floor_stash.append(gear)
	var stale: Dictionary = gear.duplicate(true)
	stale.revision = int(stale.revision) - 1
	fix.assert_false(gm.use_inventory_item(stale, true), "Stale stash revision is rejected")
	var spoofed: Dictionary = gear.duplicate(true)
	spoofed.power = 99999
	fix.assert_true(gm.use_inventory_item(spoofed, true), "An owned reward equips through its authoritative identity")
	fix.assert_eq(gm.equipped_weapon.power, power, "UI-supplied stats cannot replace the actual item")
	fix.assert_eq(gm.weapon_upgrade_level, 2, "Upgrades survive chest-to-equipment transfer")
	fix.assert_false(gm.use_inventory_item(gear, true), "The same reward cannot be equipped twice from the chest")
	var armor: Dictionary = cdb.get_card_data("royal_plate")
	gm.floor_stash.append(armor)
	var before: Dictionary = gm.build_active_run()
	var store: SaveStore = gm.save_store
	gm.save_store = FailingStore.new("user://inventory-failing-save")
	fix.assert_false(gm.use_inventory_item(armor, true), "Failed persistence rejects equipment transfer")
	fix.assert_eq(gm.equipped_weapon, before.equipment.weapon, "Save failure preserves the weapon")
	fix.assert_eq(gm.equipped_armor, before.equipment.armor, "Save failure restores the previous armor")
	fix.assert_eq(gm.hand_cards, before.hand, "Save failure restores the backpack without duplicates")
	fix.assert_eq(gm.floor_stash, before.floor_stash, "Save failure restores the chest")
	for child in main.get_children():
		if child is AcceptDialog:
			child.queue_free()
	await fix.tree.process_frame
	fix.assert_false(gm.unequip_inventory_slot(cdb.CardType.WEAPON), "Failed persistence also rejects unequipping")
	fix.assert_eq(gm.equipped_weapon, before.equipment.weapon, "Failed unequip restores the upgraded weapon")
	fix.assert_eq(gm.weapon_upgrade_level, 2, "Failed unequip restores upgrade bonuses")
	gm.save_store = store
	gm.persistence_error = ""
	fix.assert_true(gm.use_inventory_item(armor, true), "The same reward can be equipped after storage recovers")
	var legacy: Dictionary = cdb.get_card_data("lucky_dice_amulet")
	legacy.erase("instance_id")
	legacy.erase("revision")
	legacy.dice_bonus = 4
	gm.floor_stash.append(legacy)
	fix.assert_true(gm.use_inventory_item(legacy, true), "Equipment from old saves without instance IDs can be worn")
	fix.assert_eq(gm.dice_bonus, 4, "Found amulet immediately applies its actual bonus")
	fix.assert_false(str(gm.equipped_amulet.get("instance_id", "")).is_empty(), "Legacy equipment receives a persistent identity")
	fix.assert_false(gm.use_inventory_item(legacy, true), "Legacy rewards cannot be claimed twice")
	var potion: Dictionary = cdb.get_card_data("minor_health_potion")
	gm.floor_stash.append(potion)
	fix.assert_false(gm.use_inventory_item(potion, true), "Stash consumables are not claimed as equipment")
	gm.unlock_floor_stash()
	fix.assert_true(gm.floor_stash.is_empty(), "Boss unlock still empties the remaining chest")
	var copy_count := 0
	for card in gm.hand_cards:
		if str(card.get("instance_id", "")) == str(gear.instance_id):
			copy_count += 1
	fix.assert_eq(copy_count, 0, "Boss unlock does not duplicate worn chest equipment")
	# Inspect the actual run envelope instead of reconstructing a separate model.
	var file := FileAccess.open(store.get_save_path(), FileAccess.READ)
	fix.assert_true(file != null, "Inventory changes have a saved run")
	if file != null:
		var envelope = JSON.parse_string(file.get_as_text())
		fix.assert_eq(envelope.active_run.equipment.weapon.instance_id, gear.instance_id, "Equipped reward persists in the run save")
		fix.assert_eq(envelope.active_run.equipment.armor.instance_id, armor.instance_id, "Armor transfer persists too")
		file.close()
	await fix.teardown()
