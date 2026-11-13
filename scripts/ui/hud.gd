extends Control

signal inventory_requested

var inventory_button: Button

@onready var hp_label: Label = $MarginContainer/HBoxContainer/LeftStats/HPBox/HPLabel
@onready var hp_bar: ProgressBar = $MarginContainer/HBoxContainer/LeftStats/HPBox/HPProgressBar
@onready var power_label: Label = $MarginContainer/HBoxContainer/LeftStats/PowerBox/PowerLabel
@onready var gold_label: Label = $MarginContainer/HBoxContainer/LeftStats/GoldBox/GoldLabel
@onready var location_label: Label = $MarginContainer/HBoxContainer/RightStats/LocationBox/LocationLabel
@onready var stash_label: Label = $MarginContainer/HBoxContainer/RightStats/StashBox/StashLabel

func _ready() -> void:
	inventory_button = Button.new()
	inventory_button.theme_type_variation = &"CompactButton"
	inventory_button.custom_minimum_size.y = 22
	inventory_button.add_theme_font_size_override("font_size", 11)
	inventory_button.pressed.connect(func(): inventory_requested.emit())
	$MarginContainer/HBoxContainer/RightStats.add_child(inventory_button)
	UserSettings.changed.connect(_update_inventory_button)
	_update_inventory_button()
	UiIcons.label(gold_label, "coins", 12)
	GameManager.player_stats_changed.connect(update_hud)
	GameManager.inventory_changed.connect(update_hud)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.room_changed.connect(_on_room_changed)
	update_hud()

func _update_inventory_button() -> void:
	inventory_button.text = tr("UI_INVENTORY_BUTTON") % UserSettings.binding_text("inventory")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		update_hud()

func _on_room_changed(_f: int, _r: int) -> void:
	update_hud()

func _on_gold_changed(_amount: int) -> void:
	update_hud()

func update_hud() -> void:
	hp_bar.max_value = GameManager.player_max_hp
	hp_bar.value = GameManager.player_hp
	hp_label.text = "%d / %d" % [GameManager.player_hp, GameManager.player_max_hp]

	var stats := GameManager.get_combat_stats()
	power_label.text = tr("UI_HERO_COMBAT_STATS") % [stats.attack, stats.defense]

	gold_label.text = tr("%d GOLD") % GameManager.player_gold

	if GameManager.current_room == GameManager.MAX_ROOMS_PER_FLOOR:
		location_label.text = tr("FLOOR %d — [ BOSS! ]") % GameManager.current_floor
		location_label.modulate = Color(1.0, 0.25, 0.25)
	else:
		location_label.text = tr("FLOOR %d — ROOM %d / %d") % [GameManager.current_floor, GameManager.current_room, GameManager.MAX_ROOMS_PER_FLOOR]
		location_label.modulate = Color(0.9, 0.9, 1.0)

	var stash_count = GameManager.floor_stash.size()
	stash_label.text = tr("CHEST: %d CARDS") % stash_count
	if stash_count > 0:
		stash_label.modulate = Color(1.0, 0.85, 0.3)
	else:
		stash_label.modulate = Color(0.6, 0.6, 0.6)
