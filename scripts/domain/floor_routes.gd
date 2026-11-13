# scripts/domain/floor_routes.gd
class_name FloorRoutes
extends RefCounted

const EncounterFactory = preload("res://scripts/domain/encounter_factory.gd")

var generation_version: int = 2
var floor_number: int = 1
var current_depth: int = 1 # 1..10
var revision: int = 0
var initial_counts: Dictionary = {"regular": 7, "elite": 0, "trap": 2}
var remaining_counts: Dictionary = {"regular": 7, "elite": 0, "trap": 2}
var current_choices: Array = [] # Array of Dictionary proposals for current_depth
var selected_encounter_id: String = ""
var completed_rooms: Array = [] # Array of {"room": int, "kind": String, "encounter_id": String}
var boss_encounter: Dictionary = {}
var rng_state: String = ""
var context: Dictionary = {}
var balance_snapshot: Dictionary = {}
var rng: RandomNumberGenerator

# Legacy compatibility fields
var locked_route_id: int = -1
var routes: Dictionary = {}

func _init(p_floor: int = -1, p_rng: RandomNumberGenerator = null) -> void:
	if p_rng != null:
		rng = p_rng
	else:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	# If p_floor is provided (> 0), set up with default context
	if p_floor > 0:
		floor_number = p_floor
		_init_default_floor()

func _init_default_floor() -> void:
	generation_version = 2
	current_depth = 1
	revision = 0
	locked_route_id = -1
	completed_rooms.clear()
	selected_encounter_id = ""

	if balance_snapshot.is_empty():
		var cfg = BalanceConfig.new()
		if cfg.load_from_file():
			balance_snapshot = cfg.config_data.duplicate(true)

	if context.is_empty():
		context = {
			"run_id": "run_%d" % rng.randi(),
			"mode": "timed",
			"dungeon_id": "crypts",
			"dungeon_index": 1,
			"floor_number": floor_number
		}

	var rooms_before_boss = int(balance_snapshot.get("floor", {}).get("rooms_before_boss", 9))
	if floor_number == 1:
		initial_counts = balance_snapshot.get("floor", {}).get("first_floor", {"regular": 7, "elite": 0, "trap": 2}).duplicate(true)
	else:
		initial_counts = balance_snapshot.get("floor", {}).get("later_floors", {"regular": 6, "elite": 1, "trap": 2}).duplicate(true)
	remaining_counts = initial_counts.duplicate(true)

	_generate_boss_encounter()
	_generate_choices_for_depth(current_depth)
	_build_legacy_routes_cache()
	rng_state = str(rng.state)

static func create(p_context: Dictionary, p_balance_snapshot: Dictionary = {}, p_rng: RandomNumberGenerator = null) -> FloorRoutes:
	var fr = FloorRoutes.new(-1, p_rng)
	fr.generation_version = 2
	fr.context = p_context.duplicate(true)
	fr.floor_number = maxi(1, int(p_context.get("floor_number", 1)))
	fr.current_depth = 1
	fr.revision = 0
	fr.locked_route_id = -1
	fr.completed_rooms = []
	fr.selected_encounter_id = ""

	if p_balance_snapshot.is_empty():
		var cfg = BalanceConfig.new()
		if cfg.load_from_file():
			fr.balance_snapshot = cfg.config_data.duplicate(true)
	else:
		fr.balance_snapshot = p_balance_snapshot.duplicate(true)

	if fr.floor_number == 1:
		fr.initial_counts = fr.balance_snapshot.get("floor", {}).get("first_floor", {"regular": 7, "elite": 0, "trap": 2}).duplicate(true)
	else:
		fr.initial_counts = fr.balance_snapshot.get("floor", {}).get("later_floors", {"regular": 6, "elite": 1, "trap": 2}).duplicate(true)
	fr.remaining_counts = fr.initial_counts.duplicate(true)

	fr._generate_boss_encounter()
	fr._generate_choices_for_depth(fr.current_depth)
	fr._build_legacy_routes_cache()
	fr.rng_state = str(fr.rng.state)
	return fr

