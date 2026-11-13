extends Control

signal closed

const MINI_CARD_SCENE = preload("res://scenes/rest_area/mini_card_ui.tscn")

@onready var gold_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TopBar/GoldBadge/Margin/GoldBadgeLabel
@onready var close_button_top: Button = $PanelContainer/MarginContainer/VBoxContainer/TopBar/CloseButtonTop
@onready var close_button_bottom: Button = $PanelContainer/MarginContainer/VBoxContainer/BottomBar/CloseButtonBottom
@onready var drop_zone: PanelContainer = $PanelContainer/MarginContainer/VBoxContainer/SellDropZone
@onready var toast_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ToastLabel
@onready var cards_container: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/CardsContainer

# Confirm overlay elements
@onready var confirm_overlay: ColorRect = $ConfirmOverlay
@onready var confirm_title: Label = $ConfirmOverlay/ConfirmPanel/Margin/VBox/ConfirmTitle
@onready var confirm_details: Label = $ConfirmOverlay/ConfirmPanel/Margin/VBox/ConfirmDetails
@onready var confirm_button: Button = $ConfirmOverlay/ConfirmPanel/Margin/VBox/ButtonsHBox/ConfirmButton
@onready var cancel_button: Button = $ConfirmOverlay/ConfirmPanel/Margin/VBox/ButtonsHBox/CancelButton

var _previous_focus_owner: Control = null
var pending_sell_card: Dictionary = {}
var is_selling_in_progress: bool = false

func _ready() -> void:
	$PanelContainer/MarginContainer/VBoxContainer/ScrollContainer.follow_focus = true
	UiIcons.label($PanelContainer/MarginContainer/VBoxContainer/TopBar/TitleLabel, "coins", 20)
	UiIcons.label(gold_label, "coins")
	UiIcons.label($PanelContainer/MarginContainer/VBoxContainer/BackpackTitle, "bag", 12)
	UiIcons.label(confirm_title, "scales")
	UiIcons.button(close_button_top, "close")
	UiIcons.button(close_button_bottom, "close")
	UiIcons.button(confirm_button, "check")
	UiIcons.button(cancel_button, "close")
	close_button_top.pressed.connect(_on_close_pressed)
	close_button_bottom.pressed.connect(_on_close_pressed)
	drop_zone.card_sold.connect(_on_card_sell_intent)
	confirm_button.pressed.connect(_on_confirm_sell_pressed)
	cancel_button.pressed.connect(_on_cancel_sell_pressed)
	
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.inventory_changed.connect(_update_cards_list)
	
	confirm_overlay.visible = false

func open_shop() -> void:
	UiIcons.label(toast_label, "")
	GameManager.is_shop_open = true
	visible = true
	pending_sell_card = {}
	is_selling_in_progress = false
	confirm_overlay.visible = false
	
	if get_viewport():
		_previous_focus_owner = get_viewport().gui_get_focus_owner()
		
	toast_label.text = tr("UI_MERCHANT_KEYBOARD_HELP") % [UserSettings.binding_text("ui_focus_next"), UserSettings.binding_text("ui_accept"), UserSettings.binding_text("ui_cancel")]
	toast_label.modulate = Color(0.85, 0.85, 0.9)
	_on_gold_changed(GameManager.player_gold)
	_update_cards_list()
	
	# Initial focus on top close button or first card
	call_deferred("_set_initial_modal_focus")

func close_shop() -> void:
	_on_close_pressed()

func _set_initial_modal_focus() -> void:
	if not visible:
		return
	if cards_container.get_child_count() > 0 and cards_container.get_child(0) is Control:
		var first = cards_container.get_child(0)
		if first.focus_mode != Control.FOCUS_NONE:
			first.grab_focus()
			return
	if is_instance_valid(close_button_top):
		close_button_top.grab_focus()

func _on_gold_changed(gold: int) -> void:
	if is_instance_valid(gold_label):
		gold_label.text = tr("Wallet: %d gold") % gold

func _update_cards_list() -> void:
	if not is_visible_in_tree():
		return

	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()

	if GameManager.hand_cards.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = tr("No cards to sell in your backpack.")
		empty_lbl.modulate = Color(0.7, 0.7, 0.7)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cards_container.add_child(empty_lbl)
		return

	for card_data in GameManager.hand_cards:
		var mini_card = MINI_CARD_SCENE.instantiate()
		cards_container.add_child(mini_card)
		mini_card.setup(card_data)
		mini_card.card_clicked.connect(_on_card_sell_intent)

func _on_card_sell_intent(card: Dictionary) -> void:
	if is_selling_in_progress or confirm_overlay.visible:
		return
	
	pending_sell_card = card.duplicate(true)
	var card_name = CardPresenter.get_display_name(pending_sell_card)
	var price = int(pending_sell_card.get("sell_value", 15))
	
	confirm_details.text = tr("Sell \"%s\" for %d gold?") % [card_name, price]
	confirm_overlay.visible = true
	confirm_button.grab_focus()

