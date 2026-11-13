extends Node

signal player_stats_changed
signal room_changed(floor_num: int, room_num: int)
signal inventory_changed
signal gold_changed(new_amount: int)
signal game_over_triggered(victory: bool)

var current_floor: int = 1
var current_room: int = 1
const MAX_ROOMS_PER_FLOOR: int = 10

var run_mode: RunMode.Mode = RunMode.Mode.TIMED_100
var completed_floors: int = 0
var last_opened_floor: int = 1
var terminal_outcome: RunMode.Outcome = RunMode.Outcome.NONE
var starting_run_gold: int = 40
var run_clock: RunClock = RunClock.new()
var save_store: SaveStore = SaveStore.new()
var player_profile: Dictionary = {}
var campaign_equipment: Dictionary = {"weapon": {}, "armor": {}, "amulet": {}}

var player_hp: int = 50
var player_max_hp: int = 50
var player_gold: int = 40
var base_power: int = 2
var floor_power_penalty: int = 0
var temp_combat_power_buff: int = 0
var dice_bonus: int = 0
var extra_rerolls: int = 0
var weapon_upgrade_level: int = 0

var equipped_weapon: Dictionary = {}
var equipped_armor: Dictionary = {}
var equipped_amulet: Dictionary = {}
var hand_cards: Array[Dictionary] = []
var floor_stash: Array[Dictionary] = [] # Won cards stored until floor is completed

var rooms_cleared_total: int = 0
var monsters_slain_total: int = 0
var is_game_over: bool = false
var is_shop_open: bool = false
var run_generation: int = 0
var current_run_id: String = ""
var current_dungeon_id: String = "crypts"
var floor_routes: FloorRoutes = null
var balance_config: BalanceConfig = null
var encounter_controller: EncounterController = null
var entry_profile_snapshot: Dictionary = {}
var restored_controller: Dictionary = {}
var suppress_saves: bool = false
var persistence_error: String = ""
signal save_failed(message: String)

# Current combat / event state
var current_encounter: Dictionary = {}
var current_event_type: String = ""

func _ready() -> void:
	_ensure_gamepad_actions()
	if player_profile.is_empty():
		var envelope = save_store.load_envelope()
		if envelope.has("error"):
			persistence_error = str(envelope.error)
			return
		player_profile = envelope.get("profile", SaveCodec.create_default_profile())
		var active_run = envelope.get("active_run", {})
		if active_run is Dictionary and not active_run.is_empty():
			var mode_str = str(active_run.get("mode", "")).to_upper()
			if mode_str in ["ENDLESS", "MODE.ENDLESS"]:
				resume_endless_run(active_run)
				return
	start_new_game()

