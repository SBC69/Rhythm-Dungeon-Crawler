extends PanelContainer

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.get("type", "") == "card":
		var card = data.get("card_data", {})
		if int(card.get("type", -1)) == CardDatabase.CardType.WEAPON:
			modulate = Color(1.2, 1.4, 1.2) # Green highlight
			return true
	modulate = Color(1.0, 1.0, 1.0)
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	modulate = Color(1.0, 1.0, 1.0)
	if data is Dictionary and data.get("type", "") == "card":
		var card = data.get("card_data", {})
		if int(card.get("type", -1)) == CardDatabase.CardType.WEAPON:
			GameManager.equip_card_to_slot(card, CardDatabase.CardType.WEAPON)
			SoundManager.play_anvil()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = Color(1.0, 1.0, 1.0)
