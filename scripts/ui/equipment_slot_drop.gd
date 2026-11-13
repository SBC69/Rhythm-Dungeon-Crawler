extends PanelContainer

@export var slot_type: int = 0 # 0: Weapon, 1: Armor, 2: Amulet

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.get("type", "") == "card":
		var card = data.get("card_data", {})
		if int(card.get("type", -1)) == slot_type:
			modulate = Color(1.2, 1.5, 1.2) # Green highlight
			return true
	modulate = Color(1.3, 0.7, 0.7) # Red invalid
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	modulate = Color(1.0, 1.0, 1.0)
	if data is Dictionary and data.get("type", "") == "card":
		var card = data.get("card_data", {})
		GameManager.equip_card_to_slot(card, slot_type)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = Color(1.0, 1.0, 1.0)
