# tests/cases/test_inventory.gd
class_name TestInventory
extends RefCounted

static func register_tests(registry: Dictionary) -> void:
	registry["BASE-STARTER"] = {
		"fn": Callable(TestInventory, "test_base_starter"),
		"expected_failure": false,
		"desc": "Baseline starter deck and stats initialization"
	}
	registry["BASE-GOLD"] = {
		"fn": Callable(TestInventory, "test_base_gold"),
		"expected_failure": false,
		"desc": "Baseline gold adding and spending"
	}
	registry["BASE-RESET"] = {
		"fn": Callable(TestInventory, "test_base_reset"),
		"expected_failure": false,
		"desc": "M03: Reset run-only flags, run_generation, and money validation"
	}
	registry["T-C01"] = {
		"fn": Callable(TestInventory, "test_c01_card_identity_loss"),
		"expected_failure": false,
		"desc": "C01: Stack merge or weapon swap loses upgrades / distinct params"
	}
	registry["T-C05"] = {
		"fn": Callable(TestInventory, "test_c05_consumable_without_removal"),
		"expected_failure": false,
		"desc": "C05: Consumable applied even if removal fails or card is absent"
	}

static func test_base_starter(fix: GameFixture) -> void:
	var gm = fix.root.get_node("/root/GameManager")
	fix.reset_game_state()
	fix.assert_eq(gm.player_hp, 50, "Starter HP should be 50")
	fix.assert_eq(gm.player_max_hp, 50, "Starter max HP should be 50")
	fix.assert_eq(gm.player_gold, 40, "Starter gold should be 40")
	fix.assert_eq(gm.base_power, 2, "Starter base power should be 2")
	fix.assert_false(gm.equipped_weapon.is_empty(), "Starter weapon should be equipped")
	fix.assert_false(gm.equipped_armor.is_empty(), "Starter armor should be equipped")
	fix.assert_false(gm.equipped_amulet.is_empty(), "Starter amulet should be equipped")
	fix.assert_true(gm.hand_cards.size() > 0, "Hand cards should contain starter consumables")

static func test_base_gold(fix: GameFixture) -> void:
	var gm = fix.root.get_node("/root/GameManager")
	fix.reset_game_state()
	gm.player_gold = 40
	gm.add_gold(15)
	fix.assert_eq(gm.player_gold, 55, "Gold after adding 15 should be 55")
	var spent = gm.spend_gold(20)
	fix.assert_true(spent, "Spending 20 should succeed")
	fix.assert_eq(gm.player_gold, 35, "Gold after spending 20 should be 35")
	var overspent = gm.spend_gold(100)
	fix.assert_false(overspent, "Spending 100 with 35 gold should fail")
	fix.assert_eq(gm.player_gold, 35, "Gold should remain 35 after failed spend")

static func test_base_reset(fix: GameFixture) -> void:
	var gm = fix.root.get_node("/root/GameManager")
	fix.reset_game_state()
	
	# Negative spend must fail
	var neg_spend = gm.spend_gold(-10)
	fix.assert_false(neg_spend, "Negative spend must fail")
	fix.assert_eq(gm.player_gold, 40, "Gold must not change after negative spend")
	
	# Zero spend is a valid no-op
	var zero_spend = gm.spend_gold(0)
	fix.assert_true(zero_spend, "Zero spend is a successful no-op")
	fix.assert_eq(gm.player_gold, 40, "Gold must remain 40 after zero spend")
	
	# Simulate shop open and game over
	gm.is_shop_open = true
	gm.is_game_over = true
	var gen_before = gm.run_generation
	
	# Call start_new_game
	gm.start_new_game()
	fix.assert_eq(gm.run_generation, gen_before + 1, "run_generation must increment on reset")
	fix.assert_false(gm.is_shop_open, "is_shop_open must be reset to false")
	fix.assert_false(gm.is_game_over, "is_game_over must be reset to false")
	
	# Multiple starts do not duplicate cards
	var starter_count = gm.hand_cards.size()
	gm.start_new_game()
	fix.assert_eq(gm.hand_cards.size(), starter_count, "Starting new game must not duplicate starter cards")

