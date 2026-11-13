# scripts/domain/chronicle_rules.gd
class_name ChronicleRules
extends RefCounted

const MAX_HISTORY_ENTRIES: int = 10

static func add_run_record(history: Array, record: Dictionary) -> Array:
	var updated = history.duplicate(true)
	
	# Verify duplicate run_id is not added twice
	var target_run_id = str(record.get("run_id", ""))
	if not target_run_id.is_empty():
		for existing in updated:
			if str(existing.get("run_id", "")) == target_run_id:
				return updated

	updated.append(record.duplicate(true))
	if updated.size() > MAX_HISTORY_ENTRIES:
		updated.pop_front()
	return updated

static func can_compare_runs(run_a: Dictionary, run_b: Dictionary) -> bool:
	if run_a.is_empty() or run_b.is_empty():
		return false
	var mode_a = str(run_a.get("mode", ""))
	var mode_b = str(run_b.get("mode", ""))
	var dung_a = str(run_a.get("dungeon_id", ""))
	var dung_b = str(run_b.get("dungeon_id", ""))
	return (mode_a == mode_b) and (dung_a == dung_b)

static func evaluate_memory_unlocks(profile: Dictionary, current_event: Dictionary) -> Array:
	var unlocked: Array = profile.get("memory_unlocks", []).duplicate()
	var comp_floors = int(current_event.get("completed_floors", 0))
	var is_success = (str(current_event.get("outcome", "")) == "SUCCESS")
	var is_next_dungeon = bool(current_event.get("is_next_dungeon", false))

	if comp_floors >= 1 and not ("memory_first_floor" in unlocked):
		unlocked.append("memory_first_floor")

	if is_success and not ("memory_final_boss" in unlocked):
		unlocked.append("memory_final_boss")

	if is_next_dungeon and not ("memory_next_dungeon" in unlocked):
		unlocked.append("memory_next_dungeon")

	return unlocked
