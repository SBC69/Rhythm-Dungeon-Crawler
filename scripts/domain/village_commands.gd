# scripts/domain/village_commands.gd
class_name VillageCommands
extends RefCounted

static func execute_restore(village_state: VillageState, profile: Dictionary, object_id: String, expected_stage: int, expected_revision: int = -1, expected_price: int = -1) -> Dictionary:
	var cur_stage = village_state.get_stage(object_id)
	if cur_stage != expected_stage:
		return {"success": false, "reason": "Stage mismatch (stale token)"}
	
	if expected_revision >= 0 and int(village_state.revisions.get(object_id, -1)) != expected_revision:
		return {"success": false, "reason": "Revision mismatch"}
	if expected_price >= 0 and village_state.get_next_cost(object_id) != expected_price:
		return {"success": false, "reason": "Price mismatch"}
	var current_gold = int(profile.get("wallet_gold", 0))
	var res = village_state.restore_object(object_id, current_gold)
	if not res["success"]:
		return {"success": false, "reason": "Requirements not met or insufficient gold"}
	
	var cost = int(res["cost"])
	profile["wallet_gold"] = current_gold - cost
	profile["village_object_stages"] = village_state.stages.duplicate(true)
	profile["village_object_revisions"] = village_state.revisions.duplicate(true)
	
	return {
		"success": true,
		"cost": cost,
		"new_stage": res["new_stage"],
		"remaining_gold": profile["wallet_gold"]
	}