func _repeat_final_clear() -> bool:
	return bool(context.get("final_boss_defeated", false)) and str(context.get("mode", "")).to_lower() != "endless" and floor_number >= int(balance_snapshot.modes.timed.floor_limit)

func _generate_boss_encounter() -> void:
	if _repeat_final_clear():
		boss_encounter = {}
		return
	var boss_ctx = context.duplicate(true)
	boss_ctx["floor_number"] = floor_number
	boss_ctx["room_number"] = 10
	var boss_data = EncounterFactory.create_encounter("boss", boss_ctx, rng, balance_snapshot)
	var run_id = str(context.get("run_id", "run"))
	boss_encounter = {
		"door_slot": 1,
		"encounter_id": "%s_f%d_boss" % [run_id, floor_number],
		"kind": "boss",
		"status": "pending",
		"data": boss_data
	}

func _generate_choices_for_depth(depth: int) -> void:
	current_choices.clear()
	var run_id = str(context.get("run_id", "run"))

	if depth >= 10:
		if boss_encounter.is_empty():
			return
		# Boss room offers single central door (slot 1)
		var b_choice = boss_encounter.duplicate(true)
		b_choice["depth"] = depth
		current_choices = [b_choice]
		return

	var elite_min = int(balance_snapshot.get("floor", {}).get("elite_room_min", 4))
	var elite_max = int(balance_snapshot.get("floor", {}).get("elite_room_max", 9))
	var normal_door_count = int(balance_snapshot.get("floor", {}).get("normal_door_count", 3))

	for slot in range(normal_door_count):
		# Eligible kinds with remaining_count > 0
		var eligible_kinds: Array[String] = []
		var weights: Array[int] = []

		for k in ["regular", "elite", "trap"]:
			var count = int(remaining_counts.get(k, 0))
			if count <= 0:
				continue
			if k == "elite" and (depth < elite_min or depth > elite_max):
				continue
			eligible_kinds.append(k)
			weights.append(count)

		var chosen_kind = "regular"
		if generation_version == 1:
			var trap_rooms = [3, 7] if floor_number == 1 else [2, 8]
			chosen_kind = "trap" if depth in trap_rooms else ("elite" if floor_number > 1 and depth == 5 else "regular")
		elif not eligible_kinds.is_empty():
			chosen_kind = str(EncounterFactory.pick_by_weight(eligible_kinds, weights, rng))

		var enc_ctx = context.duplicate(true)
		enc_ctx["floor_number"] = floor_number
		enc_ctx["room_number"] = depth
		enc_ctx["door_slot"] = slot

		var enc_data = EncounterFactory.create_encounter(chosen_kind, enc_ctx, rng, balance_snapshot)
		var enc_id = "%s_f%d_r%d_s%d" % [run_id, floor_number, depth, slot]

		current_choices.append({
			"door_slot": slot,
			"depth": depth,
			"encounter_id": enc_id,
			"kind": chosen_kind,
			"status": "pending",
			"data": enc_data
		})

func get_current_choices() -> Array:
	# Reading must never regenerate a cleared boss or alter a saved offer.
	return current_choices.duplicate(true)

func get_choice_by_slot(slot: int) -> Dictionary:
	for c in current_choices:
		if int(c.get("door_slot", -1)) == slot:
			return c.duplicate(true)
	return {}

func get_choice_by_id(enc_id: String) -> Dictionary:
	for c in current_choices:
		if str(c.get("encounter_id", "")) == enc_id:
			return c.duplicate(true)
	if str(boss_encounter.get("encounter_id", "")) == enc_id:
		return boss_encounter.duplicate(true)
	return {}

func select_door(door_slot: int) -> Dictionary:
	for i in range(current_choices.size()):
		if int(current_choices[i].get("door_slot", -1)) == door_slot:
			var c = current_choices[i]
			if not selected_encounter_id.is_empty() or c.get("status") != "pending":
				return {}
			c["status"] = "active"
			selected_encounter_id = str(c.get("encounter_id", ""))
			revision += 1
			rng_state = str(rng.state)
			return c.duplicate(true)
	return {}