func _on_confirm_sell_pressed() -> void:
	if is_selling_in_progress or pending_sell_card.is_empty():
		return
	
	is_selling_in_progress = true
	
	# Validate item is still in hand with matching identity/revision
	var target_inst_id = str(pending_sell_card.get("instance_id", ""))
	var target_def_id = str(pending_sell_card.get("id", ""))
	var target_rev = int(pending_sell_card.get("revision", -1))
	
	var valid_in_hand = false
	for c in GameManager.hand_cards:
		var match_id = false
		if not target_inst_id.is_empty() and c.has("instance_id"):
			match_id = (str(c.get("instance_id", "")) == target_inst_id)
		else:
			match_id = (str(c.get("id", "")) == target_def_id)
		
		if match_id:
			if target_rev == -1 or int(c.get("revision", -1)) == target_rev:
				valid_in_hand = true
			break
	
	if not valid_in_hand:
		UiIcons.label(toast_label, "close")
		toast_label.text = tr("This item cannot be sold.")
		toast_label.modulate = Color(1.0, 0.4, 0.4)
		_close_confirm()
		is_selling_in_progress = false
		return
	
	var card_name = CardPresenter.get_display_name(pending_sell_card)
	var price = int(pending_sell_card.get("sell_value", 15))
	
	var success = GameManager.sell_card(pending_sell_card)
	if success:
		UiIcons.label(toast_label, "check")
		toast_label.text = tr("Sold: %s (+%d gold)!") % [card_name, price]
		toast_label.modulate = Color(0.4, 1.0, 0.5)
		var tween = create_tween()
		tween.tween_property(toast_label, "scale", Vector2(1.08, 1.08), 0.08)
		tween.tween_property(toast_label, "scale", Vector2(1.0, 1.0), 0.12)
	else:
		UiIcons.label(toast_label, "close")
		toast_label.text = tr("Could not sell the item.")
		toast_label.modulate = Color(1.0, 0.4, 0.4)
	
	_close_confirm()
	is_selling_in_progress = false

func _on_cancel_sell_pressed() -> void:
	_close_confirm()

func _close_confirm() -> void:
	pending_sell_card = {}
	confirm_overlay.visible = false
	call_deferred("_set_initial_modal_focus")

func _on_close_pressed() -> void:
	if confirm_overlay.visible:
		_close_confirm()
		return
		
	GameManager.is_shop_open = false
	visible = false
	
	# Restore background focus if still valid
	if _previous_focus_owner and is_instance_valid(_previous_focus_owner) and _previous_focus_owner.is_inside_tree():
		if _previous_focus_owner.is_visible_in_tree() and _previous_focus_owner.focus_mode != Control.FOCUS_NONE:
			_previous_focus_owner.grab_focus()
	
	SoundManager.play_click()
	emit_signal("closed")

func _get_all_focusables(root: Node) -> Array[Control]:
	var result: Array[Control] = []
	if not (root is Control) or not root.visible:
		return result
	var ctrl: Control = root as Control
	if ctrl.is_queued_for_deletion():
		return result
	if ctrl.focus_mode == Control.FOCUS_ALL and not ctrl is ScrollContainer and not ctrl is ScrollBar and not (ctrl is BaseButton and ctrl.disabled):
		result.append(ctrl)
	for child in root.get_children():
		result.append_array(_get_all_focusables(child))
	return result

func _input(event: InputEvent) -> void:
	if not visible or not GameManager.is_shop_open:
		return
	
	if event.is_action_pressed("ui_cancel"):
		if confirm_overlay.visible:
			_close_confirm()
		else:
			_on_close_pressed()
		get_viewport().set_input_as_handled()
		return
	
	# All navigation stays inside the topmost modal.
	var forward = event.is_action_pressed("ui_focus_next", true, true) or event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_right", true)
	var backward = event.is_action_pressed("ui_focus_prev", true, true) or event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_left", true)
	if forward or backward:
		var shift = backward
		var focusables: Array[Control] = []
		if confirm_overlay.visible:
			focusables = [confirm_button, cancel_button]
		else:
			focusables = _get_all_focusables(self)
		
		if focusables.is_empty():
			return
		
		var cur_focus = get_viewport().gui_get_focus_owner()
		var cur_idx = focusables.find(cur_focus)
		var next_idx = 0
		
		if cur_idx == -1:
			next_idx = 0
		elif shift:
			next_idx = (cur_idx - 1 + focusables.size()) % focusables.size()
		else:
			next_idx = (cur_idx + 1) % focusables.size()
		
		focusables[next_idx].grab_focus()
		get_viewport().set_input_as_handled()
