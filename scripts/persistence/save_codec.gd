# scripts/persistence/save_codec.gd
class_name SaveCodec
extends RefCounted

const CURRENT_SCHEMA_VERSION: int = 3

static func create_default_profile() -> Dictionary:
	return {
		"profile_version": 1,
		"wallet_gold": 40,
		"has_returned_from_dungeon": false,
		"unlocked_dungeon_ids": ["crypts"],
		"defeated_final_boss_ids": [],
		"processed_unlock_events": [],
		"village_object_stages": {
			"square": 0,
			"houses": 0,
			"chronicler": 0,
			"marketplace": 0,
			"forge": 0,
			"alchemist": 0
		},
		"village_object_revisions": {
			"square": 0,
			"houses": 0,
			"chronicler": 0,
			"marketplace": 0,
			"forge": 0,
			"alchemist": 0
		},
		"campaign_equipment": {
			"weapon": {},
			"armor": {},
			"amulet": {}
		},
		"run_history": [],
		"memory_unlocks": [],
		"selected_cosmetics": {
			"hero": "default",
			"cards": "default",
			"dice": "default",
			"village": "default"
		},
		"best_records": {
			"timed": {},
			"endless": {}
		},
		"settings": {
			"locale": "ru",
			"ui_scale": 1.0,
			"sound_volume": 1.0
		}
	}

static func encode_envelope(profile: Dictionary, active_run: Dictionary = {}, meta: Dictionary = {}) -> Dictionary:
	var envelope := {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"profile": profile.duplicate(true),
		"active_run": active_run.duplicate(true),
		"meta": meta.duplicate(true)
	}
	return envelope

static func decode_envelope(json_str: String) -> Dictionary:
	var parser := JSON.new()
	var err := parser.parse(json_str)
	if err != OK:
		return {"error": "JSON parse failed: %s at line %d" % [parser.get_error_message(), parser.get_error_line()]}
	
	var data = parser.get_data()
	if not (data is Dictionary):
		return {"error": "Root JSON must be a Dictionary"}
	
	return validate_and_migrate(data as Dictionary)

