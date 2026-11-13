extends SceneTree

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var picture = root.get_texture().get_image()
	if picture == null or picture.is_empty() or picture.save_png("res://visual-evidence/" + name + ".png") != OK:
		failures += 1
		print("FAIL: screenshot " + name)
	else:
		print("PASS: screenshot " + name)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://visual-evidence")
	var gm = root.get_node("GameManager")
	gm.player_profile["active_endless_run"] = false
	gm.start_new_game()
	gm.player_profile.wallet_gold = 5000
	for id in ["square", "houses", "chronicler", "marketplace", "forge", "alchemist"]:
		gm.player_profile.village_object_stages[id] = 0
		gm.player_profile.village_object_revisions[id] = 0
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.router.show_village_map()
	var village = main.village_map
	root.content_scale_size = Vector2i.ZERO
	for viewport in [Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = viewport
		for factor in [1.0, 2.0, 3.0]:
			var prefix = "%dx%d-%d" % [viewport.x, viewport.y, int(factor * 100)]
			village.close_detail_modal()
			village.set_text_scale(factor)
			await capture(prefix + "-map")
			village.open_detail_modal("square")
			await capture(prefix + "-detail")
			village._on_restore_pressed()
			await capture(prefix + "-confirm")
			if not village.confirm_modal.visible:
				failures += 1
				print("FAIL: confirmation did not open " + prefix)
			var bounds = Rect2(Vector2.ZERO, Vector2(viewport))
			for control in [village.confirm_modal.get_node("Card"), village.confirm_ok_button, village.confirm_cancel_button]:
				if not bounds.encloses(control.get_global_rect()):
					failures += 1
					print("FAIL: confirmation bounds %s %s %s" % [prefix, control.name, control.get_global_rect()])
	village.close_detail_modal()
	village.set_text_scale(1.0)
	root.size = Vector2i(1280, 800)
	for id in village.village_state.stages:
		village.village_state.stages[id] = 3
	village.refresh_view()
	await capture("restored-village")
	main.queue_free()
	await process_frame
	print("VISUAL CAPTURE failures=%d" % failures)
	quit(1 if failures > 0 else 0)
