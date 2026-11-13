extends Control

signal loot_selected(card_data: Dictionary)

const CARD_UI_SCENE = preload("res://scenes/cards/card_ui.tscn")

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SubtitleLabel
@onready var cards_container: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/CardsContainer

var current_options: Array[Dictionary] = []
var is_choosing: bool = false

func _ready() -> void:
	UiIcons.label(title_label, "spark", 20)

func setup_loot(floor_num: int, saved_options: Array = []) -> void:
	is_choosing = false
	current_options.assign(saved_options)
	if current_options.is_empty():
		current_options = CardDatabase.get_random_loot_cards(floor_num, 3)
	
	if is_instance_valid(subtitle_label):
		subtitle_label.text = tr("UI_CHEST_SUBTITLE")

	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()

	for card_data in current_options:
		var card_inst = CARD_UI_SCENE.instantiate()
		cards_container.add_child(card_inst)
		card_inst.setup(card_data)
		card_inst.card_clicked.connect(_on_card_chosen)

func _on_card_chosen(card: Dictionary) -> void:
	if is_choosing:
		return
	is_choosing = true

	SoundManager.play_card_play()

	# Rewards enter the floor chest; its equipment can be worn through inventory.
	# The controller accepts and persists the choice before awarding the card.

	emit_signal("loot_selected", card)
