extends ColorRect

var main: Control
var panel: PanelContainer
var stats_label: Label
var hint: Label
var feedback: Label
var close_button: Button
var scroll: ScrollContainer
var items: VBoxContainer
var slot_names: Dictionary = {}
var slot_stats: Dictionary = {}
var unequip_buttons: Dictionary = {}
var item_buttons: Array[Button] = []
var _previous_focus: Control
var _refresh_pending := false

func _ready() -> void:
	main = get_parent()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.025, 0.018, 0.04, 0.96)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 620)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label("UI_INVENTORY_TITLE", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = _button("UI_CLOSE")
	close_button.pressed.connect(close)
	header.add_child(close_button)
	stats_label = _label("", 14)
	column.add_child(stats_label)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 12)
	column.add_child(slots)
	for type in [CardDatabase.CardType.WEAPON, CardDatabase.CardType.ARMOR, CardDatabase.CardType.AMULET]:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots.add_child(box)
		var name_label := _label("", 14)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size.y = 36
		box.add_child(name_label)
		slot_names[type] = name_label
		var stat_label := _label("", 12)
		box.add_child(stat_label)
		slot_stats[type] = stat_label
		var button := _button("UI_INVENTORY_UNEQUIP")
		button.pressed.connect(_unequip.bind(type))
		box.add_child(button)
		unequip_buttons[type] = button
	hint = _label("UI_INVENTORY_HELP", 12)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(920, 290)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	items = VBoxContainer.new()
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items.add_theme_constant_override("separation", 8)
	scroll.add_child(items)
	feedback = _label("", 12)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 30
	column.add_child(feedback)
	GameManager.inventory_changed.connect(_queue_refresh)
	GameManager.player_stats_changed.connect(_queue_refresh)
	visible = false

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 32)
	button.add_theme_font_size_override("font_size", 13)
	return button

func can_open() -> bool:
	if not GameManager.can_use_inventory():
		return false
	if main.main_menu.visible or main.mode_select.visible or main.village_map.visible or main.game_over.visible or main.merchant_sell_modal.visible:
		return false
	if main.dungeon_view.visible and main.dungeon_view.is_transitioning:
		return false
	return not (main.dice_escape.visible and main.dice_escape.is_rolling) and not (main.curse_event.visible and main.curse_event.is_rolling)

func open() -> void:
	if not can_open():
		return
	_previous_focus = get_viewport().gui_get_focus_owner()
	visible = true
	_refresh()
	feedback.text = ""
	scroll.scroll_vertical = 0
	close_button.grab_focus()

func close(restore_focus: bool = true) -> void:
	visible = false
	if not restore_focus:
		return
	if is_instance_valid(_previous_focus) and _previous_focus.is_inside_tree() and _previous_focus.is_visible_in_tree() and not _previous_focus.is_queued_for_deletion():
		if not (_previous_focus is BaseButton and _previous_focus.disabled):
			_previous_focus.grab_focus()
			return
	if can_open() and main.hud.is_visible_in_tree():
		main.hud.inventory_button.grab_focus()

func _process(_delta: float) -> void:
	var available := can_open()
	main.hud.inventory_button.disabled = not available
	if visible and not available:
		close(false)

func _queue_refresh() -> void:
	if not is_visible_in_tree() or _refresh_pending:
		return
	_refresh_pending = true
	_refresh.call_deferred()

func _refresh() -> void:
	_refresh_pending = false
	if not is_visible_in_tree():
		return
	var current := get_viewport().gui_get_focus_owner()
	var index := item_buttons.find(current) if current is Button else -1
	var stats := GameManager.get_combat_stats()
	stats_label.text = tr("UI_HERO_COMBAT_STATS") % [stats.attack, stats.defense]
	var equipment := {CardDatabase.CardType.WEAPON: GameManager.equipped_weapon, CardDatabase.CardType.ARMOR: GameManager.equipped_armor, CardDatabase.CardType.AMULET: GameManager.equipped_amulet}
	for type in equipment:
		var card: Dictionary = equipment[type]
		var label: Label = slot_names[type]
		label.text = CardPresenter.get_display_name(card) if not card.is_empty() else tr("UI_INVENTORY_EMPTY_SLOT")
		label.tooltip_text = CardPresenter.get_tooltip_text(card)
		label.modulate = CardPresenter.get_type_color({"type": type})
		slot_stats[type].text = CardPresenter.get_stat_badge_text(card) if not card.is_empty() else CardPresenter.get_type_title({"type": type})
		unequip_buttons[type].disabled = card.is_empty()
	for child in items.get_children():
		items.remove_child(child)
		child.queue_free()
	item_buttons.clear()
	_add_section("UI_INVENTORY_BACKPACK", GameManager.hand_cards, false)
	_add_section("UI_INVENTORY_FLOOR_CHEST", GameManager.floor_stash, true)
	if index >= 0:
		_restore_item_focus.call_deferred(index)

func _add_section(title: String, cards: Array, from_stash: bool) -> void:
	items.add_child(_label(tr(title), 16))
	if cards.is_empty():
		items.add_child(_label("UI_INVENTORY_EMPTY", 12))
	for card in cards:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 58
		row.add_theme_constant_override("separation", 12)
		items.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_path := str(card.get("icon", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path)
		row.add_child(icon)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var name_label := _label(CardPresenter.get_display_name(card), 14)
		if int(card.get("count", 1)) > 1:
			name_label.text += " ×%d" % int(card.count)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.modulate = CardPresenter.get_rarity_color(card)
		details.add_child(name_label)
		var description := _label(CardPresenter.get_type_title(card) + " · " + CardPresenter.get_stat_badge_text(card), 12)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(description)
		var gear := CardIdentity.is_equipment_type(int(card.get("type", -1)))
		var button := _button(tr("UI_INVENTORY_EQUIP" if gear else ("UI_INVENTORY_LOCKED" if from_stash else "UI_INVENTORY_USE")))
		button.disabled = from_stash and not gear
		button.set_meta("instance_id", str(card.get("instance_id", "")))
		button.set_meta("from_stash", from_stash)
		button.tooltip_text = CardPresenter.get_tooltip_text(card)
		button.pressed.connect(_use_item.bind(card.duplicate(true), from_stash))
		row.add_child(button)
		item_buttons.append(button)

func _restore_item_focus(index: int) -> void:
	if not is_visible_in_tree():
		return
	for offset in range(item_buttons.size()):
		var button := item_buttons[posmod(index + offset, item_buttons.size())]
		if not button.disabled:
			button.grab_focus()
			return
	close_button.grab_focus()

func _use_item(card: Dictionary, from_stash: bool) -> void:
	if not can_open():
		return
	var success := GameManager.use_inventory_item(card, from_stash)
	feedback.text = tr("UI_INVENTORY_DONE") % CardPresenter.get_display_name(card) if success else tr("UI_INVENTORY_FAILED")
	feedback.modulate = Color("81eed0") if success else Color("f18e77")

func _unequip(type: int) -> void:
	if not can_open():
		return
	var success := GameManager.unequip_inventory_slot(type)
	feedback.text = tr("UI_INVENTORY_UNEQUIPPED") if success else tr("UI_INVENTORY_FAILED")
	feedback.modulate = Color("81eed0") if success else Color("f18e77")

func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory"):
			get_viewport().set_input_as_handled()
			close()
		elif event.is_action_pressed("ui_page_down", true) or event.is_action_pressed("ui_page_up", true):
			scroll.scroll_vertical += 180 if event.is_action_pressed("ui_page_down", true) else -180
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and can_open():
		get_viewport().set_input_as_handled()
		open()
