extends SceneTree

var leaves: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

# Only immutable context/configuration is shared. Every mutable branch is copied.
func branch(state: FloorRoutes) -> FloorRoutes:
	var result = FloorRoutes.new()
	result.context = state.context
	result.balance_snapshot = state.balance_snapshot
	result.floor_number = state.floor_number
	result.current_depth = state.current_depth
	result.revision = state.revision
	result.initial_counts = state.initial_counts
	result.remaining_counts = state.remaining_counts.duplicate(true)
	result.current_choices = state.current_choices.duplicate(true)
	result.completed_rooms = state.completed_rooms.duplicate(true)
	result.boss_encounter = state.boss_encounter.duplicate(true)
	result.rng.state = state.rng.state
	return result

func complete(state: FloorRoutes, slot: int) -> bool:
	var selected = state.select_door(slot)
	if selected.is_empty():
		return false
	if selected.kind != "trap":
		state.set_encounter_status(selected.encounter_id, "defeated_waiting_loot")
	return state.commit_room_completion(selected.encounter_id).get("success", false)

func walk(state: FloorRoutes) -> void:
	if state.current_depth == 10:
		leaves += 1
		for kind in state.remaining_counts:
			if int(state.remaining_counts[kind]) != 0:
				failures += 1
		var counts = {"regular": 0, "elite": 0, "trap": 0}
		for room in state.completed_rooms:
			counts[room.kind] += 1
			if room.kind == "elite" and (int(room.room) < 4 or int(room.room) > 9):
				failures += 1
		for kind in counts:
			if int(counts[kind]) != int(state.initial_counts[kind]):
				failures += 1
		return
	for slot in range(3):
		var next = branch(state)
		if complete(next, slot):
			walk(next)
		else:
			failures += 1

func _run() -> void:
	var partition = 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			partition = int(arg.trim_prefix("--mode="))
	for floor_num in [1, 2]:
		var random = RandomNumberGenerator.new()
		random.seed = 41
		var state = FloorRoutes.create({"run_id": "paths", "mode": "timed", "dungeon_id": "crypts", "dungeon_index": 1, "floor_number": floor_num}, {}, random)
		if not complete(state, int(partition / 3)) or not complete(state, partition % 3):
			failures += 1
		else:
			walk(state)
	if leaves != 4374:
		failures += 1
	print("PATHS partition=%d leaves=%d failures=%d" % [partition, leaves, failures])
	quit(1 if failures > 0 else 0)
