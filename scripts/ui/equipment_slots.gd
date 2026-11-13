extends Control

@onready var weapon_slot = $HBoxContainer/WeaponSlot
@onready var armor_slot = $HBoxContainer/ArmorSlot
@onready var amulet_slot = $HBoxContainer/AmuletSlot

@onready var weapon_label = $HBoxContainer/WeaponSlot/MarginContainer/VBox/NameLabel
@onready var weapon_stat = $HBoxContainer/WeaponSlot/MarginContainer/VBox/StatLabel
@onready var weapon_unequip_btn: Button = $HBoxContainer/WeaponSlot/MarginContainer/VBox/HeaderHBox/UnequipButton

@onready var armor_label = $HBoxContainer/ArmorSlot/MarginContainer/VBox/NameLabel
@onready var armor_stat = $HBoxContainer/ArmorSlot/MarginContainer/VBox/StatLabel
@onready var armor_unequip_btn: Button = $HBoxContainer/ArmorSlot/MarginContainer/VBox/HeaderHBox/UnequipButton

@onready var amulet_label = $HBoxContainer/AmuletSlot/MarginContainer/VBox/NameLabel
@onready var amulet_stat = $HBoxContainer/AmuletSlot/MarginContainer/VBox/StatLabel
@onready var amulet_unequip_btn: Button = $HBoxContainer/AmuletSlot/MarginContainer/VBox/HeaderHBox/UnequipButton

func _ready() -> void:
	UiIcons.label($HBoxContainer/WeaponSlot/MarginContainer/VBox/HeaderHBox/TypeLabel, "sword", 12)
	UiIcons.label($HBoxContainer/ArmorSlot/MarginContainer/VBox/HeaderHBox/TypeLabel, "shield", 12)
	UiIcons.label($HBoxContainer/AmuletSlot/MarginContainer/VBox/HeaderHBox/TypeLabel, "ring", 12)
	weapon_unequip_btn.pressed.connect(_on_unequip_weapon)
	armor_unequip_btn.pressed.connect(_on_unequip_armor)
	amulet_unequip_btn.pressed.connect(_on_unequip_amulet)

	GameManager.player_stats_changed.connect(refresh_slots)
	GameManager.inventory_changed.connect(refresh_slots)
	refresh_slots()

func _on_unequip_weapon() -> void:
	if GameManager.is_shop_open:
		return
	GameManager.unequip_slot(CardDatabase.CardType.WEAPON)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh_slots()

func _on_unequip_armor() -> void:
	if GameManager.is_shop_open:
		return
	GameManager.unequip_slot(CardDatabase.CardType.ARMOR)

func _on_unequip_amulet() -> void:
	if GameManager.is_shop_open:
		return
	GameManager.unequip_slot(CardDatabase.CardType.AMULET)

func refresh_slots() -> void:
	weapon_slot.tooltip_text = CardPresenter.get_tooltip_text(GameManager.equipped_weapon)
	armor_slot.tooltip_text = CardPresenter.get_tooltip_text(GameManager.equipped_armor)
	amulet_slot.tooltip_text = CardPresenter.get_tooltip_text(GameManager.equipped_amulet)
	# Weapon
	if not GameManager.equipped_weapon.is_empty():
		weapon_label.text = CardPresenter.get_display_name(GameManager.equipped_weapon)
		weapon_stat.text = tr("UI_WEAPON_ATTACK") % int(GameManager.equipped_weapon.get("power", 0))
		weapon_slot.modulate = Color(1.0, 1.0, 1.0)
		weapon_unequip_btn.visible = true
		weapon_unequip_btn.disabled = false
	else:
		weapon_label.text = tr("[ Empty ]")
		weapon_stat.text = tr("Drag a weapon here")
		weapon_slot.modulate = Color(0.7, 0.7, 0.7)
		weapon_unequip_btn.visible = false
		weapon_unequip_btn.disabled = true

	# Armor
	if not GameManager.equipped_armor.is_empty():
		armor_label.text = CardPresenter.get_display_name(GameManager.equipped_armor)
		armor_stat.text = tr("UI_ARMOR_DEFENSE") % [int(GameManager.equipped_armor.get("power", 0)), int(GameManager.equipped_armor.get("damage_reduction", 1))]
		armor_slot.modulate = Color(1.0, 1.0, 1.0)
		armor_unequip_btn.visible = true
		armor_unequip_btn.disabled = false
	else:
		armor_label.text = tr("[ Empty ]")
		armor_stat.text = tr("Drag armor here")
		armor_slot.modulate = Color(0.7, 0.7, 0.7)
		armor_unequip_btn.visible = false
		armor_unequip_btn.disabled = true

	# Amulet
	if not GameManager.equipped_amulet.is_empty():
		amulet_label.text = CardPresenter.get_display_name(GameManager.equipped_amulet)
		if GameManager.equipped_amulet.has("dice_bonus"):
			amulet_stat.text = tr("+%d to dice") % int(GameManager.equipped_amulet.dice_bonus)
		else:
			amulet_stat.text = tr("+1 reroll")
		amulet_slot.modulate = Color(1.0, 1.0, 1.0)
		amulet_unequip_btn.visible = true
		amulet_unequip_btn.disabled = false
	else:
		amulet_label.text = tr("[ Empty ]")
		amulet_stat.text = tr("Drag an amulet here")
		amulet_slot.modulate = Color(0.7, 0.7, 0.7)
		amulet_unequip_btn.visible = false
		amulet_unequip_btn.disabled = true
