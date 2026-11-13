extends SceneTree

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png("res://visual-evidence/" + name + ".png") != OK:
		failures += 1

func set_time(rhythm: Node, time: float) -> void:
	rhythm.started_usec = Time.get_ticks_usec() - int(time * 1000000)
	rhythm._process(0.0)
	rhythm.set_process(false)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://visual-evidence")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var fix := GameFixture.new(self)
	var main = await fix.create_main()
	var gm = root.get_node("GameManager")
	for id in main.dungeon_view.DUNGEON_ART:
		gm.current_dungeon_id = id
		gm.current_room = 1
		main.router.show_corridor()
		await capture("doors-fit-" + id)
		var fitted: AtlasTexture = main.dungeon_view.door_center.texture_rect.texture
		print("FITTED ", id, " region=", fitted.region, " original=", fitted.atlas.get_size())
	gm.current_dungeon_id = "crypts"
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1758, 983)
	main.router.show_corridor()
	await capture("doors-fit-large")
	gm.current_room = gm.MAX_ROOMS_PER_FLOOR
	main.router.show_corridor()
	await capture("doors-fit-boss")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i.ZERO
	gm.current_room = 1
	await fix.enter_regular_encounter(main, gm.get_total_player_power() + 2)
	var view = main.monster_view
	for id in ["skeleton", "shadow_ghoul", "boss_archon"]:
		var monster: Dictionary = EncounterFactory.MONSTER_TEMPLATES.get(id, {"id": id, "name": "Архонт Бездны", "is_boss": true}).duplicate(true)
		monster.power = gm.get_total_player_power() + 2
		view.setup_monster(monster)
		view._start_rhythm()
		var rhythm = view.rhythm_game
		set_time(rhythm, float(rhythm.round_state.settings.interval) * 2.2)
		await capture("rhythm-countdown-" + id)
		set_time(rhythm, rhythm.round_state.note_times[0] - float(rhythm.round_state.settings.interval) * 0.4)
		await capture("rhythm-notes-" + id)
		for index in range(3):
			rhythm.started_usec = Time.get_ticks_usec() - int(rhythm.round_state.note_times[index] * 1000000)
			rhythm._press(rhythm.round_state.note_actions[index])
		await capture("rhythm-hit-" + id)
		var panel: Control = view.get_node("PanelContainer")
		var screen := Rect2(Vector2.ZERO, Vector2(root.size))
		if not screen.encloses(panel.get_global_rect()) or not panel.get_global_rect().encloses(rhythm.hit_button.get_global_rect()):
			failures += 1
			print("FAIL: rhythm panel bounds ", panel.get_global_rect())
		if rhythm.combo != 3:
			failures += 1
			print("FAIL: hit series counter")
		rhythm.started_usec = Time.get_ticks_usec() - int(rhythm.round_state.note_times[3] * 1000000)
		rhythm._press(RhythmRound.ATTACK if rhythm.round_state.note_actions[3] == RhythmRound.GUARD else RhythmRound.GUARD)
		await capture("rhythm-wrong-" + id)
		set_time(rhythm, rhythm.round_state.note_times[4] + rhythm.round_state.hit_window_for_note(4) + 0.02)
		await capture("rhythm-miss-" + id)
		if rhythm.combo != 0:
			failures += 1
			print("FAIL: missed note did not reset series")
		view.setup_monster(monster)
		if not view.power_comparison_label.visible or not view.status_hint_label.visible:
			failures += 1
			print("FAIL: next encounter did not restore pre-fight information")
	await fix.teardown()
	main = await fix.create_main()
	await fix.enter_regular_encounter(main, gm.get_total_player_power() + 1)
	view = main.monster_view
	view._start_rhythm()
	view.rhythm_game.started_usec = Time.get_ticks_usec() - 100000000
	await capture("rhythm-defeat-return")
	if not main.dungeon_view.visible or main.encounter_ctrl.phase != EncounterController.RunPhase.CORRIDOR:
		failures += 1
		print("FAIL: failed rhythm did not show the doors")
	await fix.teardown()
	print("RHYTHM / DOOR VISUAL failures=%d" % failures)
	quit(1 if failures > 0 else 0)
