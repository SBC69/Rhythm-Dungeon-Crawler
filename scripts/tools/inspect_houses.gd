extends SceneTree

func _init():
	var h0 = Image.load_from_file("C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/houses_stage_0_1792538601048.jpg")
	var h1 = Image.load_from_file("C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/houses_stage_1_1792538627543.jpg")
	print("H0: ", h0.get_size(), " H1: ", h1.get_size())
	
	# Let's save a visual comparison of H0 and H1
	# The restored cottage in H1 is in the center-left. Let's find the difference:
	var diff = Image.create(h0.get_width(), h0.get_height(), false, Image.FORMAT_RGBA8)
	var max_diff = 0.0
	var diff_rect_min = Vector2i(9999, 9999)
	var diff_rect_max = Vector2i(0, 0)
	
	for y in range(h0.get_height()):
		for x in range(h0.get_width()):
			var c0 = h0.get_pixel(x, y)
			var c1 = h1.get_pixel(x, y)
			var d = abs(c0.r - c1.r) + abs(c0.g - c1.g) + abs(c0.b - c1.b)
			if d > 0.2:
				diff.set_pixel(x, y, Color(1, 0, 0, 1))
				if x < diff_rect_min.x: diff_rect_min.x = x
				if x > diff_rect_max.x: diff_rect_max.x = x
				if y < diff_rect_min.y: diff_rect_min.y = y
				if y > diff_rect_max.y: diff_rect_max.y = y
			else:
				diff.set_pixel(x, y, Color(0, 0, 0, 0.5))
	print("Restored region in H1: min=", diff_rect_min, " max=", diff_rect_max)
	diff.save_png("C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/h1_diff.png")
	quit()
