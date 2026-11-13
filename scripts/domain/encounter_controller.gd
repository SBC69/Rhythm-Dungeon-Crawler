# scripts/domain/encounter_controller.gd
class_name EncounterController
extends RefCounted

enum RunPhase {
	CORRIDOR,
	TRANSITION,
	COMBAT,
	ESCAPE,
	CURSE,
	LOOT,
	REST,
	SHOP,
	FINISHED
}

signal phase_changed(new_phase: RunPhase)
signal encounter_started(phase: RunPhase, encounter_data: Dictionary)
signal encounter_resolved(outcome: Dictionary)
signal room_advanced(floor_num: int, room_num: int)

var phase: RunPhase = RunPhase.CORRIDOR
var current_encounter: Dictionary = {}
var encounter_id: String = ""
var resolution_committed: bool = false
var combat_input_locked: bool = false
var active_transition_token: int = 0
var recover_legacy_loot: bool = false
var pending_loot: Array = []
var captured_generation: int = -1
var rng: RandomNumberGenerator

func _init(p_rng: RandomNumberGenerator = null) -> void:
	if p_rng != null:
		rng = p_rng
	else:
		rng = RandomNumberGenerator.new()
		rng.randomize()

func snapshot() -> Dictionary:
	return {"recover_legacy_loot": recover_legacy_loot, "phase": RunPhase.keys()[phase], "current_encounter": current_encounter.duplicate(true), "encounter_id": encounter_id, "resolution_committed": resolution_committed, "pending_loot": pending_loot.duplicate(true), "active_transition_token": active_transition_token}

func restore(state: Dictionary) -> void:
	combat_input_locked = false
	recover_legacy_loot = bool(state.get("recover_legacy_loot", false))
	phase = RunPhase.get(str(state.get("phase", "CORRIDOR")), RunPhase.CORRIDOR)
	current_encounter = state.get("current_encounter", {}).duplicate(true)
	encounter_id = str(state.get("encounter_id", ""))
	resolution_committed = bool(state.get("resolution_committed", false))
	pending_loot = state.get("pending_loot", []).duplicate(true)
	active_transition_token = maxi(active_transition_token + 1, int(state.get("active_transition_token", 0)) + 1)
	captured_generation = -1

func set_phase(new_phase: RunPhase) -> void:
	phase = new_phase
	phase_changed.emit(phase)

func _get_gm() -> Node:
	var main_loop = Engine.get_main_loop()
	if main_loop != null and "root" in main_loop and main_loop.root != null:
		return main_loop.root.get_node_or_null("GameManager")
	return null

func can_interact_with_cards() -> bool:
	return not combat_input_locked and phase in [RunPhase.CORRIDOR, RunPhase.COMBAT, RunPhase.ESCAPE, RunPhase.CURSE, RunPhase.REST]

func can_open_shop() -> bool:
	return phase == RunPhase.REST

func request_door(door_slot: int, expected_generation: int = -1, expected_floor_revision: int = -1) -> Dictionary:
	var gm = _get_gm()
	if phase != RunPhase.CORRIDOR:
		return {"success": false, "encounter": {}, "transition_token": 0, "reason": "Not in CORRIDOR phase"}
	if expected_generation >= 0 and gm != null and int(gm.get("run_generation")) != expected_generation:
		return {"success": false, "encounter": {}, "transition_token": 0, "reason": "Run generation mismatch"}
	if gm == null or gm.get("floor_routes") == null:
		return {"success": false, "encounter": {}, "transition_token": 0, "reason": "No floor routes"}
	var fr = gm.get("floor_routes")
	if expected_floor_revision >= 0 and int(fr.get("revision")) != expected_floor_revision:
		return {"success": false, "encounter": {}, "transition_token": 0, "reason": "Floor revision mismatch"}

	var before = gm.begin_run_command()
	var chosen = fr.select_door(door_slot)
	if chosen.is_empty():
		gm.cancel_run_command(before)
		return {"success": false, "encounter": {}, "transition_token": 0, "reason": "Invalid door slot or encounter"}

	captured_generation = int(gm.run_generation)
	active_transition_token += 1
	var token = active_transition_token
	phase = RunPhase.TRANSITION

	resolution_committed = false
	encounter_id = str(chosen.get("encounter_id", ""))
	current_encounter = chosen.get("data", {}).duplicate(true)
	current_encounter["encounter_id"] = encounter_id
	current_encounter["door_slot"] = door_slot
	current_encounter["kind"] = chosen.get("kind", "")

	if not gm.finish_run_command(before):
		return {"success": false, "reason": "Save failed"}
	phase_changed.emit(phase)
	return {
		"success": true,
		"encounter": current_encounter,
		"transition_token": token,
		"reason": ""
	}

