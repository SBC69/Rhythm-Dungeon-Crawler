# scripts/domain/village_state.gd
class_name VillageState
extends RefCounted

var balance: BalanceConfig

func _init(config: BalanceConfig = null) -> void:
	balance = config
	if balance == null:
		balance = BalanceConfig.new()
		balance.load_from_file()

var stages: Dictionary = {
	"square": 0,
	"houses": 0,
	"chronicler": 0,
	"marketplace": 0,
	"forge": 0,
	"alchemist": 0
}

var revisions: Dictionary = {
	"square": 0,
	"houses": 0,
	"chronicler": 0,
	"marketplace": 0,
	"forge": 0,
	"alchemist": 0
}

var has_returned_from_dungeon: bool = false
var unlocked_dungeon_ids: Array = ["crypts"]
var defeated_final_boss_ids: Array = []
var selected_cosmetics: Dictionary = {
	"hero": "default",
	"cards": "default",
	"dice": "default",
	"village": "default"
}

func get_stage(object_id: String) -> int:
	return int(stages.get(object_id, 0))

func get_next_cost(object_id: String) -> int:
	var cur_stage = get_stage(object_id)
	if cur_stage >= 3:
		return -1
	var prices = balance.get_village_object_prices(object_id)
	return int(prices[cur_stage]) if cur_stage < prices.size() else -1

func is_prerequisite_met(object_id: String) -> bool:
	for required in balance.get_village_object_prerequisites(object_id):
		if get_stage(str(required.id)) < int(required.stage):
			return false
	return true

func can_restore(object_id: String, available_gold: int) -> bool:
	if not stages.has(object_id):
		return false
	var cur_stage = get_stage(object_id)
	if cur_stage >= 3:
		return false
	if not is_prerequisite_met(object_id):
		return false
	var cost = get_next_cost(object_id)
	return available_gold >= cost

func restore_object(object_id: String, available_gold: int) -> Dictionary:
	if not can_restore(object_id, available_gold):
		return {"success": false, "cost": 0, "new_stage": get_stage(object_id)}
	var cost = get_next_cost(object_id)
	var next_stage = get_stage(object_id) + 1
	stages[object_id] = next_stage
	revisions[object_id] = int(revisions.get(object_id, 0)) + 1
	return {"success": true, "cost": cost, "new_stage": next_stage}

func serialize() -> Dictionary:
	return {
		"stages": stages.duplicate(true),
		"revisions": revisions.duplicate(true),
		"has_returned_from_dungeon": has_returned_from_dungeon,
		"unlocked_dungeon_ids": unlocked_dungeon_ids.duplicate(true),
		"defeated_final_boss_ids": defeated_final_boss_ids.duplicate(true),
		"selected_cosmetics": selected_cosmetics.duplicate(true)
	}

func deserialize(data: Dictionary) -> void:
	if data.has("stages") and data["stages"] is Dictionary:
		for k in stages.keys():
			if data["stages"].has(k):
				stages[k] = int(data["stages"][k])
	if data.has("revisions") and data["revisions"] is Dictionary:
		for k in revisions.keys():
			if data["revisions"].has(k):
				revisions[k] = int(data["revisions"][k])
	has_returned_from_dungeon = bool(data.get("has_returned_from_dungeon", false))
	if data.has("unlocked_dungeon_ids") and data["unlocked_dungeon_ids"] is Array:
		unlocked_dungeon_ids = data["unlocked_dungeon_ids"].duplicate()
	if data.has("defeated_final_boss_ids") and data["defeated_final_boss_ids"] is Array:
		defeated_final_boss_ids = data["defeated_final_boss_ids"].duplicate()
	if data.has("selected_cosmetics") and data["selected_cosmetics"] is Dictionary:
		selected_cosmetics = data["selected_cosmetics"].duplicate(true)
