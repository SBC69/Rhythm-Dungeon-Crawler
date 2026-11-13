extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _capture(name: String, bounds: Array = []) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	for control in bounds:
		if not screen.encloses(control.get_global_rect()):
			failures += 1
			print("FAIL: ", name, " ", control.name, " ", control.get_global_rect())
	if root.get_texture().get_image().save_png("res://visual-evidence/localization/" + name + ".png") != OK:
		failures += 1

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://visual-evidence/localization")
	root.position = Vector2i(-32000, -32000)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var settings = root.get_node("UserSettings")
	settings.config_path = "user://localization-visual-settings.cfg"
	var fix := GameFixture.new(self)
	var main = await fix.create_main(true)
	for locale in settings.LANGUAGES:
		settings.set_language(locale)
		main.router.show_main_menu()
		await _capture(locale + "-menu", [main.main_menu.content])
		var panel = main.main_menu.settings_panel
		panel.open()
		for page in ["controls", "display", "audio"]:
			panel.show_page(page)
			await _capture(locale + "-settings-" + page, [panel.panel, panel.close_button, panel.language_select])
		panel.language_select.show_popup()
		await _capture(locale + "-language-options")
		panel.language_select.get_popup().hide()
		panel.close()
		main.router.show_village_map()
		await _capture(locale + "-village")
		main.router.show_mode_select()
		await _capture(locale + "-mode", [main.mode_select.get_node("PanelContainer")])
		main._restore_screen()
		main.hud.update_hud()
		main.inventory_panel.open()
		await _capture(locale + "-inventory", [main.inventory_panel.panel])
		main.inventory_panel.close(false)
		await fix.enter_regular_encounter(main)
		await _capture(locale + "-combat", [main.monster_view.get_node("PanelContainer")])
		main.monster_view._start_rhythm()
		main.monster_view.rhythm_game.set_process(false)
		await _capture(locale + "-rhythm", [main.monster_view.get_node("PanelContainer")])
		main.monster_view._cancel_rhythm()
		main.router.show_rest_room()
		await _capture(locale + "-camp", [main.rest_room.get_node("PanelContainer")])
		main.router.open_shop()
		await _capture(locale + "-shop")
		main.router.close_shop()
		main = await fix.create_main(true)
	await fix.teardown()
	print("LOCALIZATION VISUAL failures=%d" % failures)
	quit(1 if failures > 0 else 0)
