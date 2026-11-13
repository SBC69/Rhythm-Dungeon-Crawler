extends SceneTree

const BUILDINGS := ["houses", "square", "chronicler", "marketplace", "forge", "alchemist"]
const TITLES := {"crypts": "Катакомбы", "ash_forges": "Пепельные кузни", "drowned_temple": "Затонувший храм", "crystal_mines": "Кристальные шахты", "abyss_rift": "Разлом Бездны"}
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func capture(filename: String) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if picture == null or picture.is_empty() or picture.save_png("res://visual-evidence/" + filename + ".png") != OK:
		failures += 1
	return picture

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://visual-evidence")
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i.ZERO
	var fix := GameFixture.new(self)
	var main = await fix.create_main()
	main.router.show_village_map()
	var village = main.village_map
	for stage in range(4):
		for id in BUILDINGS:
			village.village_state.stages[id] = stage
			var path := "res://assets/sprites/village/%s/stage_%d.png" % [id, stage]
			var image := (load(path) as Texture2D).get_image()
			if image == null or image.is_empty():
				failures += 1
				continue
			for corner in [Vector2i.ZERO, Vector2i(image.get_width() - 1, 0), Vector2i(0, image.get_height() - 1), image.get_size() - Vector2i.ONE]:
				# One alpha quantization step is visually transparent (1 / 255).
				if image.get_pixelv(corner).a > 1.0 / 255.0 + 0.000001:
					failures += 1
					print("FAIL: opaque sprite corner ", path)
		village.refresh_view()
		await capture("village-stage-%d" % stage)
	root.size = Vector2i(1280, 720)
	var gm = root.get_node("GameManager")
	var previews: Array[Texture2D] = []
	for id in TITLES:
		gm.current_dungeon_id = id
		gm.current_room = 1
		main.router.show_corridor()
		var image := await capture("dungeon-" + id)
		if image != null:
			previews.append(ImageTexture.create_from_image(image))
		var door_image: Image = main.dungeon_view.door_center.texture_rect.texture.get_image()
		if door_image.get_pixel(0, 0).a != 0.0:
			failures += 1
	main.visible = false
	root.size = Vector2i(1280, 580)
	var background := ColorRect.new()
	background.color = Color(0.035, 0.03, 0.055)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(20, 20)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 20)
	root.add_child(grid)
	for i in range(previews.size()):
		var card := VBoxContainer.new()
		grid.add_child(card)
		var texture := TextureRect.new()
		texture.custom_minimum_size = Vector2(400, 225)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture.texture = previews[i]
		card.add_child(texture)
		var label := Label.new()
		label.text = TITLES.values()[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		card.add_child(label)
	await capture("dungeon-themes-preview")
	grid.queue_free()
	await process_frame
	root.size = Vector2i(1280, 1600)
	grid = GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(20, 16)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	root.add_child(grid)
	var building_titles := {"houses": "Жилые дома", "square": "Площадь", "chronicler": "Летописец", "marketplace": "Рынок", "forge": "Кузница", "alchemist": "Алхимик"}
	for id in BUILDINGS:
		for stage in range(4):
			var card := VBoxContainer.new()
			grid.add_child(card)
			var texture := TextureRect.new()
			texture.custom_minimum_size = Vector2(300, 225)
			texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			texture.texture = load("res://assets/sprites/village/%s/stage_%d.png" % [id, stage])
			card.add_child(texture)
			var label := Label.new()
			label.text = "%s · %d/3" % [building_titles[id], stage]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 20)
			card.add_child(label)
	await capture("village-buildings-preview")
	grid.queue_free()
	background.queue_free()
	await fix.teardown()
	print("ENVIRONMENT VISUAL failures=%d" % failures)
	quit(1 if failures > 0 else 0)
