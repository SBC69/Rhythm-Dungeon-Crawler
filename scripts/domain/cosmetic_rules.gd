# scripts/domain/cosmetic_rules.gd
class_name CosmeticRules
extends RefCounted

const COSMETICS_MAP: Dictionary = {
	"hero_road_cloak": {"category": "hero", "stage": 1},
	"hero_village_guard": {"category": "hero", "stage": 1},
	"cards_oak": {"category": "cards", "stage": 2},
	"cards_starlight": {"category": "cards", "stage": 2},
	"dice_bone": {"category": "dice", "stage": 2},
	"dice_copper": {"category": "dice", "stage": 2},
	"village_warm_evening": {"category": "village", "stage": 3},
	"village_fair": {"category": "village", "stage": 3}
}

static func is_cosmetic_available(cosmetic_id: String, marketplace_stage: int) -> bool:
	if cosmetic_id == "default":
		return true
	if not COSMETICS_MAP.has(cosmetic_id):
		return false
	var required_stage = int(COSMETICS_MAP[cosmetic_id]["stage"])
	return marketplace_stage >= required_stage

static func select_cosmetic(selected_dict: Dictionary, category: String, cosmetic_id: String, marketplace_stage: int) -> Dictionary:
	var result = selected_dict.duplicate(true)
	if not is_cosmetic_available(cosmetic_id, marketplace_stage):
		return result
	if cosmetic_id != "default" and COSMETICS_MAP[cosmetic_id]["category"] != category:
		return result
	result[category] = cosmetic_id
	return result
