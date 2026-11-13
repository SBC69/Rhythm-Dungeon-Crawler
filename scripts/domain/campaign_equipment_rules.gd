# scripts/domain/campaign_equipment_rules.gd
class_name CampaignEquipmentRules
extends RefCounted

static func record_victory_equipment(weapon: Dictionary, armor: Dictionary, amulet: Dictionary) -> Dictionary:
	return {
		"weapon": weapon.duplicate(true),
		"armor": armor.duplicate(true),
		"amulet": amulet.duplicate(true)
	}

static func clear_equipment() -> Dictionary:
	return {
		"weapon": {},
		"armor": {},
		"amulet": {}
	}

static func has_campaign_equipment(campaign_eq: Dictionary) -> bool:
	if campaign_eq.is_empty():
		return false
	return not campaign_eq.get("weapon", {}).is_empty() or not campaign_eq.get("armor", {}).is_empty() or not campaign_eq.get("amulet", {}).is_empty()
