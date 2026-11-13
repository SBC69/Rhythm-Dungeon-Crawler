# tests/helpers/game_fixture.gd
class_name GameFixture
extends RefCounted

var tree: SceneTree
var root: Window
var current_main: Node = null
var failures: Array[String] = []
var assertions_count: int = 0

func _init(p_tree: SceneTree) -> void:
	tree = p_tree
	root = p_tree.root

func assert_true(condition: bool, message: String = "") -> bool:
	assertions_count += 1
	if not condition:
		var err = "Assertion failed: expected true, got false. " + message
		failures.append(err)
		push_error(err)
		return false
	return true

func assert_false(condition: bool, message: String = "") -> bool:
	assertions_count += 1
	if condition:
		var err = "Assertion failed: expected false, got true. " + message
		failures.append(err)
		push_error(err)
		return false
	return true

func assert_eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	assertions_count += 1
	if actual != expected:
		var err = "Assertion failed: expected %s, got %s. %s" % [str(expected), str(actual), message]
		failures.append(err)
		push_error(err)
		return false
	return true

func assert_ne(actual: Variant, expected: Variant, message: String = "") -> bool:
	assertions_count += 1
	if actual == expected:
		var err = "Assertion failed: expected NOT %s, got %s. %s" % [str(expected), str(actual), message]
		failures.append(err)
		push_error(err)
		return false
	return true

func reset_game_state() -> void:
	var gm = root.get_node_or_null("/root/GameManager")
	if gm != null:
		if gm.save_store == null or gm.save_store.save_dir == "user://saves" or gm.save_store.base_dir == "user://saves":
			gm.save_store = SaveStore.new("user://test_saves")
		gm.player_profile = SaveCodec.create_default_profile()
		if gm.has_method("start_new_game"):
			gm.start_new_game()
		gm.is_shop_open = false
		if "floor_power_penalty" in gm:
			gm.floor_power_penalty = 0

func create_main(open_menu: bool = false) -> Node:
	if current_main != null and is_instance_valid(current_main):
		current_main.queue_free()
		current_main = null
		await tree.process_frame
		await tree.process_frame

	reset_game_state()
	var main_scene = load("res://scenes/main.tscn")
	current_main = main_scene.instantiate()
	root.add_child(current_main)
	await tree.process_frame
	await tree.process_frame
	if not open_menu:
		current_main._restore_screen()
	return current_main

func teardown() -> void:
	if current_main != null and is_instance_valid(current_main):
		current_main.queue_free()
		current_main = null
		await tree.process_frame
		await tree.process_frame
	reset_game_state()

func simulate_click(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	var center = control.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	root.push_input(motion, true)
	await tree.process_frame
	var press = InputEventMouseButton.new()
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = center
	press.global_position = center
	root.push_input(press, true)
	await tree.process_frame
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = center
	release.global_position = center
	root.push_input(release, true)

	await tree.process_frame

func simulate_key(keycode: Key, shift: bool = false) -> void:
	var press = InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	press.shift_pressed = shift
	root.push_input(press, true)
	
	var release = InputEventKey.new()
	release.keycode = keycode
	release.pressed = false
	release.shift_pressed = shift
	root.push_input(release, true)
	await tree.process_frame

func enter_regular_encounter(main: Node, power: int = 1) -> void:
	var gm = root.get_node("GameManager")
	var random = RandomNumberGenerator.new()
	random.seed = 42
	gm.floor_routes = FloorRoutes.create(gm.floor_routes.context, gm.floor_routes.balance_snapshot, random)
	var choice = gm.floor_routes.current_choices[0]
	choice.kind = "regular"
	choice.data = EncounterFactory.create_encounter("regular", gm.floor_routes.context, random, gm.floor_routes.balance_snapshot)
	choice.data.power = power
	var request = main.encounter_ctrl.request_door(0, gm.run_generation, gm.floor_routes.revision)
	assert_true(request.get("success", false), "accepted encounter fixture")
	main.encounter_ctrl.apply_door_transition(int(request.get("transition_token", -1)))
	main._show_encounter()
	await tree.process_frame