func apply_door_transition(token: int) -> bool:
	if phase != RunPhase.TRANSITION or token != active_transition_token or _get_gm() == null or captured_generation != int(_get_gm().run_generation):
		return false

	var kind = str(current_encounter.get("kind", ""))
	if kind == "trap":
		set_phase(RunPhase.CURSE)
	else:
		set_phase(RunPhase.COMBAT)

	encounter_started.emit(phase, current_encounter)
	return true

func _get_mdb() -> Node:
	var main_loop = Engine.get_main_loop()
	if main_loop != null and "root" in main_loop and main_loop.root != null:
		return main_loop.root.get_node_or_null("MonsterDatabase")
	return null

func start_room_encounter(is_boss: bool, floor_num: int, room_num: int, forced_type: String = "", forced_data: Dictionary = {}) -> Dictionary:
	resolution_committed = false
	if forced_data.has("encounter_id") and not str(forced_data["encounter_id"]).is_empty():
		encounter_id = str(forced_data["encounter_id"])
	else:
		encounter_id = "enc_%d_%d_%d_%d" % [floor_num, room_num, Time.get_ticks_msec(), rng.randi()]

	if not forced_data.is_empty():
		current_encounter = forced_data.duplicate(true)
		current_encounter["encounter_id"] = encounter_id
		if forced_type == "monster" or forced_type == "boss":
			set_phase(RunPhase.COMBAT)
		elif forced_type == "curse":
			set_phase(RunPhase.CURSE)
		encounter_started.emit(phase, current_encounter)
		return current_encounter

	var mdb = _get_mdb()
	if is_boss:
		if mdb != null and mdb.has_method("get_monster_for_room"):
			current_encounter = mdb.get_monster_for_room(floor_num, room_num).duplicate(true)
		current_encounter["encounter_id"] = encounter_id
		set_phase(RunPhase.COMBAT)
	else:
		var roll = rng.randf()
		if roll < 0.75:
			if mdb != null and mdb.has_method("get_monster_for_room"):
				current_encounter = mdb.get_monster_for_room(floor_num, room_num).duplicate(true)
			current_encounter["encounter_id"] = encounter_id
			set_phase(RunPhase.COMBAT)
		else:
			if mdb != null and mdb.has_method("get_random_curse"):
				current_encounter = mdb.get_random_curse(floor_num).duplicate(true)
			current_encounter["encounter_id"] = encounter_id
			set_phase(RunPhase.CURSE)

	encounter_started.emit(phase, current_encounter)
	return current_encounter

func commit_monster_defeat(enc_id: String) -> bool:
	if phase != RunPhase.COMBAT or resolution_committed or enc_id != encounter_id:
		return false
	var gm = _get_gm()
	if gm == null:
		return false
	var before = gm.begin_run_command()
	resolution_committed = true
	gm.monsters_slain_total += 1
	gm.floor_routes.set_encounter_status(encounter_id, "defeated_waiting_loot")
	var cfg = gm.floor_routes.balance_snapshot
	var q = EncounterFactory.calculate_q_for_context(gm.floor_routes.context, cfg)
	var rewards = cfg["economy"]["gold_per_victory"]
	var g = int(rewards["base"]) + int(q / int(rewards["depth_divisor"]))
	var multiplier = int(rewards["boss_multiplier"]) if current_encounter.get("is_boss", false) else (int(rewards["elite_multiplier"]) if current_encounter.get("is_elite", false) else int(rewards["regular_multiplier"]))
	gm.player_gold += g * multiplier
	pending_loot = gm.get_node("../CardDatabase").get_random_loot_cards(gm.current_floor, 3)
	phase = RunPhase.LOOT
	if not gm.finish_run_command(before):
		return false
	phase_changed.emit(phase)
	encounter_resolved.emit({"type": "monster_defeat", "encounter_id": encounter_id, "monster": current_encounter, "gold_reward": g * multiplier})
	return true