static func test_c01_card_identity_loss(fix: GameFixture) -> void:
	var gm = fix.root.get_node("/root/GameManager")
	var cdb = fix.root.get_node("/root/CardDatabase")
	fix.reset_game_state()
	
	# 1. Upgrade starter weapon
	var initial_power = int(gm.equipped_weapon.get("power", 2))
	var upgraded = gm.upgrade_equipped_weapon()
	fix.assert_true(upgraded, "Weapon upgrade should succeed")
	var upgraded_power = int(gm.equipped_weapon.get("power", 0))
	fix.assert_eq(upgraded_power, initial_power + 2, "Upgraded weapon power should increase by 2")
	var upgraded_inst_id = str(gm.equipped_weapon.get("instance_id", ""))
	
	# Add ordinary copy to hand
	var ordinary = cdb.get_card_data("rusty_sword")
	gm.add_card_to_hand(ordinary)
	var sword_in_hand = gm.hand_cards.back()
	var ordinary_inst_id = str(sword_in_hand.get("instance_id", ""))
	fix.assert_ne(upgraded_inst_id, ordinary_inst_id, "Different instances must have distinct instance_ids")
	
	# Equip ordinary sword - previous upgraded sword is returned to hand
	gm.equip_card_to_slot(sword_in_hand, cdb.CardType.WEAPON)
	
	# Verify returned sword in hand
	var returned_sword: Dictionary = {}
	for c in gm.hand_cards:
		if str(c.get("instance_id", "")) == upgraded_inst_id:
			returned_sword = c
			break
	
	fix.assert_false(returned_sword.is_empty(), "Upgraded sword must be found in hand by instance_id")
	fix.assert_eq(int(returned_sword.get("power", 0)), upgraded_power, "Returned sword should retain upgraded power %d" % upgraded_power)
	fix.assert_eq(int(returned_sword.get("upgrade_level", 0)), 1, "Returned sword should retain upgrade_level 1")
	fix.assert_eq(int(gm.equipped_weapon.get("power", 0)), 2, "Equipped ordinary sword should have power 2")
	
	# Swap back: equip the upgraded sword again
	gm.equip_card_to_slot(returned_sword, cdb.CardType.WEAPON)
	fix.assert_eq(int(gm.equipped_weapon.get("power", 0)), upgraded_power, "Equipped sword after swap back should have power %d" % upgraded_power)
	fix.assert_eq(int(gm.equipped_weapon.get("upgrade_level", 0)), 1, "Equipped sword after swap back should have upgrade_level 1")
	
	# 2. Potions heal 15 and heal 35 must remain separate stacks
	var pot15 = cdb.get_card_data("minor_health_potion")
	pot15["heal"] = 15
	var pot35 = cdb.get_card_data("minor_health_potion")
	pot35["heal"] = 35
	gm.hand_cards.clear()
	gm.add_card_to_hand(pot15)
	gm.add_card_to_hand(pot35)
	fix.assert_eq(gm.hand_cards.size(), 2, "Potions with different heal values (15 vs 35) must remain separate stacks")
	
	# 3. Two identical heal 15 potions must merge into count=2
	var pot15_second = cdb.get_card_data("minor_health_potion")
	pot15_second["heal"] = 15
	gm.add_card_to_hand(pot15_second)
	var found_merged := false
	for c in gm.hand_cards:
		if int(c.get("heal", 0)) == 15 and int(c.get("count", 0)) == 2:
			found_merged = true
	fix.assert_true(found_merged, "Identical potions must merge count to 2")
	
	# 4. Check instance_id uniqueness across hand and slots
	var equipped_ids: Array[String] = [
		str(gm.equipped_weapon.get("instance_id", "")),
		str(gm.equipped_armor.get("instance_id", "")),
		str(gm.equipped_amulet.get("instance_id", ""))
	]
	for c in gm.hand_cards:
		var hand_inst_id = str(c.get("instance_id", ""))
		fix.assert_false(equipped_ids.has(hand_inst_id), "Instance ID %s must not exist in both hand and equipment slots" % hand_inst_id)

static func test_c05_consumable_without_removal(fix: GameFixture) -> void:
	var gm = fix.root.get_node("/root/GameManager")
	var cdb = fix.root.get_node("/root/CardDatabase")
	fix.reset_game_state()
	
	gm.hand_cards.clear()
	gm.temp_combat_power_buff = 0
	var card = cdb.get_card_data("scroll_of_might")
	
	# 1. Playing a card that is NOT in hand must return false and not apply buff
	var accepted = gm.play_card(card)
	fix.assert_false(accepted, "TARGET: play_card should return false when card is not in hand")
	fix.assert_eq(gm.temp_combat_power_buff, 0, "TARGET: Buff should not be applied when card is not in hand")
	
	# 2. Add 1 scroll of might (+3 power) to hand and play it
	gm.add_card_to_hand(card)
	fix.assert_eq(gm.hand_cards.size(), 1, "Hand should have 1 card")
	var hand_card = gm.hand_cards[0]
	var played = gm.play_card(hand_card)
	fix.assert_true(played, "Playing card from hand should return true")
	fix.assert_eq(gm.temp_combat_power_buff, 3, "Buff should be increased by 3")
	fix.assert_eq(gm.hand_cards.size(), 0, "Hand should be empty after playing single card")
	
	# 3. Second call with same card representation must fail
	var played_again = gm.play_card(hand_card)
	fix.assert_false(played_again, "Playing already consumed card must return false")
	fix.assert_eq(gm.temp_combat_power_buff, 3, "Buff must remain 3 without double application")
	
	# 4. Potion at full HP is allowed (D05): consumes potion, returns true, HP remains at 50
	var pot = cdb.get_card_data("minor_health_potion")
	gm.player_hp = 50
	gm.player_max_hp = 50
	gm.add_card_to_hand(pot)
	var pot_card = gm.hand_cards.back()
	var pot_played = gm.play_card(pot_card)
	fix.assert_true(pot_played, "Drinking potion at full HP is allowed")
	fix.assert_eq(gm.player_hp, 50, "HP should remain 50 after drinking potion at full HP")
	fix.assert_eq(gm.hand_cards.size(), 0, "Potion must be consumed from hand")
	
	# 5. Wrong slot equipment (e.g. potion to weapon slot) must be rejected
	var pot2 = cdb.get_card_data("minor_health_potion")
	gm.add_card_to_hand(pot2)
	var equip_wrong = gm.equip_card_to_slot(gm.hand_cards.back(), cdb.CardType.WEAPON)
	fix.assert_false(equip_wrong, "Equipping potion into weapon slot must be rejected")
