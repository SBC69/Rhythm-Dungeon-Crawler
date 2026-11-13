extends SceneTree

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func capture(filename: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png("res://" + filename + ".png") != OK:
		failures += 1

func _run() -> void:
	root.size = Vector2i(1280, 960)
	root.content_scale_size = Vector2i.ZERO
	var background := ColorRect.new()
	background.color = Color(0.055, 0.045, 0.085)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(32, 24)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	root.add_child(grid)
	for id in EncounterFactory.MONSTER_TEMPLATES:
		var monster: Dictionary = EncounterFactory.MONSTER_TEMPLATES[id]
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(288, 280)
		card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		grid.add_child(card)
		var texture := TextureRect.new()
		texture.custom_minimum_size = Vector2(272, 235)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.texture = load(EncounterFactory.sprite_for(monster))
		card.add_child(texture)
		var label := Label.new()
		label.text = str(monster.name)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		card.add_child(label)
	await capture("enemy-roster-preview")
	var bounds := Rect2(Vector2.ZERO, Vector2(root.size))
	for card in grid.get_children():
		if not bounds.encloses(card.get_global_rect()):
			failures += 1
	grid.queue_free()
	background.queue_free()
	await process_frame
	root.size = Vector2i(1280, 720)
	var fix := GameFixture.new(self)
	var main = await fix.create_main()
	var gm = root.get_node("GameManager")
	await fix.enter_regular_encounter(main, gm.get_total_player_power() + 3)
	for id in ["cave_spider", "dungeon_slime", "restless_ghost", "werewolf", "goblin_raider", "stone_golem", "bound_djinn", "abyss_demon"]:
		var monster: Dictionary = EncounterFactory.MONSTER_TEMPLATES[id].duplicate(true)
		monster.power = gm.get_total_player_power() + 3
		main.monster_view.setup_monster(monster)
		await capture("enemy-combat-" + id)
		if not Rect2(Vector2.ZERO, Vector2(root.size)).encloses(main.monster_view.get_node("PanelContainer").get_global_rect()):
			failures += 1
	await fix.teardown()
	print("ENEMY VISUAL failures=%d" % failures)
	quit(1 if failures > 0 else 0)
