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
	if not Rect2(Vector2.ZERO, Vector2(root.size)).encloses(control.get_global_rect()):
		failures += 1
		print("FAIL: ", description, " bounds: ", control.get_global_rect())

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://visual-evidence")
	root.position = Vector2i(-32000, -32000)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i.ZERO
	var fix := GameFixture.new(self)
	var main = await fix.create_main()
	var gm = root.get_node("GameManager")
	var cdb = root.get_node("CardDatabase")
	gm.add_card_to_hand(cdb.get_card_data("spiked_shield"))
	for id in ["iron_blade", "royal_plate", "lucky_dice_amulet", "greater_health_potion"]:
		gm.floor_stash.append(cdb.get_card_for_floor(2, id))
	gm.inventory_changed.emit()
	var inventory = main.inventory_panel
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		var suffix := "%dx%d" % [size.x, size.y]
		await _capture("inventory-hud-" + suffix)
		_inside(main.hud.inventory_button, "HUD inventory button")
		await fix.simulate_click(main.hud.inventory_button)
		if not inventory.visible:
			failures += 1
			print("FAIL: mouse could not open inventory")
		await _capture("inventory-open-" + suffix)
		_inside(inventory.panel, "inventory panel")
		_inside(inventory.close_button, "inventory close button")
		await TestUI._keyboard_focus(fix, TestRunInventory._item_button(inventory, gm.floor_stash[0], true))
		await _capture("inventory-loot-" + suffix)
		inventory.close()
	root.size = Vector2i(1280, 720)
	inventory.open()
	var gear: Dictionary = gm.floor_stash[0].duplicate(true)
	var button = TestRunInventory._item_button(inventory, gear, true)
	await TestUI._keyboard_focus(fix, button)
	await fix.simulate_key(KEY_ENTER)
	await _capture("inventory-equipped")
	if str(gm.equipped_weapon.instance_id) != str(gear.instance_id):
		failures += 1
		print("FAIL: reward was not equipped")
	inventory.close()
	gm.hand_cards.clear()
	gm.floor_stash.clear()
	gm.inventory_changed.emit()
	inventory.open()
	await _capture("inventory-empty")
	_inside(inventory.panel, "empty inventory")
	await fix.teardown()
	print("INVENTORY VISUAL failures=%d" % failures)
	quit(1 if failures > 0 else 0)