static func validate_and_migrate(envelope: Dictionary) -> Dictionary:
	envelope = envelope.duplicate(true)
	var ver = int(envelope.get("schema_version", 0))
	if ver <= 0 or ver > CURRENT_SCHEMA_VERSION:
		return {"error": "Unsupported schema_version: %d" % ver}
	
	if not envelope.has("profile") or not (envelope["profile"] is Dictionary):
		return {"error": "Envelope missing profile dictionary"}
	
	var profile: Dictionary = envelope["profile"]
	if int(profile.get("wallet_gold", 0)) < 0:
		return {"error": "Invalid negative wallet gold"}

	# Validate village stages
	var stages = profile.get("village_object_stages")
	if stages is Dictionary:
		for b_name in stages.keys():
			var s = int(stages[b_name])
			if s < 0 or s > 3:
				return {"error": "Invalid village stage for %s: %d" % [b_name, s]}

	if ver < 3:
		var ar = envelope.get("active_run", {})
		if ar is Dictionary and not ar.is_empty():
			if not ar.has("floor_state"):
				ar["floor_state"] = _create_legacy_v1_floor_state(maxi(1, int(ar.get("floor", 1))), mini(10, maxi(1, int(ar.get("room", 1)))), ar)
			else:
				var fs = ar["floor_state"]
				if fs is Dictionary and int(fs.get("generation_version", 0)) == 1:
					_fill_legacy_data(fs, ar)
			if not ar.has("floor"):
				ar["floor"] = ar["floor_state"].get("floor_number", 1)
			if not ar.has("room"):
				ar["room"] = ar["floor_state"].get("current_depth", 1)
			var floor_state = ar["floor_state"]
			if floor_state.get("completed_rooms", []).size() == 10:
				floor_state["current_choices"] = []
				floor_state["selected_encounter_id"] = ""
				floor_state["boss_encounter"]["status"] = "completed"
			if not ar.has("controller"):
				var ctl = {"phase": "REST" if floor_state.get("completed_rooms", []).size() == 10 else "CORRIDOR", "pending_loot": [], "resolution_committed": false}
				for c in ar["floor_state"].get("current_choices", []):
					if c.get("status") in ["active", "defeated_waiting_loot"]:
						ctl["current_encounter"] = c.get("data", {}).duplicate(true)
						ctl["current_encounter"]["kind"] = c.get("kind", "regular")
						ctl["current_encounter"]["encounter_id"] = c["encounter_id"]
						ctl["encounter_id"] = c["encounter_id"]
						ctl["resolution_committed"] = c.status == "defeated_waiting_loot"
						ctl["phase"] = "LOOT" if c.status == "defeated_waiting_loot" else ("CURSE" if c.kind == "trap" else "COMBAT")
				ar["controller"] = ctl
			if ar["controller"].get("phase") == "LOOT" and ar["controller"].get("pending_loot", []).is_empty():
				ar["controller"]["recover_legacy_loot"] = true
			ar["phase"] = ar["controller"].get("phase", "CORRIDOR")
		envelope["schema_version"] = CURRENT_SCHEMA_VERSION

	# Validate active run if present
	if envelope.has("active_run"):
		if not (envelope["active_run"] is Dictionary):
			return {"error": "active_run must be a Dictionary"}
		var active_run: Dictionary = envelope["active_run"]
		if not active_run.is_empty():
			if active_run.has("mode"):
				var mode_str = str(active_run["mode"])
				if not (mode_str in ["TIMED_100", "ENDLESS", "timed_100", "endless"]):
					return {"error": "Invalid mode in active_run: %s" % mode_str}
			if active_run.has("gold") and int(active_run["gold"]) < 0:
				return {"error": "Invalid negative gold in active_run"}
			if active_run.has("hp") and int(active_run["hp"]) < 0:
				return {"error": "Invalid negative hp in active_run"}
			if active_run.has("player_hp") and int(active_run["player_hp"]) < 0:
				return {"error": "Invalid negative player_hp in active_run"}
			if active_run.has("phase"):
				var valid_phases = ["CORRIDOR", "TRANSITION", "COMBAT", "ESCAPE", "CURSE", "LOOT", "REST", "SHOP", "FINISHED"]
				var phase_str = str(active_run["phase"])
				if not valid_phases.has(phase_str):
					return {"error": "Invalid phase in active_run: %s" % phase_str}
			var seen_instance_ids: Array[String] = []
			if active_run.has("hand") and (active_run["hand"] is Array):
				for card in active_run["hand"]:
					if card is Dictionary and card.has("instance_id"):
						var iid = str(card["instance_id"])
						if seen_instance_ids.has(iid):
							return {"error": "Duplicate instance_id: %s" % iid}
						seen_instance_ids.append(iid)
			if active_run.has("equipment") and (active_run["equipment"] is Dictionary):
				for eq_slot in active_run["equipment"].values():
					if eq_slot is Dictionary and eq_slot.has("instance_id"):
						var iid = str(eq_slot["instance_id"])
						if seen_instance_ids.has(iid):
							return {"error": "Duplicate instance_id across containers: %s" % iid}
						seen_instance_ids.append(iid)
			if active_run.has("floor_stash") and (active_run["floor_stash"] is Array):
				for card in active_run["floor_stash"]:
					if card is Dictionary and card.has("instance_id"):
						var iid = str(card["instance_id"])
						if seen_instance_ids.has(iid):
							return {"error": "Duplicate instance_id across containers: %s" % iid}
						seen_instance_ids.append(iid)

			if not active_run.has("floor_state") or not active_run["floor_state"] is Dictionary:
				return {"error": "Missing floor_state"}
			var floor_error = FloorRoutes.validate_snapshot(active_run["floor_state"])
			if not floor_error.is_empty():
				return {"error": floor_error}
			var ctl = active_run.get("controller", {})
			if not ctl is Dictionary or not ctl.get("phase", "") in ["CORRIDOR", "TRANSITION", "COMBAT", "ESCAPE", "CURSE", "LOOT", "REST", "SHOP", "FINISHED"]:
				return {"error": "Missing or invalid controller phase"}
			if ctl.phase == "LOOT" and (str(ctl.get("encounter_id", "")).is_empty() or not ctl.get("resolution_committed", false)):
				return {"error": "Invalid pending loot state"}

			var fs_state = active_run.floor_state
			if not FloorRoutes._integer(active_run.get("floor")) or not FloorRoutes._integer(active_run.get("room")) or int(active_run.floor) != int(fs_state.floor_number) or int(active_run.room) != int(fs_state.current_depth):
				return {"error": "Run room and floor snapshot disagree"}
			if active_run.get("phase", ctl.phase) != ctl.phase:
				return {"error": "Run phase and controller disagree"}

			var selected = str(fs_state.get("selected_encounter_id", ""))
			if ctl.phase in ["TRANSITION", "COMBAT", "ESCAPE", "CURSE", "LOOT"]:
				if str(ctl.get("encounter_id", "")) != selected or selected.is_empty() or not ctl.get("current_encounter") is Dictionary or ctl.current_encounter.is_empty():
					return {"error": "Controller and selected encounter disagree"}
			if not selected.is_empty():
				var selected_choice = {}
				for c in fs_state.current_choices:
					if c.encounter_id == selected:
						selected_choice = c
				var expected_status = "defeated_waiting_loot" if ctl.phase == "LOOT" else "active"
				if selected_choice.get("status") != expected_status:
					return {"error": "Controller phase and encounter status disagree"}

			if ctl.phase == "CORRIDOR" and not selected.is_empty():
				return {"error": "Selected encounter in corridor"}
			if ctl.phase == "LOOT":
				if not ctl.get("pending_loot") is Array:
					return {"error": "Invalid pending loot options"}
				if ctl.pending_loot.is_empty() and not ctl.get("recover_legacy_loot", false):
					return {"error": "Missing pending loot options"}
				for card in ctl.pending_loot:
					if not card is Dictionary or str(card.get("instance_id", "")).is_empty() or seen_instance_ids.has(str(card.instance_id)):
						return {"error": "Invalid or duplicate pending loot instance"}
					seen_instance_ids.append(str(card.instance_id))

	# Migrate/fill default fields
	var default_prof = create_default_profile()
	for k in default_prof.keys():
		if not profile.has(k):
			profile[k] = default_prof[k]
		elif profile[k] is Dictionary and default_prof[k] is Dictionary:
			var sub_dict: Dictionary = profile[k]
			var def_sub: Dictionary = default_prof[k]
			for sub_k in def_sub.keys():
				if not sub_dict.has(sub_k):
					sub_dict[sub_k] = def_sub[sub_k]
	
	if not envelope.has("active_run") or not (envelope["active_run"] is Dictionary):
		envelope["active_run"] = {}
	
	return envelope

