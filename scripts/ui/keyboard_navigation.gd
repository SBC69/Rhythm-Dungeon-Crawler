extends Node
## Keeps keyboard focus on the current screen, including after UI rebuilds.

var main: Control

func _ready() -> void:
	main = get_parent()

func _focusables() -> Array[Control]:
	var result: Array[Control] = []
	if is_instance_valid(main.inventory_panel) and main.inventory_panel.visible:
		_collect(main.inventory_panel, result)
		return result
	if main.monster_view.is_visible_in_tree() and main.monster_view.is_resolving:
		return result
	var screen: Control = null
	for candidate in [main.main_menu, main.village_map, main.mode_select, main.game_over,
		main.merchant_sell_modal, main.monster_view, main.dice_escape, main.curse_event,
		main.loot_picker, main.rest_room, main.dungeon_view]:
		if candidate.is_visible_in_tree():
			screen = candidate
			break
	if screen == null:
		return result
	if screen == main.main_menu and screen.settings_panel.visible:
		_collect(screen.settings_panel, result)
	elif screen == main.merchant_sell_modal and screen.confirm_overlay.visible:
		_collect(screen.confirm_overlay, result)
	elif screen == main.village_map and (screen.confirm_modal.visible or screen.detail_modal.visible):
		_collect(screen.confirm_modal if screen.confirm_modal.visible else screen.detail_modal, result)
	else:
		_collect(screen, result)
		if screen in [main.monster_view, main.dice_escape, main.curse_event,
			main.loot_picker, main.rest_room, main.dungeon_view]:
			_collect(main.hud, result)
			_collect(main.hand_ui, result)
	return result

func _collect(node: Node, result: Array[Control]) -> void:
	if node.is_queued_for_deletion():
		return
	if node is Control:
		if not node.is_visible_in_tree():
			return
		if node.focus_mode == Control.FOCUS_ALL and not node is ScrollContainer and not node is ScrollBar:
			if not (node is BaseButton and node.disabled):
				result.append(node)
	for child in node.get_children():
		_collect(child, result)

func _process(_delta: float) -> void:
	var controls := _focusables()
	if not controls.is_empty() and not get_viewport().gui_get_focus_owner() in controls:
		controls[0].grab_focus()

func _input(event: InputEvent) -> void:
	if main.main_menu.is_visible_in_tree() and main.main_menu.settings_panel.visible and not main.main_menu.settings_panel.capture_action.is_empty():
		return
	if not event is InputEventKey or not event.pressed:
		return
	# A rhythm binding can share a menu navigation key; combat owns it here.
	if main.monster_view.is_visible_in_tree() and main.monster_view.is_resolving:
		if UserSettings.rhythm_key_pressed(event, "rhythm_attack") or UserSettings.rhythm_key_pressed(event, "rhythm_guard"):
			return
	# These screens own their modal focus and scrolling behavior.
	if main.merchant_sell_modal.is_visible_in_tree():
		return
	if main.village_map.is_visible_in_tree() and (main.village_map.detail_modal.visible or main.village_map.confirm_modal.visible):
		return
	var direction := 0
	var tab := event.is_action_pressed("ui_focus_next", true, true) or event.is_action_pressed("ui_focus_prev", true, true)
	if event.is_action_pressed("ui_focus_next", true, true):
		direction = 1
	elif event.is_action_pressed("ui_focus_prev", true, true):
		direction = -1
	elif not main.village_map.is_visible_in_tree():
		if event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_down", true):
			direction = 1
		elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_up", true):
			direction = -1
	if direction == 0:
		return
	var current := get_viewport().gui_get_focus_owner()
	if not tab and (current is Range or current is LineEdit or current is OptionButton):
		return
	var controls := _focusables()
	if controls.is_empty():
		get_viewport().set_input_as_handled()
		return
	var index := controls.find(current)
	var next := posmod(index + direction, controls.size()) if index >= 0 else (0 if direction > 0 else controls.size() - 1)
	controls[next].grab_focus()
	get_viewport().set_input_as_handled()
