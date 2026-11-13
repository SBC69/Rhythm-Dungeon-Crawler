extends Control

@onready var dungeon_view = $DungeonView
@onready var hud = $HUD
@onready var hand_ui = $HandUI
@onready var monster_view = $MonsterView
@onready var dice_escape = $DiceEscape
@onready var curse_event = $CurseEvent
@onready var loot_picker = $LootPicker
@onready var rest_room = $RestRoom
@onready var merchant_sell_modal = $MerchantSellModal
@onready var game_over = $GameOver
@onready var mode_select = $ModeSelect
@onready var village_map = $VillageMap
@onready var main_menu = $MainMenu

var active_monster: Dictionary = {}
var last_defeated_encounter_id: String = ""
var current_route_id: int = 0
var router: ScreenRouter
var encounter_ctrl: EncounterController
var inventory_panel: Control

func _ready() -> void:
	router = ScreenRouter.new(self)
	encounter_ctrl = EncounterController.new()
	GameManager.encounter_controller = encounter_ctrl

	# Connect sub-components
	dungeon_view.door_requested.connect(_on_door_selected)
	dungeon_view.door_transition_completed.connect(_on_door_transition_completed)
	GameManager.save_failed.connect(_show_save_error)
	monster_view.monster_defeated.connect(_on_monster_defeated)
	monster_view.rhythm_failed.connect(_on_rhythm_failed)
	monster_view.escape_requested.connect(_on_escape_requested)
	dice_escape.escape_resolved.connect(_on_escape_resolved)
	curse_event.curse_resolved.connect(_on_curse_resolved)
	loot_picker.loot_selected.connect(_on_loot_selected)
	rest_room.descend_requested.connect(_on_descend_requested)
	rest_room.retire_requested.connect(_on_retire_requested)
	rest_room.shop_opened.connect(_on_shop_opened)
	merchant_sell_modal.closed.connect(_on_shop_closed)
	game_over.restart_requested.connect(_on_restart_requested)
	GameManager.game_over_triggered.connect(_on_game_over)
	if mode_select != null:
		mode_select.mode_selected.connect(_on_mode_selected)
		mode_select.continue_endless_requested.connect(_on_continue_endless_requested)
		mode_select.back_requested.connect(router.show_main_menu)
	if village_map != null:
		village_map.enter_dungeon_requested.connect(_on_enter_dungeon_requested)
		village_map.main_menu_requested.connect(router.show_main_menu)
	main_menu.continue_requested.connect(_on_continue_endless_requested)
	main_menu.new_game_requested.connect(_on_enter_dungeon_requested)
	main_menu.village_requested.connect(router.show_village_map)
	main_menu.quit_requested.connect(_on_quit_requested)
	get_tree().auto_accept_quit = false

	encounter_ctrl.restore(GameManager.restored_controller)
	router.show_main_menu()
	inventory_panel = preload("res://scripts/ui/inventory_panel.gd").new()
	inventory_panel.name = "InventoryPanel"
	add_child(inventory_panel)
	hud.inventory_requested.connect(inventory_panel.open)
	var keyboard_navigation = preload("res://scripts/ui/keyboard_navigation.gd").new()
	keyboard_navigation.name = "KeyboardNavigation"
	add_child(keyboard_navigation)
	if not GameManager.persistence_error.is_empty():
		dungeon_view.lock_all_doors()
		_show_save_error.call_deferred(GameManager.persistence_error)
		return

func _on_quit_requested() -> void:
	if GameManager.persistence_error.is_empty() and not GameManager._save_active_run():
		_show_save_error("UI_SAVE_FAILED")
		return
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_quit_requested()