func set_encounter_status(enc_id: String, new_status: String) -> bool:
	for i in range(current_choices.size()):
		if str(current_choices[i].get("encounter_id", "")) == enc_id:
			current_choices[i]["status"] = new_status
			revision += 1
			rng_state = str(rng.state)
			return true
	if str(boss_encounter.get("encounter_id", "")) == enc_id:
		boss_encounter["status"] = new_status
		revision += 1
		rng_state = str(rng.state)
		return true
	return false

func commit_room_completion(enc_id: String) -> Dictionary:
	if enc_id.is_empty() or selected_encounter_id != enc_id:
		return {"success": false, "reason": "Encounter is not selected"}
	for done in completed_rooms:
		if done.get("encounter_id") == enc_id:
			return {"success": false, "reason": "Already completed"}
	var selected = get_choice_by_id(enc_id)
	var expected_status = "active" if selected.get("kind") == "trap" else "defeated_waiting_loot"
	if selected.get("status") != expected_status:
		return {"success": false, "reason": "Invalid completion status"}
	# Locate encounter
	var kind = ""
	var slot = -1
	for c in current_choices:
		if str(c.get("encounter_id", "")) == enc_id:
			kind = str(c.get("kind", ""))
			slot = int(c.get("door_slot", -1))
			break
	if kind.is_empty() and str(boss_encounter.get("encounter_id", "")) == enc_id:
		kind = "boss"
		slot = 1

	if kind.is_empty():
		return {"success": false, "reason": "Encounter ID not found in current choices"}

	# Deduct quota for regular/elite/trap
	if remaining_counts.has(kind):
		remaining_counts[kind] = maxi(0, int(remaining_counts[kind]) - 1)

	completed_rooms.append({
		"room": current_depth,
		"kind": kind,
		"encounter_id": enc_id,
		"door_slot": slot
	})

	revision += 1
	selected_encounter_id = ""

	if current_depth < 10:
		current_depth += 1
		_generate_choices_for_depth(current_depth)
		_build_legacy_routes_cache()
	else:
		boss_encounter["status"] = "completed"
		current_choices.clear()

	rng_state = str(rng.state)
	return {"success": true, "new_depth": current_depth, "kind": kind}

func _build_legacy_routes_cache() -> void:
	# Keep legacy routes dictionary populated for old tests / inspectors
	routes.clear()
	for r in [0, 1, 2]:
		routes[r] = {}

	for c in current_choices:
		var slot = int(c.get("door_slot", 0))
		var k = str(c.get("kind", "regular"))
		var type_str = "monster"
		if k == "trap":
			type_str = "curse"

		var rec = {
			"route_id": slot,
			"depth": current_depth,
			"status": c.get("status", "pending"),
			"type": type_str,
			"data": c.get("data", {}),
			"encounter_id": c.get("encounter_id", "")
		}
		routes[slot][current_depth] = rec

# Legacy methods
func is_route_locked() -> bool:
	if generation_version == 1:
		return locked_route_id != -1
	return false

func lock_route(route_id: int) -> void:
	if generation_version == 1:
		if locked_route_id == -1:
			locked_route_id = route_id

func get_active_route_id(door_index: int) -> int:
	if generation_version == 1 and is_route_locked():
		return locked_route_id
	return maxi(0, mini(2, door_index - 1))

func get_encounter(route_id: int, depth: int) -> Dictionary:
	if depth >= 10:
		return boss_encounter.get("data", boss_encounter)

	if depth == current_depth:
		for c in current_choices:
			if int(c.get("door_slot", -1)) == route_id:
				var k = str(c.get("kind", "regular"))
				var type_str = "curse" if k == "trap" else "monster"
				var ret = {
					"route_id": route_id,
					"depth": depth,
					"status": c.get("status", "pending"),
					"type": type_str,
					"data": c.get("data", {}),
					"encounter_id": c.get("encounter_id", "")
				}
				# Copy data fields to top level for legacy readers
				for dk in c.get("data", {}):
					ret[dk] = c["data"][dk]
				return ret

	if routes.has(route_id) and routes[route_id].has(depth):
		return routes[route_id][depth]

	return {}

