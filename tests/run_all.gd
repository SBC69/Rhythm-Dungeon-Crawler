# tests/run_all.gd
extends SceneTree

const GameFixtureScript = preload("res://tests/helpers/game_fixture.gd")
const TestInventoryScript = preload("res://tests/cases/test_inventory.gd")
const TestRunInventoryScript = preload("res://tests/cases/test_run_inventory.gd")
const TestEncountersScript = preload("res://tests/cases/test_encounters.gd")
const TestEnemyRosterScript = preload("res://tests/cases/test_enemy_roster.gd")
const TestRhythmScript = preload("res://tests/cases/test_rhythm.gd")
const TestRhythmEquipmentScript = preload("res://tests/cases/test_rhythm_equipment.gd")
const TestUIScript = preload("res://tests/cases/test_ui.gd")
const TestSettingsScript = preload("res://tests/cases/test_settings.gd")
const TestAudioScript = preload("res://tests/cases/test_audio.gd")
const TestModesAndPersistenceScript = preload("res://tests/cases/test_modes_and_persistence.gd")

var _started := false
var registry: Dictionary = {}

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run_suite.call_deferred()
	return false

func _build_registry() -> void:
	registry.clear()
	TestInventoryScript.register_tests(registry)
	TestRunInventoryScript.register_tests(registry)
	TestEncountersScript.register_tests(registry)
	TestEnemyRosterScript.register_tests(registry)
	TestRhythmScript.register_tests(registry)
	TestRhythmEquipmentScript.register_tests(registry)
	TestUIScript.register_tests(registry)
	TestSettingsScript.register_tests(registry)
	TestAudioScript.register_tests(registry)
	TestModesAndPersistenceScript.register_tests(registry)
	
	# Diagnostic test to verify exit=1 on intentional assertion failure
	registry["FAIL-INTENTIONAL"] = {
		"fn": Callable(self, "_test_intentional_failure"),
		"expected_failure": false,
		"desc": "Intentional assertion failure to verify runner exit=1"
	}

func _test_intentional_failure(fix: RefCounted) -> void:
	fix.assert_true(false, "Intentional failure probe for runner verification")

func _parse_args() -> Dictionary:
	var parsed := {
		"mode": "none",
		"case_id": "",
		"strict": false
	}
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var arg := args[i]
		if arg == "--all":
			parsed["mode"] = "all"
		elif arg == "--case":
			parsed["mode"] = "case"
			if i + 1 < args.size():
				parsed["case_id"] = args[i + 1]
				i += 1
		elif arg == "--strict":
			parsed["strict"] = true
		i += 1
	return parsed

func _run_suite() -> void:
	_build_registry()
	var parsed := _parse_args()
	
	print("====================================================")
	print(" Dungeon of Cards — Test Suite Runner")
	print(" Mode: %s, Case: %s" % [parsed["mode"], parsed["case_id"] if parsed["case_id"] != "" else "ALL"])
	print("====================================================")
	
	var cases_to_run: Array[String] = []
	if parsed["mode"] == "all":
		for id in registry.keys():
			if id != "FAIL-INTENTIONAL":
				cases_to_run.append(id)
	elif parsed["mode"] == "case":
		var target_id: String = parsed["case_id"]
		if not registry.has(target_id):
			print("[ERROR] Unknown test case ID: '%s'" % target_id)
			print("Available cases: ", registry.keys())
			quit(1)
			return
		cases_to_run.append(target_id)
	else:
		print("[ERROR] No test target specified. Use '--all' or '--case <ID>'")
		quit(1)
		return
	
	if cases_to_run.is_empty():
		print("[ERROR] Zero tests selected to run.")
		quit(1)
		return
	
	var passed_count := 0
	var failed_count := 0
	var expected_fail_count := 0
	
	var log_file_path := ""
	var cmd_args := OS.get_cmdline_args()
	for idx in range(cmd_args.size()):
		if cmd_args[idx] == "--log-file" and idx + 1 < cmd_args.size():
			log_file_path = cmd_args[idx + 1]
			break

	for test_id in cases_to_run:
		var entry: Dictionary = registry[test_id]
		var callable: Callable = entry["fn"]
		var is_expected_fail: bool = entry.get("expected_failure", false) and not parsed["strict"]
		var desc: String = entry.get("desc", "")
		
		var fix = GameFixtureScript.new(self)
		print("\n[RUNNING] %s: %s" % [test_id, desc])
		
		var log_offset := 0
		if not log_file_path.is_empty() and FileAccess.file_exists(log_file_path):
			var lf_pre = FileAccess.open(log_file_path, FileAccess.READ)
			if lf_pre != null:
				log_offset = lf_pre.get_length()
				lf_pre.close()

		# Execute test callable
		await callable.call(fix)
		await process_frame
		
		if not log_file_path.is_empty() and FileAccess.file_exists(log_file_path):
			var lf_post = FileAccess.open(log_file_path, FileAccess.READ)
			if lf_post != null:
				if lf_post.get_length() > log_offset:
					lf_post.seek(log_offset)
					var new_log = lf_post.get_as_text()
					if "SCRIPT ERROR:" in new_log:
						fix.failures.append("Runtime script error detected in engine log")
				lf_post.close()

		if fix.assertions_count == 0:
			fix.failures.append("Test executed zero assertions")

		var has_failures = fix.failures.size() > 0
		if not has_failures:
			if entry.get("expected_failure", false):
				print(" [PASS] %s (Defect was fixed or target passed!)" % test_id)
			else:
				print(" [PASS] %s" % test_id)
			passed_count += 1
		else:
			if is_expected_fail:
				print(" [EXPECTED_FAIL] %s — Known baseline defect reproduced:" % test_id)
				for f in fix.failures:
					print("    -> %s" % f)
				expected_fail_count += 1
			else:
				print(" [FAIL] %s — Unexpected assertion failure:" % test_id)
				for f in fix.failures:
					print("    -> %s" % f)
				failed_count += 1
	
	print("\n====================================================")
	print(" Results Summary:")
	print("  Total executed : %d" % cases_to_run.size())
	print("  Passed         : %d" % passed_count)
	print("  Expected Fails : %d" % expected_fail_count)
	print("  Failed         : %d" % failed_count)
	print("====================================================")
	
	if failed_count > 0:
		print("STATUS: FAILED (exit code 1)")
		quit(1)
	else:
		print("STATUS: SUCCESS (exit code 0)")
		quit(0)