## Keep keyboard defaults and explicitly support the PC gamepad navigation contract.
func _ensure_gamepad_actions() -> void:
	var buttons = {"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B, "ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN, "ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT}
	for action in buttons:
		var event = InputEventJoypadButton.new()
		event.device = -1
		event.button_index = buttons[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
	for binding in [["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0], ["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0]]:
		var event = InputEventJoypadMotion.new()
		event.device = -1
		event.axis = binding[1]
		event.axis_value = binding[2]
		if not InputMap.action_has_event(binding[0], event):
			InputMap.action_add_event(binding[0], event)

func resume_endless_run(active_run: Dictionary) -> void:
	var decoded = FloorRoutes.from_snapshot(active_run.get("floor_state", {}))
	if not decoded.get("success", false):
		persistence_error = str(decoded.get("error", "Invalid floor state"))
		save_failed.emit(persistence_error)
		return
	run_mode = RunMode.Mode.ENDLESS
	run_generation += 1
	current_run_id = str(active_run.get("run_id", "run_%d_%d" % [Time.get_ticks_msec(), run_generation]))
	current_dungeon_id = str(active_run.get("dungeon_id", "crypts"))
	current_floor = int(active_run.get("floor", 1))
	current_room = int(active_run.get("room", 1))
	completed_floors = int(active_run.get("completed_floors", current_floor - 1))
	last_opened_floor = maxi(current_floor, int(active_run.get("last_opened_floor", current_floor)))
	terminal_outcome = RunMode.Outcome.NONE
	floor_power_penalty = int(active_run.get("floor_power_penalty", 0))
	run_clock = RunClock.new()
	run_clock.start()

	balance_config = BalanceConfig.new()
	balance_config.load_from_file()

	player_max_hp = int(active_run.get("max_hp", balance_config.get_hero_max_hp()))
	player_hp = int(active_run.get("hp", player_max_hp))
	player_gold = int(active_run.get("gold", 40))
	starting_run_gold = int(active_run.get("starting_gold", player_gold))
	base_power = balance_config.get_hero_base_power()
	temp_combat_power_buff = int(active_run.get("temp_combat_power_buff", 0))
	dice_bonus = 0
	extra_rerolls = 0
	weapon_upgrade_level = 0
	rooms_cleared_total = int(active_run.get("rooms_cleared_total", 0))
	monsters_slain_total = int(active_run.get("monsters_slain_total", 0))
	is_game_over = false
	is_shop_open = false
	floor_routes = decoded["state"]
	balance_config.config_data = floor_routes.balance_snapshot.duplicate(true)
	restored_controller = active_run.get("controller", {}).duplicate(true)
	current_encounter.clear()
	current_event_type = ""
	floor_stash.clear()
	equipped_weapon.clear()
	equipped_armor.clear()
	equipped_amulet.clear()
	hand_cards.clear()

	var eq = active_run.get("equipment", {})
	if eq is Dictionary:
		if eq.has("weapon") and eq["weapon"] is Dictionary:
			equipped_weapon = eq["weapon"].duplicate(true)
			weapon_upgrade_level = int(equipped_weapon.get("upgrade_level", 0))
		if eq.has("armor") and eq["armor"] is Dictionary:
			equipped_armor = eq["armor"].duplicate(true)
		if eq.has("amulet") and eq["amulet"] is Dictionary:
			equipped_amulet = eq["amulet"].duplicate(true)
			dice_bonus = int(equipped_amulet.get("dice_bonus", 0))
			extra_rerolls = int(equipped_amulet.get("extra_reroll", 0))

	if active_run.has("hand") and active_run["hand"] is Array:
		for c in active_run["hand"]:
			if c is Dictionary:
				hand_cards.append(c.duplicate(true))

	if active_run.has("floor_stash") and active_run["floor_stash"] is Array:
		for c in active_run["floor_stash"]:
			if c is Dictionary:
				floor_stash.append(c.duplicate(true))

	entry_profile_snapshot = active_run.get("entry_profile_snapshot", player_profile).duplicate(true)
	player_profile["active_endless_run"] = true

	emit_signal("player_stats_changed")
	emit_signal("inventory_changed")
	emit_signal("gold_changed", player_gold)
	emit_signal("room_changed", current_floor, current_room)

func _save_active_run() -> bool:
	if suppress_saves:
		return true
	if terminal_outcome != RunMode.Outcome.NONE or is_game_over:
		return true
	if save_store == null:
		return false
	return save_store.save_envelope(SaveCodec.encode_envelope(player_profile, build_active_run()))

func build_active_run() -> Dictionary:
	var active_run = {
		"mode": RunMode.mode_to_string(run_mode),
		"floor": current_floor,
		"room": current_room,
		"hp": player_hp,
		"max_hp": player_max_hp,
		"gold": player_gold,
		"run_id": current_run_id,
		"dungeon_id": current_dungeon_id,
		"equipment": {
			"weapon": equipped_weapon.duplicate(true),
			"armor": equipped_armor.duplicate(true),
			"amulet": equipped_amulet.duplicate(true)
		},
		"hand": hand_cards.duplicate(true),
		"floor_stash": floor_stash.duplicate(true),
		"entry_profile_snapshot": entry_profile_snapshot.duplicate(true),
		"terminal_outcome": RunMode.outcome_to_string(terminal_outcome)
	}
	if floor_routes != null:
		active_run["floor_state"] = floor_routes.serialize()
	active_run["starting_gold"] = starting_run_gold
	active_run["floor_power_penalty"] = floor_power_penalty
	active_run["temp_combat_power_buff"] = temp_combat_power_buff
	active_run["completed_floors"] = completed_floors
	active_run["last_opened_floor"] = last_opened_floor
	active_run["rooms_cleared_total"] = rooms_cleared_total
	active_run["monsters_slain_total"] = monsters_slain_total
	var state = encounter_controller.snapshot() if encounter_controller != null else restored_controller
	if state.is_empty():
		state = {"phase": "CORRIDOR"}
	active_run["controller"] = state.duplicate(true)
	active_run["phase"] = state.get("phase", "CORRIDOR")
	return active_run

## Capture before a room command. Nested inventory operations must not save half a command.
func begin_run_command() -> Dictionary:
	var before = build_active_run()
	before["signals_were_blocked"] = is_blocking_signals()
	set_block_signals(true)
	suppress_saves = true
	return before

func finish_run_command(before: Dictionary) -> bool:
	suppress_saves = false
	if _save_active_run():
		set_block_signals(bool(before.get("signals_were_blocked", false)))
		persistence_error = ""
		player_stats_changed.emit()
		inventory_changed.emit()
		gold_changed.emit(player_gold)
		room_changed.emit(current_floor, current_room)
		return true
	return cancel_run_command(before, true)

func cancel_run_command(before: Dictionary, report_error: bool = false) -> bool:
	suppress_saves = false
	# Restore all fields changed by room commands; the previous disk snapshot is untouched.
	for pair in [["floor", "current_floor"], ["room", "current_room"], ["gold", "player_gold"], ["hp", "player_hp"], ["completed_floors", "completed_floors"], ["last_opened_floor", "last_opened_floor"], ["floor_power_penalty", "floor_power_penalty"], ["temp_combat_power_buff", "temp_combat_power_buff"], ["rooms_cleared_total", "rooms_cleared_total"], ["monsters_slain_total", "monsters_slain_total"]]:
		set(pair[1], before.get(pair[0], get(pair[1])))
	floor_routes = FloorRoutes.from_snapshot(before["floor_state"])["state"]
	hand_cards.assign(before["hand"])
	floor_stash.assign(before["floor_stash"])
	var equipment: Dictionary = before.get("equipment", {})
	equipped_weapon = equipment.get("weapon", {}).duplicate(true)
	equipped_armor = equipment.get("armor", {}).duplicate(true)
	equipped_amulet = equipment.get("amulet", {}).duplicate(true)
	weapon_upgrade_level = int(equipped_weapon.get("upgrade_level", 0))
	dice_bonus = int(equipped_amulet.get("dice_bonus", 0))
	extra_rerolls = int(equipped_amulet.get("extra_reroll", 0))
	if encounter_controller != null:
		encounter_controller.restore(before["controller"])
	set_block_signals(bool(before.get("signals_were_blocked", false)))
	if report_error:
		persistence_error = "UI_SAVE_FAILED"
		save_failed.emit(persistence_error)
	return false

func get_current_dungeon_index() -> int:
	var d_order = ["crypts", "ash_forges", "drowned_temple", "crystal_mines", "abyss_rift"]
	if balance_config != null:
		d_order = balance_config.get_dungeon_order()
	var idx = d_order.find(current_dungeon_id)
	return (idx + 1) if idx >= 0 else 1

func _create_floor_routes_for_current_floor() -> void:
	var ctx = {
		"run_id": current_run_id,
		"mode": RunMode.mode_to_string(run_mode),
		"dungeon_id": current_dungeon_id,
		"dungeon_index": get_current_dungeon_index(),
		"final_boss_defeated": current_dungeon_id in player_profile.get("defeated_final_boss_ids", []),
		"floor_number": current_floor
	}
	var snap = balance_config.config_data if balance_config != null else {}
	floor_routes = FloorRoutes.create(ctx, snap)

func start_new_game(mode: RunMode.Mode = RunMode.Mode.TIMED_100, dungeon_id: String = "crypts") -> void:
	if run_mode == RunMode.Mode.ENDLESS and player_profile.get("active_endless_run", false) and terminal_outcome == RunMode.Outcome.NONE and not is_game_over and player_hp > 0:
		return

	entry_profile_snapshot = player_profile.duplicate(true)
	suppress_saves = true
	restored_controller = {}
	if encounter_controller != null:
		encounter_controller.restore({})
	run_mode = mode
	current_dungeon_id = dungeon_id
	run_generation += 1
	current_run_id = "run_%d_%d" % [Time.get_ticks_msec(), run_generation]
	current_floor = 1
	current_room = 1
	completed_floors = 0
	last_opened_floor = 1
	terminal_outcome = RunMode.Outcome.NONE
	player_profile.erase("pending_result")
	floor_power_penalty = 0
	run_clock = RunClock.new()
	run_clock.start()

	balance_config = BalanceConfig.new()
	balance_config.load_from_file()

	player_max_hp = balance_config.get_hero_max_hp()
	player_hp = player_max_hp
	starting_run_gold = int(player_profile.get("wallet_gold", balance_config.get_hero_starting_gold()))
	player_gold = starting_run_gold
	base_power = balance_config.get_hero_base_power()
	temp_combat_power_buff = 0
	dice_bonus = 0
	extra_rerolls = 0
	weapon_upgrade_level = 0
	rooms_cleared_total = 0
	monsters_slain_total = 0
	is_game_over = false
	is_shop_open = false
	_create_floor_routes_for_current_floor()
	current_encounter.clear()
	current_event_type = ""
	floor_stash.clear()
	equipped_weapon.clear()
	equipped_armor.clear()
	equipped_amulet.clear()
	hand_cards.clear()

	# Check if campaign equipment was transferred from a previous victory
	var camp_eq = player_profile.get("campaign_equipment", {})
	if not camp_eq.get("weapon", {}).is_empty():
		equipped_weapon = camp_eq["weapon"].duplicate(true)
		weapon_upgrade_level = int(equipped_weapon.get("upgrade_level", 0))
	if not camp_eq.get("armor", {}).is_empty():
		equipped_armor = camp_eq["armor"].duplicate(true)
	if not camp_eq.get("amulet", {}).is_empty():
		equipped_amulet = camp_eq["amulet"].duplicate(true)
		dice_bonus = int(equipped_amulet.get("dice_bonus", 0))
		extra_rerolls = int(equipped_amulet.get("extra_reroll", 0))
	if player_profile.has("campaign_equipment"):
		player_profile["campaign_equipment"] = {"weapon": {}, "armor": {}, "amulet": {}}

	# Starter tier offset for deeper dungeons (e.g. D2 ash_forges Q_entry = 100)
	var d_order = ["crypts", "ash_forges", "drowned_temple", "crystal_mines", "abyss_rift"]
	if balance_config != null:
		d_order = balance_config.get_dungeon_order()
	var d_index = d_order.find(current_dungeon_id)
	if d_index < 0:
		d_index = 0
	var q_entry = d_index * int(balance_config.config_data.modes.timed.depth_stride)

	# Generate starter deck
	var starter = CardDatabase.get_random_starter_deck()
	for card in starter:
		if card.type == CardDatabase.CardType.WEAPON and equipped_weapon.is_empty():
			equipped_weapon = card
			equipped_weapon["power"] = int(equipped_weapon.get("power", 2)) + q_entry
		elif card.type == CardDatabase.CardType.ARMOR and equipped_armor.is_empty():
			equipped_armor = card
			equipped_armor["power"] = int(equipped_armor.get("power", 1)) + q_entry
		elif card.type == CardDatabase.CardType.AMULET and equipped_amulet.is_empty():
			equipped_amulet = card
			dice_bonus = int(card.get("dice_bonus", 0))
			extra_rerolls = int(card.get("extra_reroll", 0))
		else:
			add_card_to_hand(card)

	if run_mode == RunMode.Mode.ENDLESS:
		player_profile["active_endless_run"] = true

	suppress_saves = false
	_save_active_run()

	emit_signal("player_stats_changed")
	emit_signal("inventory_changed")
	emit_signal("gold_changed", player_gold)
	emit_signal("room_changed", current_floor, current_room)

func settle_current_run(outcome: RunMode.Outcome, final_boss_bonus: int = 0) -> Dictionary:
	if terminal_outcome != RunMode.Outcome.NONE:
		return {}
	if outcome == RunMode.Outcome.NONE:
		return {}
	if run_mode == RunMode.Mode.ENDLESS and outcome == RunMode.Outcome.SUCCESS:
		return {}

	terminal_outcome = outcome
	run_clock.freeze()
	player_profile["active_endless_run"] = false

	var settlement = ProfileRules.settle_run(starting_run_gold, player_gold, outcome, final_boss_bonus)
	player_profile["wallet_gold"] = settlement["settled_gold"]
	player_profile["has_returned_from_dungeon"] = true

	if outcome == RunMode.Outcome.SUCCESS:
		player_profile["pending_result"] = true
		player_profile["campaign_equipment"] = CampaignEquipmentRules.record_victory_equipment(equipped_weapon, equipped_armor, equipped_amulet)
	else:
		player_profile["campaign_equipment"] = CampaignEquipmentRules.clear_equipment()

	# Update best records
	if not player_profile.has("best_records"):
		player_profile["best_records"] = {"timed": {}, "endless": {}}
	if run_mode == RunMode.Mode.ENDLESS:
		var cur_best = int(player_profile["best_records"].get("endless", {}).get("completed_floors", -1))
		if completed_floors >= cur_best:
			player_profile["best_records"]["endless"] = {
				"completed_floors": completed_floors,
				"outcome": RunMode.outcome_to_string(outcome),
				"timestamp": Time.get_unix_time_from_system()
			}
	else:
		var timed_record: Dictionary = player_profile["best_records"].get("timed", {})
		var cur_best_floors = int(timed_record.get("completed_floors", -1))
		var cur_best_time = int(timed_record.get("elapsed_msec", 999999999))
		var this_time = run_clock.get_elapsed_msec()
		var should_update = false
		if completed_floors > cur_best_floors:
			should_update = true
		elif completed_floors == cur_best_floors:
			if outcome == RunMode.Outcome.SUCCESS:
				should_update = (this_time <= cur_best_time)
			else:
				should_update = false
		if should_update:
			player_profile["best_records"]["timed"] = {
				"completed_floors": completed_floors,
				"outcome": RunMode.outcome_to_string(outcome),
				"elapsed_msec": this_time
			}

	# Record to history
	var run_record = {
		"run_id": current_run_id,
		"mode": RunMode.mode_to_string(run_mode),
		"dungeon_id": current_dungeon_id,
		"outcome": RunMode.outcome_to_string(outcome),
		"starting_gold": starting_run_gold,
		"settled_gold": settlement["settled_gold"],
		"completed_floors": completed_floors,
		"last_opened_floor": last_opened_floor,
		"elapsed_msec": run_clock.get_elapsed_msec()
	}
	var cur_history = player_profile.get("run_history", [])
	player_profile["run_history"] = ChronicleRules.add_run_record(cur_history, run_record)

	# Evaluate memories
	var evt = {
		"completed_floors": completed_floors,
		"outcome": RunMode.outcome_to_string(outcome),
		"is_next_dungeon": false
	}
	player_profile["memory_unlocks"] = ChronicleRules.evaluate_memory_unlocks(player_profile, evt)

	# Save envelope
	var envelope = SaveCodec.encode_envelope(player_profile, {})
	save_store.save_envelope(envelope)

	return settlement

func get_total_player_power() -> int:
	var effective_base = maxi(1, base_power - floor_power_penalty)
	var total = effective_base
	if not equipped_weapon.is_empty():
		total += int(equipped_weapon.get("power", 0))
	if not equipped_armor.is_empty():
		total += int(equipped_armor.get("power", 0))
	if not equipped_amulet.is_empty():
		total += int(equipped_amulet.get("power", 0))
	total += temp_combat_power_buff
	return total

func get_combat_stats() -> Dictionary:
	# Derived from live gear so upgrades, consumables and old saved items stay in sync.
	var effective_base := maxi(1, base_power - floor_power_penalty)
	var attack := effective_base + int(equipped_weapon.get("power", 0)) + int(equipped_amulet.get("power", 0)) + temp_combat_power_buff
	var defense := effective_base + int(equipped_armor.get("power", 0))
	return {"attack": maxi(1, attack), "defense": maxi(1, defense)}

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	player_gold += amount
	emit_signal("gold_changed", player_gold)
	_save_active_run()

func spend_gold(amount: int) -> bool:
	if amount < 0:
		return false
	if amount == 0:
		return true
	if player_gold >= amount:
		player_gold -= amount
		emit_signal("gold_changed", player_gold)
		_save_active_run()
		return true
	return false

func get_weapon_upgrade_cost() -> int:
	return 40 + weapon_upgrade_level * 30

func upgrade_equipped_weapon() -> bool:
	if equipped_weapon.is_empty():
		return false
	var cur_u = int(equipped_weapon.get("upgrade_level", weapon_upgrade_level))
	if cur_u >= 5:
		return false
	var cost = get_weapon_upgrade_cost()
	if spend_gold(cost):
		cur_u += 1
		equipped_weapon["upgrade_level"] = cur_u
		weapon_upgrade_level = cur_u
		var forge_stage = int(player_profile.get("village_object_stages", {}).get("forge", 0))
		var gain = 2 + forge_stage
		if balance_config != null:
			gain = balance_config.get_forge_power_gain(forge_stage)
		equipped_weapon["power"] = int(equipped_weapon.get("power", 2)) + gain
		if not equipped_weapon.has("base_name"):
			equipped_weapon["base_name"] = equipped_weapon.get("name", tr("Sword"))
		equipped_weapon["name"] = "%s +%d" % [equipped_weapon["base_name"], cur_u]
		equipped_weapon["description"] = tr("+%d hero power (Forge level %d)") % [equipped_weapon["power"], cur_u]
		CardIdentity.increment_revision(equipped_weapon)
		SoundManager.play_anvil()
		emit_signal("player_stats_changed")
		emit_signal("inventory_changed")
		_save_active_run()
		return true
	return false

func _remove_card_from_hand_silent(card: Dictionary) -> bool:
	var target_inst_id = str(card.get("instance_id", ""))
	var target_def_id = str(card.get("id", ""))
	for i in range(hand_cards.size()):
		var existing = hand_cards[i]
		var match_found = false
		if not target_inst_id.is_empty() and existing.has("instance_id"):
			match_found = (str(existing.get("instance_id", "")) == target_inst_id)
		else:
			match_found = (str(existing.get("id", "")) == target_def_id)
		if match_found:
			var current_count = int(existing.get("count", 1))
			if current_count > 1:
				existing["count"] = current_count - 1
				CardIdentity.increment_revision(existing)
			else:
				hand_cards.remove_at(i)
			return true
	return false

func _add_card_to_hand_silent(card: Dictionary) -> void:
	var inst = CardIdentity.create_instance(card)
	var count_to_add = maxi(1, int(inst.get("count", 1)))
	for existing in hand_cards:
		if CardIdentity.can_merge(existing, inst):
			existing["count"] = int(existing.get("count", 1)) + count_to_add
			CardIdentity.increment_revision(existing)
			return
	var new_card = inst.duplicate(true)
	new_card["count"] = count_to_add
	CardIdentity.increment_revision(new_card)
	hand_cards.append(new_card)

func add_card_to_hand(card: Dictionary) -> void:
	_add_card_to_hand_silent(card)
	emit_signal("inventory_changed")
	_save_active_run()

func remove_card_from_hand(card: Dictionary) -> bool:
	if _remove_card_from_hand_silent(card):
		emit_signal("inventory_changed")
		_save_active_run()
		return true
	return false

func sell_card(card: Dictionary) -> bool:
	var target_inst_id = str(card.get("instance_id", ""))
	var target_def_id = str(card.get("id", ""))
	var live_card: Dictionary = {}
	for c in hand_cards:
		if not target_inst_id.is_empty() and c.has("instance_id"):
			if str(c.get("instance_id", "")) == target_inst_id:
				live_card = c
				break
		elif str(c.get("id", "")) == target_def_id:
			live_card = c
			break

	if live_card.is_empty():
		return false

	if card.has("revision") and live_card.has("revision"):
		if int(card.get("revision", 0)) != int(live_card.get("revision", 0)):
			return false

	var card_id = str(live_card.get("id", ""))
	var authoritative_card = CardDatabase.get_card_data(card_id)
	var authoritative_value = 15
	if not authoritative_card.is_empty():
		authoritative_value = int(authoritative_card.get("sell_value", 15))
	else:
		match int(live_card.get("rarity", CardDatabase.Rarity.COMMON)):
			CardDatabase.Rarity.COMMON: authoritative_value = 15
			CardDatabase.Rarity.UNCOMMON: authoritative_value = 30
			CardDatabase.Rarity.RARE: authoritative_value = 60
			CardDatabase.Rarity.LEGENDARY: authoritative_value = 120
			_: authoritative_value = 15

	if remove_card_from_hand(live_card):
		add_gold(authoritative_value)
		SoundManager.play_coin()
		return true
	return false

func can_use_inventory() -> bool:
	return not is_game_over and not is_shop_open and terminal_outcome == RunMode.Outcome.NONE and encounter_controller != null and encounter_controller.can_interact_with_cards()

func use_inventory_item(card: Dictionary, from_stash: bool = false) -> bool:
	if not can_use_inventory():
		return false
	if not from_stash:
		var before = begin_run_command()
		if not play_card(card):
			return cancel_run_command(before)
		return finish_run_command(before)

	# Look up the owned reward; never trust the stats sent by its UI row.
	var index := -1
	var instance_id := str(card.get("instance_id", ""))
	if not instance_id.is_empty():
		for i in range(floor_stash.size()):
			if str(floor_stash[i].get("instance_id", "")) == instance_id:
				index = i
				break
	else:
		# Old saves can contain reward definitions without instance IDs.
		index = floor_stash.find(card)
	if index < 0:
		return false
	var model: Dictionary = floor_stash[index]
	var slot_type := int(model.get("type", -1))
	if not CardIdentity.is_equipment_type(slot_type):
		return false
	if card.has("revision") and model.has("revision") and int(card.revision) != int(model.revision):
		return false
	var before = begin_run_command()
	var item := CardIdentity.create_instance(model)
	floor_stash.remove_at(index)
	_add_card_to_hand_silent(item)
	var added: Dictionary = {}
	for owned in hand_cards:
		if str(owned.get("instance_id", "")) == str(item.instance_id):
			added = owned
			break
	if added.is_empty() or not equip_card_to_slot(added, slot_type):
		return cancel_run_command(before)
	return finish_run_command(before)

func unequip_inventory_slot(slot_type: int) -> bool:
	if not can_use_inventory():
		return false
	var before = begin_run_command()
	if not unequip_slot(slot_type):
		return cancel_run_command(before)
	return finish_run_command(before)

func equip_card_to_slot(card: Dictionary, slot_type: int) -> bool:
	if encounter_controller != null and encounter_controller.combat_input_locked:
		return false
	# Authoritative lookup in hand
	var target_inst_id = str(card.get("instance_id", ""))
	var target_def_id = str(card.get("id", ""))
	var model_card: Dictionary = {}
	for c in hand_cards:
		if not target_inst_id.is_empty() and c.has("instance_id"):
			if str(c.get("instance_id", "")) == target_inst_id:
				model_card = c
				break
		elif str(c.get("id", "")) == target_def_id:
			model_card = c
			break
	
	if model_card.is_empty():
		return false

	# If revision was provided, check for stale revision
	if card.has("revision") and model_card.has("revision"):
		if int(card.get("revision", 0)) != int(model_card.get("revision", 0)):
			return false
	
	# Verify that card type matches the destination slot
	var card_type = int(model_card.get("type", -1))
	if card_type != slot_type:
		return false
	
	match slot_type:
		CardDatabase.CardType.WEAPON:
			var old_eq = equipped_weapon.duplicate(true)
			if not old_eq.is_empty():
				old_eq["upgrade_level"] = weapon_upgrade_level
			if not _remove_card_from_hand_silent(model_card):
				return false
			if not old_eq.is_empty():
				_add_card_to_hand_silent(old_eq)
			var new_weapon = CardIdentity.create_instance(model_card)
			new_weapon["count"] = 1
			equipped_weapon = new_weapon
			weapon_upgrade_level = int(equipped_weapon.get("upgrade_level", 0))
			CardIdentity.increment_revision(equipped_weapon)
			SoundManager.play_card_play()
			emit_signal("player_stats_changed")
			emit_signal("inventory_changed")
			if terminal_outcome == RunMode.Outcome.SUCCESS:
				player_profile["campaign_equipment"] = CampaignEquipmentRules.record_victory_equipment(equipped_weapon, equipped_armor, equipped_amulet)
				save_store.save_envelope(SaveCodec.encode_envelope(player_profile, {}))
			else:
				_save_active_run()
			return true
		CardDatabase.CardType.ARMOR:
			var old_eq = equipped_armor.duplicate(true)
			if not _remove_card_from_hand_silent(model_card):
				return false
			if not old_eq.is_empty():
				_add_card_to_hand_silent(old_eq)
			var new_armor = CardIdentity.create_instance(model_card)
			new_armor["count"] = 1
			equipped_armor = new_armor
			CardIdentity.increment_revision(equipped_armor)
			SoundManager.play_card_play()
			emit_signal("player_stats_changed")
			emit_signal("inventory_changed")
			if terminal_outcome == RunMode.Outcome.SUCCESS:
				player_profile["campaign_equipment"] = CampaignEquipmentRules.record_victory_equipment(equipped_weapon, equipped_armor, equipped_amulet)
				save_store.save_envelope(SaveCodec.encode_envelope(player_profile, {}))
			else:
				_save_active_run()
			return true
		CardDatabase.CardType.AMULET:
			var old_eq = equipped_amulet.duplicate(true)
			if not _remove_card_from_hand_silent(model_card):
				return false
			if not old_eq.is_empty():
				_add_card_to_hand_silent(old_eq)
			var new_amulet = CardIdentity.create_instance(model_card)
			new_amulet["count"] = 1
			equipped_amulet = new_amulet
			dice_bonus = int(equipped_amulet.get("dice_bonus", 0))
			extra_rerolls = int(equipped_amulet.get("extra_reroll", 0))
			CardIdentity.increment_revision(equipped_amulet)
			SoundManager.play_magic()
			emit_signal("player_stats_changed")
			emit_signal("inventory_changed")
			if terminal_outcome == RunMode.Outcome.SUCCESS:
				player_profile["campaign_equipment"] = CampaignEquipmentRules.record_victory_equipment(equipped_weapon, equipped_armor, equipped_amulet)
				save_store.save_envelope(SaveCodec.encode_envelope(player_profile, {}))
			else:
				_save_active_run()
			return true
	return false

func unequip_slot(slot_type: int) -> bool:
	if encounter_controller != null and encounter_controller.combat_input_locked:
		return false
	match slot_type:
		CardDatabase.CardType.WEAPON:
			if not equipped_weapon.is_empty():
				var old_w = equipped_weapon.duplicate(true)
				old_w["upgrade_level"] = weapon_upgrade_level
				equipped_weapon.clear()
				weapon_upgrade_level = 0
				_add_card_to_hand_silent(old_w)
				emit_signal("player_stats_changed")
				emit_signal("inventory_changed")
				if terminal_outcome == RunMode.Outcome.SUCCESS:
					player_profile["campaign_equipment"] = CampaignEquipmentRules.record_victory_equipment(equipped_weapon, equipped_armor, equipped_amulet)
					save_store.save_envelope(SaveCodec.encode_envelope(player_profile, {}))
				else:
					_save_active_run()
				return true
		CardDatabase.CardType.ARMOR:
			if not equipped_armor.is_empty():
				var old_a = equipped_armor.duplicate(true)
				equipped_armor.clear()
				_add_card_to_hand_silent(old_a)
				emit_signal("player_stats_changed")
				emit_signal("inventory_changed")
				if terminal_outcome == RunMode.Outcome.SUCCESS:
					player_profile["campaign_equipment"] = CampaignEquipmentRules.record_victory_equipment(equipped_weapon, equipped_armor, equipped_amulet)
					save_store.save_envelope(SaveCodec.encode_envelope(player_profile, {}))
				else:
					_save_active_run()
				return true
		CardDatabase.CardType.AMULET:
			if not equipped_amulet.is_empty():
				var old_am = equipped_amulet.duplicate(true)
				equipped_amulet.clear()
				dice_bonus = 0
				extra_rerolls = 0
				_add_card_to_hand_silent(old_am)
				emit_signal("player_stats_changed")
				emit_signal("inventory_changed")
				if terminal_outcome == RunMode.Outcome.SUCCESS:
					player_profile["campaign_equipment"] = CampaignEquipmentRules.record_victory_equipment(equipped_weapon, equipped_armor, equipped_amulet)
					save_store.save_envelope(SaveCodec.encode_envelope(player_profile, {}))
				else:
					_save_active_run()
				return true
	return false

func play_card(card: Dictionary) -> bool:
	if is_shop_open:
		return false
	if encounter_controller != null and not encounter_controller.can_interact_with_cards():
		return false

	var target_inst_id = str(card.get("instance_id", ""))
	var target_def_id = str(card.get("id", ""))
	
	# Find authoritative card in hand
	var card_index = -1
	var model_card: Dictionary = {}
	for i in range(hand_cards.size()):
		var c = hand_cards[i]
		if not target_inst_id.is_empty() and c.has("instance_id"):
			if str(c.get("instance_id", "")) == target_inst_id:
				card_index = i
				model_card = c
				break
		elif str(c.get("id", "")) == target_def_id:
			card_index = i
			model_card = c
			break
			
	if card_index == -1 or model_card.is_empty():
		return false
		
	# If revision was provided, check for stale revision
	if card.has("revision") and model_card.has("revision"):
		if int(card.get("revision", 0)) != int(model_card.get("revision", 0)):
			return false
			
	var card_type = int(model_card.get("type", CardDatabase.CardType.BUFF))
	match card_type:
		CardDatabase.CardType.WEAPON:
			return equip_card_to_slot(model_card, CardDatabase.CardType.WEAPON)
		CardDatabase.CardType.ARMOR:
			return equip_card_to_slot(model_card, CardDatabase.CardType.ARMOR)
		CardDatabase.CardType.AMULET:
			return equip_card_to_slot(model_card, CardDatabase.CardType.AMULET)
		CardDatabase.CardType.POTION:
			var heal_val = int(model_card.get("heal", 15))
			if not remove_card_from_hand(model_card):
				return false
			heal_player(heal_val)
			return true
		CardDatabase.CardType.BUFF:
			var buff_val = int(model_card.get("power_buff", 3))
			if not remove_card_from_hand(model_card):
				return false
			temp_combat_power_buff += buff_val
			SoundManager.play_magic()
			emit_signal("player_stats_changed")
			return true
			
	return false

func damage_player(amount: int) -> Dictionary:
	var reduction = 0
	if not equipped_armor.is_empty():
		reduction = int(equipped_armor.get("damage_reduction", 0))
	var dmg = CombatRules.calculate_damage(amount, reduction, player_hp)
	player_hp = dmg["remaining_hp"]
	SoundManager.play_damage()
	emit_signal("player_stats_changed")
	_save_active_run()
	if dmg["is_lethal"]:
		is_game_over = true
		emit_signal("game_over_triggered", false)
	return dmg

func apply_curse_effect(raw_damage: int, power_drain: int) -> Dictionary:
	var reduction = 0
	if not equipped_armor.is_empty():
		reduction = int(equipped_armor.get("damage_reduction", 0))
	var dmg = CombatRules.calculate_damage(raw_damage, reduction, player_hp)
	player_hp = dmg["remaining_hp"]
	floor_power_penalty += power_drain
	SoundManager.play_damage()
	emit_signal("player_stats_changed")
	_save_active_run()
	if dmg["is_lethal"]:
		is_game_over = true
		emit_signal("game_over_triggered", false)
	return dmg

func heal_player(amount: int) -> void:
	player_hp = mini(player_max_hp, player_hp + amount)
	SoundManager.play_heal()
	emit_signal("player_stats_changed")
	_save_active_run()

func add_to_floor_stash(card: Dictionary) -> void:
	floor_stash.append(card)
	emit_signal("inventory_changed")

func unlock_floor_stash() -> void:
	var pending = floor_stash.duplicate(true)
	floor_stash.clear()
	var prior = suppress_saves
	suppress_saves = true
	for card in pending:
		add_card_to_hand(card)
	suppress_saves = prior
	_save_active_run()
	emit_signal("inventory_changed")

func reset_combat_buffs() -> void:
	temp_combat_power_buff = 0
	emit_signal("player_stats_changed")

func advance_room() -> void:
	rooms_cleared_total += 1
	reset_combat_buffs()
	if current_room < MAX_ROOMS_PER_FLOOR:
		current_room += 1
		emit_signal("room_changed", current_floor, current_room)

func advance_to_next_floor() -> bool:
	var before = begin_run_command()
	current_floor += 1
	current_room = 1
	last_opened_floor = maxi(last_opened_floor, current_floor)
	reset_combat_buffs()
	floor_power_penalty = 0
	_create_floor_routes_for_current_floor()
	if encounter_controller != null:
		encounter_controller.restore({})
	if not finish_run_command(before):
		return false
	emit_signal("player_stats_changed")
	emit_signal("room_changed", current_floor, current_room)
	return true
