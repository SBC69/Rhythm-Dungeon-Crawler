extends Control

signal descend_requested
signal retire_requested
signal shop_opened

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var gold_badge_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TopBar/GoldBadge/Margin/GoldBadgeLabel

# Campfire elements
@onready var rest_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CampfireSection/Margin/VBox/RestButton

# Forge elements
@onready var forge_weapon_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ForgeSection/Margin/VBox/ForgeWeaponLabel
@onready var forge_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ForgeSection/Margin/VBox/ForgeButton

# Merchant elements
@onready var merchant_button: Button = $PanelContainer/MarginContainer/VBoxContainer/MerchantSection/Margin/VBox/MerchantButton

# Bottom action buttons
@onready var descend_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ActionsBox/DescendButton
@onready var retire_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ActionsBox/RetireButton

var has_rested: bool = false
var rest_used_for_floor: int = -1

func _ready() -> void:
	UiIcons.label(title_label, "trophy")
	UiIcons.label(gold_badge_label, "coins")
	UiIcons.label($PanelContainer/MarginContainer/VBoxContainer/EquipHint, "bag", 12)
	UiIcons.label($PanelContainer/MarginContainer/VBoxContainer/CampfireSection/Margin/VBox/SectionTitle, "fire", 12)
	UiIcons.label($PanelContainer/MarginContainer/VBoxContainer/ForgeSection/Margin/VBox/SectionTitle, "hammer", 12)
	UiIcons.label($PanelContainer/MarginContainer/VBoxContainer/MerchantSection/Margin/VBox/SectionTitle, "coins", 12)
	UiIcons.button(rest_button, "fire")
	UiIcons.button(forge_button, "hammer")
	UiIcons.button(merchant_button, "coins")
	UiIcons.button(descend_button, "sword")
	UiIcons.button(retire_button, "crown")
	rest_button.pressed.connect(_on_rest_pressed)
	descend_button.pressed.connect(_on_descend_pressed)
	retire_button.pressed.connect(_on_retire_pressed)
	forge_button.pressed.connect(_on_forge_pressed)
	merchant_button.pressed.connect(_on_merchant_pressed)

	GameManager.gold_changed.connect(_on_gold_updated)
	GameManager.player_stats_changed.connect(_on_player_stats_changed)

func setup_rest_room() -> void:
	$PanelContainer/MarginContainer/VBoxContainer/EquipHint.text = tr("UI_CARDS_KEYBOARD_HELP") % [UserSettings.binding_text("ui_focus_next"), UserSettings.binding_text("ui_focus_prev"), UserSettings.binding_text("ui_accept")]
	has_rested = (rest_used_for_floor == GameManager.current_floor)
	title_label.text = tr("FLOOR %d CLEARED! BOSS DEFEATED!") % GameManager.current_floor

	if has_rested:
		rest_button.disabled = true
		rest_button.text = tr("The campfire is fading (+15 HP received)")
	else:
		rest_button.disabled = false
		rest_button.text = tr("Rest at Campfire (+15 HP)")
	descend_button.text = tr("Descend to floor %d") % (GameManager.current_floor + 1)

	_on_gold_updated(GameManager.player_gold)
	_update_forge_ui()

func _on_gold_updated(gold: int) -> void:
	if is_instance_valid(gold_badge_label):
		gold_badge_label.text = tr("Wallet: %d gold") % gold
	if is_visible_in_tree():
		_update_forge_ui()

func _on_player_stats_changed() -> void:
	if is_visible_in_tree():
		_update_forge_ui()

func _update_forge_ui() -> void:
	if GameManager.is_shop_open:
		forge_button.disabled = true
		return

	if GameManager.equipped_weapon.is_empty():
		forge_weapon_label.text = tr("No weapon equipped")
		forge_button.disabled = true
		forge_button.text = tr("No weapon to upgrade")
		return

	var w_name = CardPresenter.get_display_name(GameManager.equipped_weapon)
	var w_pow = int(GameManager.equipped_weapon.get("power", 2))
	var cost = GameManager.get_weapon_upgrade_cost()
	var lvl = GameManager.weapon_upgrade_level
	var forge_stage = int(GameManager.player_profile.get("village_object_stages", {}).get("forge", 0))
	var gain = 2 + forge_stage

	forge_weapon_label.text = tr("Current weapon: %s (Attack: %d, Upgrade: +%d)") % [w_name, w_pow, lvl]

	if lvl >= 5:
		forge_button.disabled = true
		forge_button.text = tr("Maximum upgrade reached (+5)")
		forge_button.modulate = Color(0.8, 0.8, 0.8)
	elif GameManager.player_gold >= cost:
		forge_button.disabled = false
		forge_button.text = tr("Sharpen weapon (+%d attack) — %d gold") % [gain, cost]
		forge_button.modulate = Color(1.0, 0.85, 0.3)
	else:
		forge_button.disabled = true
		forge_button.text = tr("Sharpen (+%d attack) — need %d gold (%d short)") % [gain, cost, cost - GameManager.player_gold]
		forge_button.modulate = Color(0.8, 0.8, 0.8)

func set_interactive(is_interactive: bool) -> void:
	rest_button.disabled = !is_interactive or has_rested
	descend_button.disabled = !is_interactive
	retire_button.disabled = !is_interactive
	merchant_button.disabled = !is_interactive
	if not is_interactive:
		forge_button.disabled = true
	else:
		_update_forge_ui()

func _on_forge_pressed() -> void:
	if GameManager.upgrade_equipped_weapon():
		_update_forge_ui()

func _on_merchant_pressed() -> void:
	SoundManager.play_click()
	emit_signal("shop_opened")

func _on_rest_pressed() -> void:
	if not has_rested and rest_used_for_floor != GameManager.current_floor:
		has_rested = true
		rest_used_for_floor = GameManager.current_floor
		GameManager.heal_player(15)
		rest_button.disabled = true
		rest_button.text = tr("The campfire is fading (+15 HP received)")

func _on_descend_pressed() -> void:
	SoundManager.play_door_open()
	if GameManager.advance_to_next_floor():
		emit_signal("descend_requested")

func _on_retire_pressed() -> void:
	SoundManager.play_victory()
	emit_signal("retire_requested")
