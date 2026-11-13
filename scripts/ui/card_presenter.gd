# scripts/ui/card_presenter.gd
class_name CardPresenter
extends RefCounted

static func get_display_name(card: Dictionary) -> String:
	var key := "CARD_" + str(card.get("id", "")).to_upper()
	var translated := TranslationServer.translate(key)
	var level := int(card.get("upgrade_level", 0))
	var base_name := str(card.get("base_name", card.get("name", "Card")))
	if level > 0:
		base_name = base_name.trim_suffix(" +%d" % level)
	var display_name := translated if translated != key else TranslationServer.translate(base_name)
	return "%s +%d" % [display_name, level] if level > 0 else display_name

static func get_type_title(card: Dictionary) -> String:
	var c_type = int(card.get("type", CardDatabase.CardType.BUFF))
	match c_type:
		CardDatabase.CardType.WEAPON:
			return TranslationServer.translate("[ WEAPON ]")
		CardDatabase.CardType.ARMOR:
			return TranslationServer.translate("[ ARMOR ]")
		CardDatabase.CardType.POTION:
			return TranslationServer.translate("[ POTION ]")
		CardDatabase.CardType.BUFF:
			return TranslationServer.translate("[ BUFF SCROLL ]")
		CardDatabase.CardType.AMULET:
			return TranslationServer.translate("[ LUCK AMULET ]")
	return TranslationServer.translate("[ ITEM ]")

static func get_type_color(card: Dictionary) -> Color:
	var c_type = int(card.get("type", CardDatabase.CardType.BUFF))
	match c_type:
		CardDatabase.CardType.WEAPON:
			return Color(1.0, 0.7, 0.4)
		CardDatabase.CardType.ARMOR:
			return Color(0.6, 0.8, 1.0)
		CardDatabase.CardType.POTION:
			return Color(0.4, 1.0, 0.5)
		CardDatabase.CardType.BUFF:
			return Color(0.9, 0.5, 1.0)
		CardDatabase.CardType.AMULET:
			return Color(1.0, 0.9, 0.4)
	return Color(0.8, 0.8, 0.8)

static func get_stat_badge_text(card: Dictionary) -> String:
	var c_type = int(card.get("type", CardDatabase.CardType.BUFF))
	match c_type:
		CardDatabase.CardType.WEAPON:
			return TranslationServer.translate("UI_WEAPON_ATTACK") % int(card.get("power", 0))
		CardDatabase.CardType.ARMOR:
			return TranslationServer.translate("UI_ARMOR_DEFENSE") % [int(card.get("power", 0)), int(card.get("damage_reduction", 1))]
		CardDatabase.CardType.POTION:
			return "+%d HP" % int(card.get("heal", 15))
		CardDatabase.CardType.BUFF:
			return TranslationServer.translate("+%d IN BATTLE") % int(card.get("power_buff", 3))
		CardDatabase.CardType.AMULET:
			if card.has("dice_bonus"):
				return TranslationServer.translate("+%d TO DICE") % int(card.get("dice_bonus", 2))
			else:
				return TranslationServer.translate("+%d REROLL") % int(card.get("extra_reroll", 1))
	return ""

static func get_stat_badge_color(card: Dictionary) -> Color:
	var c_type = int(card.get("type", CardDatabase.CardType.BUFF))
	match c_type:
		CardDatabase.CardType.WEAPON:
			return Color(1.0, 0.4, 0.3)
		CardDatabase.CardType.ARMOR:
			return Color(0.4, 0.7, 1.0)
		CardDatabase.CardType.POTION:
			return Color(0.3, 1.0, 0.4)
		CardDatabase.CardType.BUFF:
			return Color(0.8, 0.4, 1.0)
		CardDatabase.CardType.AMULET:
			return Color(1.0, 0.85, 0.3)
	return Color(1.0, 1.0, 1.0)

static func get_description(card: Dictionary) -> String:
	var description := _get_base_description(card)
	var properties := RhythmEquipment.describe(card)
	return description if properties.is_empty() else description + "\n" + properties

static func get_compact_description(card: Dictionary) -> String:
	var description := _get_base_description(card)
	var properties := RhythmEquipment.compact_description(card)
	# The stat badge already shows power/armor/dice; reserve this space for both affixes.
	return description if properties.is_empty() else properties

static func _get_base_description(card: Dictionary) -> String:
	var c_type = int(card.get("type", CardDatabase.CardType.BUFF))
	match c_type:
		CardDatabase.CardType.WEAPON:
			var u = int(card.get("upgrade_level", 0))
			if u > 0:
				return TranslationServer.translate("UI_WEAPON_ATTACK_UPGRADED") % [int(card.get("power", 0)), u]
			return TranslationServer.translate("UI_WEAPON_ATTACK") % int(card.get("power", 0))
		CardDatabase.CardType.ARMOR:
			return TranslationServer.translate("UI_ARMOR_DEFENSE") % [int(card.get("power", 0)), int(card.get("damage_reduction", 1))]
		CardDatabase.CardType.POTION:
			return TranslationServer.translate("Restores +%d HP (consumable)") % int(card.get("heal", 15))
		CardDatabase.CardType.BUFF:
			return TranslationServer.translate("UI_ATTACK_BUFF") % int(card.get("power_buff", 3))
		CardDatabase.CardType.AMULET:
			if card.has("dice_bonus"):
				return TranslationServer.translate("+%d to escape and saving rolls") % int(card.get("dice_bonus", 2))
			else:
				return TranslationServer.translate("+%d extra free rerolls") % int(card.get("extra_reroll", 1))
	return str(card.get("description", ""))

static func get_rarity_text(card: Dictionary) -> String:
	var rarity = int(card.get("rarity", CardDatabase.Rarity.COMMON))
	match rarity:
		CardDatabase.Rarity.COMMON:
			return TranslationServer.translate("Common")
		CardDatabase.Rarity.UNCOMMON:
			return TranslationServer.translate("Uncommon")
		CardDatabase.Rarity.RARE:
			return TranslationServer.translate("Rare")
		CardDatabase.Rarity.LEGENDARY:
			return TranslationServer.translate("Legendary")
	return TranslationServer.translate("Common")

static func get_rarity_color(card: Dictionary) -> Color:
	var rarity = int(card.get("rarity", CardDatabase.Rarity.COMMON))
	match rarity:
		CardDatabase.Rarity.COMMON:
			return Color(0.7, 0.7, 0.8)
		CardDatabase.Rarity.UNCOMMON:
			return Color(0.3, 0.8, 0.4)
		CardDatabase.Rarity.RARE:
			return Color(0.3, 0.6, 1.0)
		CardDatabase.Rarity.LEGENDARY:
			return Color(1.0, 0.7, 0.1)
	return Color(0.7, 0.7, 0.8)

static func get_sell_price_text(card: Dictionary) -> String:
	return TranslationServer.translate("UI_PRICE_GOLD") % int(card.get("sell_value", 15))

static func get_count_text(card: Dictionary) -> String:
	var cnt = int(card.get("count", 1))
	return "x%d" % cnt if cnt > 1 else ""

static func get_tooltip_text(card: Dictionary) -> String:
	if card.is_empty():
		return ""
	var name_str = get_display_name(card)
	var type_str = get_type_title(card)
	var rar_str = get_rarity_text(card)
	var desc_str = get_description(card)
	var price_str = get_sell_price_text(card)
	return TranslationServer.translate("%s %s\nRarity: %s\n%s\nSell price: %s") % [name_str, type_str, rar_str, desc_str, price_str]
