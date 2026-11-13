extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://visual-evidence/" + name + ".png")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://visual-evidence")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i.ZERO
	var fix := GameFixture.new(self)
	var main = await fix.create_main(true)
	await capture("main-menu")
	var gm = root.get_node("GameManager")
	gm.start_new_game(RunMode.Mode.ENDLESS)
	main.encounter_ctrl.restore({})
	main.router.show_main_menu()
	await capture("main-menu-continue")
	if not Rect2(Vector2.ZERO, Vector2(root.size)).encloses(main.main_menu.content.get_global_rect()):
		print("FAIL: menu does not fit the viewport")
		quit(1)
		return
	await fix.teardown()
	print("MAIN MENU VISUAL failures=0")
	quit(0)
