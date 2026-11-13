extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://visual-evidence/" + name + ".png") != OK:
		failures += 1

func _inside(control: Control, description: String) -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	if not screen.encloses(control.get_global_rect()):
		failures += 1
		print("FAIL: ", description, " bounds ", control.get_global_rect())

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://visual-evidence")
	root.position = Vector2i(-32000, -32000)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var settings = root.get_node("UserSettings")
	settings.config_path = "user://visual-settings.cfg"
	var fix := GameFixture.new(self)
	var main = await fix.create_main(true)
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		var suffix := "%dx%d" % [size.x, size.y]
		await _capture("settings-menu-" + suffix)
		_inside(main.main_menu.content, "main menu")
		main.main_menu.settings_panel.open()
		var panel = main.main_menu.settings_panel
		for page in ["controls", "display", "audio"]:
			panel.show_page(page)
			await _capture("settings-" + page + "-" + suffix)
			_inside(panel.panel, "settings panel")
			_inside(panel.close_button, "settings close button")
		panel.close()
	var gm = root.get_node("GameManager")
	gm.start_new_game(RunMode.Mode.ENDLESS)
	main.encounter_ctrl.restore({})
	main.router.show_main_menu()
	root.size = Vector2i(1280, 720)
	await _capture("settings-menu-continue-1280x720")
	_inside(main.main_menu.content, "main menu with a saved run")
	main._restore_screen()
	await fix.enter_regular_encounter(main)
	main.monster_view._start_rhythm()
	var rhythm = main.monster_view.rhythm_game
	rhythm.set_process(false)
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		await _capture("settings-rhythm-hints-%dx%d" % [size.x, size.y])
		_inside(main.monster_view.get_node("PanelContainer"), "rhythm panel")
		_inside(rhythm.controls_hint, "rhythm key hints")
		_inside(rhythm.timing_hint, "rhythm timing hint")
		_inside(rhythm.guard_button, "rhythm guard action")
	settings.rebind("rhythm_attack", settings.key_event(KEY_F))
	settings.rebind("rhythm_guard", settings.key_event(KEY_G))
	root.size = Vector2i(1280, 720)
	await _capture("settings-rhythm-custom-keys")
	# Exercise the real window resize API and its saved selection.
	var requested := Vector2i(1280, 720)
	if requested in settings.available_resolutions():
		settings.set_resolution(requested)
		root.position = Vector2i(-32000, -32000)
		await process_frame
		if root.size != requested:
			failures += 1
			print("FAIL: real window resolution did not change: ", root.size)
	await fix.teardown()
	print("SETTINGS VISUAL failures=%d" % failures)
	quit(1 if failures > 0 else 0)