static func _create_legacy_v1_floor_state(f_num: int, r_num: int, active_run: Dictionary) -> Dictionary:
	var trap_depths: Array[int] = [3, 7]
	var elite_depth = -1
	if f_num >= 2:
		trap_depths = [2, 8]
		elite_depth = 5

	var completed: Array = []
	var reg_remain = 7 if f_num == 1 else 6
	var eli_remain = 0 if f_num == 1 else 1
	var trp_remain = 2

	for d in range(1, r_num):
		var kind = "regular"
		if trap_depths.has(d):
			kind = "trap"
			trp_remain = maxi(0, trp_remain - 1)
		elif d == elite_depth:
			kind = "elite"
			eli_remain = maxi(0, eli_remain - 1)
		else:
			reg_remain = maxi(0, reg_remain - 1)
		completed.append({
			"room": d,
			"kind": kind,
			"encounter_id": "legacy_f%d_r%d" % [f_num, d],
			"door_slot": 1
		})

	var run_id = str(active_run.get("run_id", "run_legacy"))
	var choices: Array = []
	if r_num < 10:
		for slot in [0, 1, 2]:
			var k = "regular"
			if trap_depths.has(r_num):
				k = "trap"
			elif r_num == elite_depth:
				k = "elite"
			choices.append({
				"door_slot": slot,
				"depth": r_num,
				"encounter_id": "%s_f%d_r%d_s%d" % [run_id, f_num, r_num, slot],
				"kind": k,
				"status": "pending",
				"data": {}
			})

	var state = {
		"generation_version": 1,
		"floor_number": f_num,
		"current_depth": r_num,
		"revision": 0,
		"initial_counts": {"regular": 7 if f_num == 1 else 6, "elite": 0 if f_num == 1 else 1, "trap": 2},
		"remaining_counts": {"regular": reg_remain, "elite": eli_remain, "trap": trp_remain},
		"current_choices": choices,
		"selected_encounter_id": "",
		"completed_rooms": completed,
		"boss_encounter": {
			"door_slot": 1,
			"encounter_id": "%s_f%d_boss" % [run_id, f_num],
			"kind": "boss",
			"status": "pending",
			"data": {}
		},
		"rng_state": "12345678",
		"context": {
			"run_id": run_id,
			"mode": str(active_run.get("mode", "timed")),
			"dungeon_id": str(active_run.get("dungeon_id", "crypts")),
			"floor_number": f_num
		},
		"balance_snapshot": {}
	}

	_fill_legacy_data(state, active_run)
	return state

