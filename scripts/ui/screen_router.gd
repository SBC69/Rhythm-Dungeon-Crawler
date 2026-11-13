# scripts/ui/screen_router.gd
class_name ScreenRouter
extends RefCounted

var dungeon_view: Control
var hud: Control
var hand_ui: Control
var monster_view: Control
var dice_escape: Control
var curse_event: Control
var loot_picker: Control
var rest_room: Control
var merchant_sell_modal: Control
var game_over: Control
var mode_select: Control
var village_map: Control
var main_menu: Control

func _init(main_node: Control) -> void:
	dungeon_view = main_node.get_node_or_null("DungeonView")
	hud = main_node.get_node_or_null("HUD")
	hand_ui = main_node.get_node_or_null("HandUI")
	monster_view = main_node.get_node_or_null("MonsterView")
	dice_escape = main_node.get_node_or_null("DiceEscape")
	curse_event = main_node.get_node_or_null("CurseEvent")
	loot_picker = main_node.get_node_or_null("LootPicker")
	rest_room = main_node.get_node_or_null("RestRoom")
	merchant_sell_modal = main_node.get_node_or_null("MerchantSellModal")
	game_over = main_node.get_node_or_null("GameOver")
	mode_select = main_node.get_node_or_null("ModeSelect")
	village_map = main_node.get_node_or_null("VillageMap")
	main_menu = main_node.get_node_or_null("MainMenu")

func hide_all_screens() -> void:
	if main_menu: main_menu.visible = false
	if dungeon_view: dungeon_view.visible = false
	if monster_view: monster_view.visible = false
	if dice_escape: dice_escape.visible = false
	if curse_event: curse_event.visible = false
	if loot_picker: loot_picker.visible = false
	if rest_room: rest_room.visible = false
	if merchant_sell_modal: merchant_sell_modal.visible = false
	if game_over: game_over.visible = false
	if mode_select: mode_select.visible = false
	if village_map: village_map.visible = false

func show_corridor(animated: bool = false) -> void:
	hide_all_screens()
	if hud: hud.visible = true
	if hand_ui: hand_ui.visible = true
	if dungeon_view:
		dungeon_view.visible = true
		if animated:
			dungeon_view.play_enter_next_room()
		else:
			dungeon_view.reset_view()

func show_combat(monster_data: Dictionary) -> void:
	hide_all_screens()
	if hand_ui: hand_ui.visible = true
	if monster_view:
		monster_view.visible = true
		monster_view.setup_monster(monster_data)

func show_escape(monster_data: Dictionary) -> void:
	hide_all_screens()
	if hand_ui: hand_ui.visible = true
	if dice_escape:
		dice_escape.visible = true
		dice_escape.setup_escape(monster_data)

func show_curse(curse_data: Dictionary) -> void:
	hide_all_screens()
	if hand_ui: hand_ui.visible = true
	if curse_event:
		curse_event.visible = true
		curse_event.setup_curse(curse_data)

func show_loot(floor_num: int) -> void:
	hide_all_screens()
	if hand_ui: hand_ui.visible = true
	if loot_picker:
		loot_picker.visible = true
		loot_picker.setup_loot(floor_num, GameManager.encounter_controller.pending_loot)

func show_rest_room() -> void:
	hide_all_screens()
	if hand_ui: hand_ui.visible = true
	if rest_room:
		rest_room.visible = true
		rest_room.setup_rest_room()

func open_shop() -> void:
	if rest_room and rest_room.has_method("set_interactive"):
		rest_room.set_interactive(false)
	if merchant_sell_modal:
		merchant_sell_modal.open_shop()

func close_shop() -> void:
	if merchant_sell_modal:
		merchant_sell_modal.visible = false
	if rest_room:
		rest_room.visible = true
		if rest_room.has_method("set_interactive"):
			rest_room.set_interactive(true)
	if hand_ui:
		hand_ui.visible = true

func show_game_over(victory: bool) -> void:
	hide_all_screens()
	if hand_ui: hand_ui.visible = false
	if game_over:
		game_over.show_screen(victory)

func show_village_map() -> void:
	hide_all_screens()
	if hand_ui: hand_ui.visible = false
	if hud: hud.visible = false
	if village_map:
		village_map.visible = true
		if village_map.has_method("setup"):
			var vstate = VillageState.new()
			if GameManager.player_profile.has("village_object_stages"):
				vstate.stages = GameManager.player_profile["village_object_stages"].duplicate(true)
			if GameManager.player_profile.has("village_object_revisions"):
				vstate.revisions = GameManager.player_profile["village_object_revisions"].duplicate(true)
			village_map.setup(vstate, GameManager.player_profile)

func show_mode_select() -> void:
	hide_all_screens()
	if hand_ui: hand_ui.visible = false
	if hud: hud.visible = false
	if mode_select:
		mode_select.visible = true
		mode_select.setup(int(GameManager.player_profile.get("wallet_gold", 0)), bool(GameManager.player_profile.get("active_endless_run", false)))

func show_main_menu() -> void:
	hide_all_screens()
	if hand_ui: hand_ui.visible = false
	if hud: hud.visible = false
	if main_menu:
		main_menu.visible = true
		var can_continue := GameManager.run_mode == RunMode.Mode.ENDLESS and bool(GameManager.player_profile.get("active_endless_run", false)) and GameManager.terminal_outcome == RunMode.Outcome.NONE and not GameManager.is_game_over
		var summary := tr("UI_MENU_RUN_SUMMARY") % [GameManager.current_floor, GameManager.current_room]
		main_menu.setup(int(GameManager.player_profile.get("wallet_gold", 0)), can_continue, not GameManager.persistence_error.is_empty(), summary)