func _show_save_error(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = tr(message) if message.begins_with("UI_") else tr("UI_SAVE_FAILED") + "\n" + message
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.popup_centered()

func _restore_screen() -> void:
	match encounter_ctrl.phase:
		EncounterController.RunPhase.LOOT:
			if encounter_ctrl.pending_loot.is_empty():
				encounter_ctrl.pending_loot = CardDatabase.get_random_loot_cards(GameManager.current_floor, 3)
				encounter_ctrl.recover_legacy_loot = false
				if not GameManager._save_active_run():
					_show_save_error("UI_SAVE_FAILED")
					return
			router.show_loot(GameManager.current_floor)
		EncounterController.RunPhase.REST, EncounterController.RunPhase.SHOP:
			router.show_rest_room()
		EncounterController.RunPhase.COMBAT, EncounterController.RunPhase.ESCAPE, EncounterController.RunPhase.TRANSITION:
			encounter_ctrl.phase = EncounterController.RunPhase.COMBAT if encounter_ctrl.current_encounter.get("kind") != "trap" else EncounterController.RunPhase.CURSE
			_show_encounter()
		EncounterController.RunPhase.CURSE:
			_show_encounter()
		_:
			_show_dungeon_room(false)

func _show_encounter() -> void:
	if encounter_ctrl.phase == EncounterController.RunPhase.COMBAT:
		active_monster = encounter_ctrl.current_encounter
		router.show_combat(active_monster)
	elif encounter_ctrl.phase == EncounterController.RunPhase.CURSE:
		router.show_curse(encounter_ctrl.current_encounter)

func _show_dungeon_room(animated: bool = false) -> void:
	if router != null:
		router.show_corridor(animated)
	else:
		monster_view.visible = false
		dice_escape.visible = false
		curse_event.visible = false
		loot_picker.visible = false
		rest_room.visible = false
		merchant_sell_modal.visible = false
		game_over.visible = false
		hand_ui.visible = true
		dungeon_view.visible = true
		if animated:
			dungeon_view.play_enter_next_room()
		else:
			dungeon_view.reset_view()

func _on_door_selected(door_idx: int) -> void:
	if GameManager.floor_routes == null:
		GameManager._create_floor_routes_for_current_floor()

	var door_slot = maxi(0, mini(2, door_idx - 1))
	current_route_id = door_slot
	var floor_rev = GameManager.floor_routes.revision if GameManager.floor_routes != null else -1

	var req = encounter_ctrl.request_door(door_slot, GameManager.run_generation, floor_rev)
	if not req.get("success", false):
		return

	dungeon_view.begin_accepted_transition(door_idx, int(req.transition_token), GameManager.run_generation)

func _on_door_transition_completed(_door_idx: int, token: int) -> void:
	if encounter_ctrl.apply_door_transition(token):
		_show_encounter()

func _on_monster_defeated() -> void:
	var enc_id = monster_view.current_encounter_id
	if not enc_id.is_empty() and enc_id == last_defeated_encounter_id:
		return
	if encounter_ctrl.commit_monster_defeat(enc_id):
		last_defeated_encounter_id = enc_id
		if GameManager.current_floor >= GameManager.balance_config.get_timed_floor_limit() and GameManager.current_room == GameManager.MAX_ROOMS_PER_FLOOR and GameManager.run_mode == RunMode.Mode.TIMED_100:
			GameManager.run_clock.freeze()
		router.show_loot(GameManager.current_floor)
	else:
		monster_view.setup_monster(encounter_ctrl.current_encounter)

func _on_rhythm_failed(raw_damage: int) -> void:
	var hp_before := GameManager.player_hp
	if not encounter_ctrl.resolve_rhythm_failure(monster_view.current_encounter_id, raw_damage):
		if encounter_ctrl.phase == EncounterController.RunPhase.COMBAT:
			monster_view.setup_monster(encounter_ctrl.current_encounter)
		return
	SoundManager.play_damage()
	if not GameManager.is_game_over:
		_show_dungeon_room(false)
		dungeon_view.show_combat_failure(hp_before - GameManager.player_hp)

func _on_escape_requested(monster: Dictionary) -> void:
	encounter_ctrl.request_escape(monster_view.current_encounter_id)
	router.show_escape(monster)

func _on_escape_resolved(success: bool, raw_damage: int = 0) -> void:
	if not encounter_ctrl.resolve_escape(success, raw_damage):
		return
	if not GameManager.is_game_over:
		_show_dungeon_room(false)

func _on_curse_resolved(raw_damage: int = 0, drain: int = 0) -> void:
	if encounter_ctrl == null or encounter_ctrl.phase != EncounterController.RunPhase.CURSE:
		return
	var was_room = GameManager.current_room
	if not encounter_ctrl.resolve_curse(raw_damage, drain):
		return
	if not GameManager.is_game_over:
		var is_repeat_final = (GameManager.current_floor >= GameManager.balance_config.get_timed_floor_limit() and was_room == 9 and (GameManager.current_dungeon_id in GameManager.player_profile.get("defeated_final_boss_ids", [])))
		if is_repeat_final and GameManager.run_mode == RunMode.Mode.TIMED_100:
			GameManager.completed_floors = GameManager.balance_config.get_timed_floor_limit()
			GameManager.run_clock.freeze()
			encounter_ctrl.set_phase(EncounterController.RunPhase.FINISHED)
			GameManager.settle_current_run(RunMode.Outcome.SUCCESS, 0)
			if not GameManager.floor_stash.is_empty():
				GameManager.unlock_floor_stash()
			if router != null:
				router.show_game_over(true)
			return
		_show_dungeon_room(true)

func _on_loot_selected(card: Dictionary) -> void:
	if GameManager.terminal_outcome != RunMode.Outcome.NONE or encounter_ctrl.phase != EncounterController.RunPhase.LOOT:
		return
	var was_boss = (GameManager.current_room == GameManager.MAX_ROOMS_PER_FLOOR)
	var is_final_floor = (GameManager.current_floor >= GameManager.balance_config.get_timed_floor_limit() and was_boss)
	var is_repeat_final = (GameManager.current_floor >= GameManager.balance_config.get_timed_floor_limit() and GameManager.current_room == 9 and (GameManager.current_dungeon_id in GameManager.player_profile.get("defeated_final_boss_ids", [])))

	if not encounter_ctrl.resolve_loot_selection(was_boss, card):
		loot_picker.is_choosing = false
		return

	if is_repeat_final and GameManager.run_mode == RunMode.Mode.TIMED_100:
		GameManager.completed_floors = GameManager.balance_config.get_timed_floor_limit()
		GameManager.run_clock.freeze()
		if encounter_ctrl != null:
			encounter_ctrl.set_phase(EncounterController.RunPhase.FINISHED)
		GameManager.settle_current_run(RunMode.Outcome.SUCCESS, 0)
		if not GameManager.floor_stash.is_empty():
			GameManager.unlock_floor_stash()
		if router != null:
			router.show_game_over(true)
		return

	if is_final_floor and GameManager.run_mode == RunMode.Mode.TIMED_100:
		GameManager.completed_floors = GameManager.balance_config.get_timed_floor_limit()
		GameManager.run_clock.freeze()
		if not (GameManager.current_dungeon_id in GameManager.player_profile.get("defeated_final_boss_ids", [])):
			GameManager.player_profile["defeated_final_boss_ids"].append(GameManager.current_dungeon_id)
		var next_dungeon = GameManager.balance_config.config_data.dungeons[GameManager.current_dungeon_id].get("next")
		if next_dungeon != null and not next_dungeon in GameManager.player_profile["unlocked_dungeon_ids"]:
			GameManager.player_profile["unlocked_dungeon_ids"].append(next_dungeon)
		if encounter_ctrl != null:
			encounter_ctrl.set_phase(EncounterController.RunPhase.FINISHED)
		GameManager.settle_current_run(RunMode.Outcome.SUCCESS, int(GameManager.balance_config.config_data.economy.first_final_boss_bonus))
		if not GameManager.floor_stash.is_empty():
			GameManager.unlock_floor_stash()
		if router != null:
			router.show_game_over(true)
	else:
		if was_boss:
			if not GameManager.floor_stash.is_empty():
				GameManager.unlock_floor_stash()
			if router != null:
				router.show_rest_room()
		else:
			_show_dungeon_room(true)

func _on_shop_opened() -> void:
	router.open_shop()

func _on_shop_closed() -> void:
	router.close_shop()

func _on_descend_requested() -> void:
	encounter_ctrl.phase = EncounterController.RunPhase.CORRIDOR
	_show_dungeon_room(true)

func _on_retire_requested() -> void:
	GameManager.settle_current_run(RunMode.Outcome.RETIRED, 0)
	if router != null:
		router.show_village_map()

func _on_game_over(victory: bool) -> void:
	if victory:
		GameManager.settle_current_run(RunMode.Outcome.SUCCESS, int(GameManager.balance_config.config_data.economy.first_final_boss_bonus))
		router.show_game_over(victory)
		merchant_sell_modal.visible = false
		hand_ui.visible = false
		game_over.show_screen(victory)
	else:
		GameManager.settle_current_run(RunMode.Outcome.DEATH, 0)
		router.show_village_map()

func _on_mode_selected(mode: int, dungeon_id: String = "crypts") -> void:
	GameManager.start_new_game(mode as RunMode.Mode, dungeon_id)
	_show_dungeon_room(true)

func _on_continue_endless_requested() -> void:
	_restore_screen()

func _on_enter_dungeon_requested() -> void:
	router.show_mode_select()

func _on_restart_requested() -> void:
	if GameManager.terminal_outcome != RunMode.Outcome.NONE and GameManager.player_profile.get("has_returned_from_dungeon", false):
		router.show_village_map()
		return
	GameManager.start_new_game()
	if encounter_ctrl != null:
		encounter_ctrl.set_phase(EncounterController.RunPhase.CORRIDOR)
	hand_ui.visible = true
	_show_dungeon_room(true)
