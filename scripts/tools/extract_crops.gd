extends SceneTree

func _init():
	var ground = Image.load_from_file("C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/village_ground_1792538273608.jpg")
	if ground == null:
		quit(1)
	ground.convert(Image.FORMAT_RGBA8)
	
	var crops = [
		{"name": "market_stall_1", "rect": Rect2i(150, 480, 240, 240)},
		{"name": "market_stall_2", "rect": Rect2i(350, 600, 260, 200)},
		{"name": "market_stall_3", "rect": Rect2i(220, 210, 160, 160)},
		{"name": "chapel_chronicler", "rect": Rect2i(1130, 520, 220, 240)},
		{"name": "apothecary_cottage", "rect": Rect2i(710, 240, 200, 240)},
		{"name": "cottage_houses_2", "rect": Rect2i(180, 20, 240, 230)},
		{"name": "cottage_houses_3", "rect": Rect2i(400, 10, 220, 240)},
		{"name": "shop_middle", "rect": Rect2i(500, 160, 200, 220)}
	]
	
	for c in crops:
		var dest = "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/crop_" + c["name"] + ".png"
		var sub = Image.create(c["rect"].size.x, c["rect"].size.y, false, Image.FORMAT_RGBA8)
		sub.blit_rect(ground, c["rect"], Vector2i.ZERO)
		sub.save_png(dest)
		print("Saved crop: ", dest)
		
	quit(0)