func resolve_rhythm_failure(enc_id: String, raw_damage: int) -> bool:
	var gm = _get_gm()
	if gm == null or phase != RunPhase.COMBAT or resolution_committed or enc_id != encounter_id or gm.is_game_over:
		return false
	var before = gm.begin_run_command()
	var reduction := int(gm.equipped_armor.get("damage_reduction", 0))
	gm.player_hp = int(CombatRules.calculate_damage(raw_damage, reduction, gm.player_hp).remaining_hp)
	if not gm.floor_routes.set_encounter_status(encounter_id, "pending"):
		return gm.cancel_run_command(before)
	# Release the selection without generating another set of doors or changing depth.
	gm.floor_routes.selected_encounter_id = ""
	gm.temp_combat_power_buff = 0
	pending_loot.clear()
	current_encounter.clear()
	encounter_id = ""
	combat_input_locked = false
	active_transition_token += 1
	phase = RunPhase.FINISHED if gm.player_hp <= 0 else RunPhase.CORRIDOR
	if not gm.finish_run_command(before):
		return false
	phase_changed.emit(phase)
	if gm.player_hp <= 0:
		gm.is_game_over = true
		gm.game_over_triggered.emit(false)
	return true

func commit_room_completion(enc_id: String, expected_floor_revision: int = -1) -> Dictionary:
	var gm = _get_gm()
	if gm == null or gm.get("floor_routes") == null:
		return {"success": false, "next_screen": "", "reason": "No floor routes"}
	var fr = gm.get("floor_routes")
	if expected_floor_revision >= 0 and int(fr.get("revision")) != expected_floor_revision:
		return {"success": false, "next_screen": "", "reason": "Floor revision mismatch"}
	if not enc_id.is_empty() and not encounter_id.is_empty() and enc_id != encounter_id:
		return {"success": false, "next_screen": "", "reason": "Encounter ID mismatch"}

	var res = fr.commit_room_completion(enc_id)
	if not res.get("success", false):
		return {"success": false, "next_screen": "", "reason": res.get("reason", "commit failed")}

	return {
		"success": true,
		"new_depth": res.get("new_depth", 1),
		"kind": res.get("kind", "")
	}

func request_escape(enc_id: String) -> bool:
	if resolution_committed or phase != RunPhase.COMBAT:
		return false
	if not enc_id.is_empty() and enc_id != encounter_id:
		return false
	set_phase(RunPhase.ESCAPE)
	return true

func resolve_escape(success: bool, raw_damage: int = 0) -> bool:
	if phase != RunPhase.ESCAPE:
		return false
	var gm = _get_gm()
	var before = gm.begin_run_command()
	if not success and raw_damage > 0:
		var reduction = int(gm.equipped_armor.get("damage_reduction", 0))
		gm.player_hp = int(CombatRules.calculate_damage(raw_damage, reduction, gm.player_hp)["remaining_hp"])
		if gm.player_hp <= 0:
			gm.suppress_saves = false
			gm.set_block_signals(bool(before.get("signals_were_blocked", false)))
			gm.is_game_over = true
			phase = RunPhase.FINISHED
			gm.game_over_triggered.emit(false)
			return true
	resolution_committed = false
	gm.floor_routes.set_encounter_status(encounter_id, "pending")
	gm.floor_routes.selected_encounter_id = ""
	gm.temp_combat_power_buff = 0
	phase = RunPhase.CORRIDOR
	if not gm.finish_run_command(before):
		return false
	encounter_resolved.emit({"type": "escape", "success": success})
	return true

func resolve_curse(raw_damage: int = 0, drain: int = 0) -> bool:
	if phase != RunPhase.CURSE or resolution_committed:
		return false
	var gm = _get_gm()
	var before = gm.begin_run_command()
	var reduction = int(gm.equipped_armor.get("damage_reduction", 0))
	gm.player_hp = int(CombatRules.calculate_damage(raw_damage, reduction, gm.player_hp)["remaining_hp"])
	gm.floor_power_penalty += drain
	if gm.player_hp <= 0:
		gm.suppress_saves = false
		gm.set_block_signals(bool(before.get("signals_were_blocked", false)))
		gm.is_game_over = true
		phase = RunPhase.FINISHED
		gm.game_over_triggered.emit(false)
		return true
	var res = commit_room_completion(encounter_id)
	if not res.get("success", false):
		return gm.cancel_run_command(before)
	resolution_committed = true
	gm.advance_room()
	phase = RunPhase.CORRIDOR
	return gm.finish_run_command(before)

func resolve_loot_selection(was_boss: bool, card: Dictionary = {}) -> bool:
	if phase != RunPhase.LOOT or pending_loot.is_empty() or not pending_loot.has(card):
		return false
	var gm = _get_gm()
	var before = gm.begin_run_command()
	var res = commit_room_completion(encounter_id)
	if not res.get("success", false):
		return gm.cancel_run_command(before)
	gm.floor_stash.append(card.duplicate(true))
	pending_loot.clear()
	gm.advance_room()
	phase = RunPhase.REST if was_boss else RunPhase.CORRIDOR
	if was_boss:
		gm.completed_floors += 1
		gm.unlock_floor_stash()
	return gm.finish_run_command(before)