static func _fill_legacy_data(state: Dictionary, active_run: Dictionary) -> void:
	var cfg = BalanceConfig.new()
	cfg.load_from_file()
	if state.get("balance_snapshot", {}).is_empty():
		state["balance_snapshot"] = cfg.config_data.duplicate(true)
	var ctx = state.get("context", {}).duplicate(true)
	ctx["dungeon_index"] = maxi(1, cfg.get_dungeon_order().find(ctx.get("dungeon_id", "crypts")) + 1)
	state["context"] = ctx
	var random = RandomNumberGenerator.new()
	random.state = int(state.get("rng_state", "12345678"))
	var entries = state.get("current_choices", []).duplicate()
	entries.append(state["boss_encounter"])
	for c in entries:
		if c.get("data", {}).is_empty():
			var encounter_ctx = ctx.duplicate(true)
			encounter_ctx["room_number"] = 10 if c.kind == "boss" else state.current_depth
			c["data"] = EncounterFactory.create_encounter(c.kind, encounter_ctx, random, state.balance_snapshot)
		c["depth"] = 10 if c.kind == "boss" else state.current_depth
	var saved = active_run.get("current_encounter", {})
	if saved is Dictionary and not saved.is_empty():
		var slot = clampi(int(saved.get("door_slot", active_run.get("current_route_id", 0))), 0, 2)
		for c in state.current_choices:
			if c.encounter_id == state.get("selected_encounter_id", "") or (state.get("selected_encounter_id", "").is_empty() and int(c.door_slot) == slot):
				c["data"] = saved.duplicate(true)
				c["encounter_id"] = str(saved.get("encounter_id", c.encounter_id))
				c["status"] = "defeated_waiting_loot" if active_run.get("phase") == "LOOT" else "active"
				state["selected_encounter_id"] = c.encounter_id
				break
	if int(state.current_depth) == 10 and state.current_choices.is_empty():
		state.current_choices = [state.boss_encounter.duplicate(true)]
	state["rng_state"] = str(random.state)
