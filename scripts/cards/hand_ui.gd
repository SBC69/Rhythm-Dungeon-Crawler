extends Control

const CARD_UI_SCENE = preload("res://scenes/cards/card_ui.tscn")

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var cards_container: HBoxContainer = $ScrollContainer/MarginContainer/CardsContainer

func _ready() -> void:
	scroll_container.follow_focus = true
	scroll_container.gui_input.connect(_on_scroll_gui_input)
	gui_input.connect(_on_scroll_gui_input)
	GameManager.inventory_changed.connect(refresh_hand)
	refresh_hand()

func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_container.scroll_horizontal += 80
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_container.scroll_horizontal -= 80
			accept_event()

func refresh_hand() -> void:
	var focused_index := -1
	var focus := get_viewport().gui_get_focus_owner()
	# Clear existing card views
	for child in cards_container.get_children():
		if child == focus:
			focused_index = child.get_index()
	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()

	for card_data in GameManager.hand_cards:
		var card_inst = CARD_UI_SCENE.instantiate()
		cards_container.add_child(card_inst)
		card_inst.setup(card_data)
		card_inst.card_clicked.connect(_on_card_clicked)
	if focused_index >= 0:
		_restore_card_focus.call_deferred(focused_index)

func _restore_card_focus(index: int) -> void:
	if not is_visible_in_tree() or GameManager.is_shop_open or cards_container.get_child_count() == 0:
		return
	if GameManager.encounter_controller != null and GameManager.encounter_controller.combat_input_locked:
		return
	cards_container.get_child(mini(index, cards_container.get_child_count() - 1)).grab_focus()

func _on_card_clicked(card_data: Dictionary) -> void:
	if GameManager.is_shop_open:
		# When shop is open, clicking cards does not use or consume them
		return
	# Try to play the card
	GameManager.play_card(card_data)