func mark_encounter_completed(route_id: int, depth: int) -> void:
	if depth < 10:
		if routes.has(route_id) and routes[route_id].has(depth):
			routes[route_id][depth]["status"] = "completed"
		if generation_version == 1:
			lock_route(route_id)
	elif depth >= 10:
		boss_encounter["status"] = "completed"

func advance_room() -> void:
	if current_depth < 10:
		current_depth += 1

func serialize() -> Dictionary:
	return {
		"generation_version": generation_version,
		"floor_number": floor_number,
		"current_depth": current_depth,
		"revision": revision,
		"initial_counts": initial_counts.duplicate(true),
		"remaining_counts": remaining_counts.duplicate(true),
		"current_choices": current_choices.duplicate(true),
		"selected_encounter_id": selected_encounter_id,
		"completed_rooms": completed_rooms.duplicate(true),
		"boss_encounter": boss_encounter.duplicate(true),
		"rng_state": str(rng.state),
		"context": context.duplicate(true),
		"balance_snapshot": balance_snapshot.duplicate(true)
	}

static func _integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))

static func validate_snapshot(s: Dictionary) -> String:
	for key in ["generation_version", "floor_number", "current_depth", "revision"]:
		if not _integer(s.get(key)):
			return key + " must be an integer"
	if int(s.generation_version) not in [1, 2] or int(s.floor_number) < 1 or int(s.revision) < 0:
		return "Invalid floor metadata"
	var depth = int(s.current_depth)
	if depth < 1 or depth > 10:
		return "Invalid current_depth"
	for key in ["context", "balance_snapshot", "initial_counts", "remaining_counts", "boss_encounter"]:
		if not s.get(key) is Dictionary:
			return key + " must be a Dictionary"
	if s.balance_snapshot.is_empty() or not s.balance_snapshot.get("floor") is Dictionary:
		return "Missing balance_snapshot.floor"
	for key in ["first_floor", "later_floors"]:
		if not s.balance_snapshot.floor.get(key) is Dictionary:
			return "Missing balance floor counts"
	if int(s.context.get("floor_number", -1)) != int(s.floor_number) or not _integer(s.context.get("dungeon_index")) or int(s.context.dungeon_index) < 1:
		return "Invalid encounter context"
	if str(s.context.get("dungeon_id", "")).is_empty():
		return "Missing dungeon_id"
	if not s.get("completed_rooms") is Array or not s.get("current_choices") is Array:
		return "Invalid completed_rooms or current_choices"
	var rng_text = s.get("rng_state")
	if not rng_text is String or not rng_text.is_valid_int() or str(int(rng_text)) != rng_text:
		return "Invalid rng_state string"
	var totals = {"regular": 0, "elite": 0, "trap": 0}
	for k in totals:
		for counts in [s.initial_counts, s.remaining_counts]:
			if not _integer(counts.get(k)) or int(counts[k]) < 0:
				return "Invalid nonnegative quota: " + k
	var expected_counts = s.balance_snapshot.floor.first_floor if int(s.floor_number) == 1 else s.balance_snapshot.floor.later_floors
	for k in totals:
		if int(s.initial_counts[k]) != int(expected_counts[k]):
			return "Initial counts differ from balance snapshot"
	var seen = {}
	var boss_done = false
	for i in range(s.completed_rooms.size()):
		var c = s.completed_rooms[i]
		if not c is Dictionary or not _integer(c.get("room")) or int(c.room) != i + 1:
			return "Invalid completed room order"
		if not _integer(c.get("door_slot")) or int(c.door_slot) < 0 or int(c.door_slot) > 2:
			return "Invalid completed door slot"
		var id = c.get("encounter_id", "")
		if not id is String or id.is_empty() or seen.has(id):
			return "Duplicate or empty completed encounter ID"
		seen[id] = true
		if int(c.room) == 10 and c.get("kind") == "boss":
			boss_done = true
		elif totals.has(c.get("kind")) and int(c.room) < 10:
			totals[c.kind] += 1
		else:
			return "Invalid completed kind"
	for k in totals:
		if int(s.remaining_counts[k]) != int(s.initial_counts[k]) - int(totals[k]):
			return "Remaining quota mismatch: " + k
	if depth != mini(10, s.completed_rooms.size() + 1):
		return "Depth does not match completed rooms"
	var repeat_done = depth == 10 and s.boss_encounter.is_empty() and s.context.get("final_boss_defeated", false) and str(s.context.get("mode", "")).to_lower() != "endless" and int(s.floor_number) >= int(s.balance_snapshot.get("modes", {}).get("timed", {}).get("floor_limit", 100))
	var expected_size = 0 if boss_done or repeat_done else (1 if depth == 10 else 3)
	if s.current_choices.size() != expected_size:
		return "Invalid number of current choices"
	if not s.boss_encounter.is_empty():
		var boss = s.boss_encounter
		if str(boss.get("encounter_id", "")).is_empty() or boss.get("kind") != "boss" or not boss.get("data") is Dictionary or boss.data.is_empty():
			return "Invalid boss snapshot"
		if seen.has(boss.encounter_id) and not boss_done:
			return "Boss ID collides with a completed ordinary room"
	elif not (s.context.get("final_boss_defeated", false) and str(s.context.get("mode", "")).to_lower() != "endless" and int(s.floor_number) >= int(s.balance_snapshot.get("modes", {}).get("timed", {}).get("floor_limit", 100))):
		return "Missing boss snapshot"
	var slots = {}
	var selected = str(s.get("selected_encounter_id", ""))
	var found_selected = selected.is_empty()
	for c in s.current_choices:
		if not c is Dictionary or not _integer(c.get("door_slot")):
			return "Invalid door slot"
		var slot = int(c.door_slot)
		if slot < 0 or slot > 2 or slots.has(slot) or (depth == 10 and slot != 1):
			return "Duplicate or invalid door slot"
		slots[slot] = true
		var id = c.get("encounter_id", "")
		if not id is String or id.is_empty() or seen.has(id):
			return "Duplicate or empty current encounter ID"
		seen[id] = true
		if int(c.get("depth", -1)) != depth or not c.get("data") is Dictionary or c.data.is_empty():
			return "Missing encounter parameters or incorrect depth"
		if c.get("kind") == "trap" and c.get("status") == "defeated_waiting_loot":
			return "Trap cannot await monster loot"
		if c.get("status") not in ["pending", "active", "defeated_waiting_loot"]:
			return "Invalid encounter status"
		if depth == 10:
			if c.get("kind") != "boss" or c.encounter_id != s.boss_encounter.get("encounter_id"):
				return "Invalid boss choice"
		elif not totals.has(c.get("kind")) or int(s.remaining_counts[c.kind]) <= 0:
			return "Choice kind exceeds remaining quota"
		if id == selected:
			found_selected = c.status in ["active", "defeated_waiting_loot"]
		elif c.status != "pending":
			return "Unselected encounter is not pending"
	if not found_selected:
		return "Selected encounter not found"
	return ""

static func from_snapshot(snapshot: Dictionary) -> Dictionary:
	var error = validate_snapshot(snapshot)
	if not error.is_empty():
		return {"success": false, "state": null, "error": error}
	var fr = FloorRoutes.new(-1, null)
	for key in ["generation_version", "floor_number", "current_depth", "revision"]:
		fr.set(key, int(snapshot[key]))
	for key in ["initial_counts", "remaining_counts", "context", "balance_snapshot", "boss_encounter"]:
		fr.set(key, snapshot[key].duplicate(true))
	fr.current_choices = snapshot.current_choices.duplicate(true)
	fr.selected_encounter_id = str(snapshot.get("selected_encounter_id", ""))
	fr.completed_rooms = snapshot.completed_rooms.duplicate(true)
	fr.rng_state = snapshot.rng_state
	fr.rng.state = int(fr.rng_state)
	fr._build_legacy_routes_cache()
	return {"success": true, "state": fr, "error": ""}

static func _sanitize_encounter_data(data: Dictionary) -> Dictionary:
	var res = data.duplicate(true)
	for int_key in ["power", "base_power", "archetype_offset", "q", "dc", "damage_on_fail", "power_penalty"]:
		if res.has(int_key):
			res[int_key] = int(res[int_key])
	return res
