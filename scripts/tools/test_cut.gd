extends SceneTree

func _init():
	var ground = Image.load_from_file("C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/village_ground_1792538273608.jpg")
	ground.convert(Image.FORMAT_RGBA8)
	
	# Chronicler: Chapel in lower right
	# Coordinates on 1376x768 image:
	# Peak: (1215, 535)
	# Left eave: (1165, 615)
	# Left wall bottom: (1170, 715)
	# Steps: (1205, 765), (1245, 765)
	# Right wall bottom: (1290, 730)
	# Right eave: (1310, 630)
	var pts: Array[Vector2] = [
		Vector2(1215, 535),
		Vector2(1165, 615),
		Vector2(1170, 715),
		Vector2(1205, 765),
		Vector2(1245, 765),
		Vector2(1290, 730),
		Vector2(1310, 630)
	]
	
	var cut = _cut_polygon(ground, pts, 256, 256, Vector2(128, 224))
	cut.save_png("C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/test_cut_chronicler.png")
	print("Saved test_cut_chronicler.png")
	quit()

func _cut_polygon(src: Image, pts: Array[Vector2], out_w: int, out_h: int, anchor: Vector2) -> Image:
	var min_x = 9999.0
	var max_x = -9999.0
	var min_y = 9999.0
	var max_y = -9999.0
	for p in pts:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
		
	var w = int(max_x - min_x + 1)
	var h = int(max_y - min_y + 1)
	
	var cut = Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)
	
	var scale = 200.0 / float(h)
	var scaled_w = int(w * scale)
	var scaled_h = int(h * scale)
	
	var dest_base_x = int(anchor.x)
	var dest_base_y = int(anchor.y)
	var dest_origin_x = dest_base_x - int(scaled_w * 0.5)
	var dest_origin_y = dest_base_y - scaled_h
	
	for dy in range(scaled_h):
		var sy = min_y + dy / scale
		for dx in range(scaled_w):
			var sx = min_x + dx / scale
			if _point_in_poly(Vector2(sx, sy), pts):
				var c = src.get_pixel(int(sx), int(sy))
				var dx_pos = dest_origin_x + dx
				var dy_pos = dest_origin_y + dy
				if dx_pos >= 0 and dx_pos < out_w and dy_pos >= 0 and dy_pos < out_h:
					cut.set_pixel(dx_pos, dy_pos, c)
				
	return cut

func _point_in_poly(pt: Vector2, poly: Array[Vector2]) -> bool:
	var inside = false
	var j = poly.size() - 1
	for i in range(poly.size()):
		var pi = poly[i]
		var pj = poly[j]
		if (pi.y > pt.y) != (pj.y > pt.y) and pt.x < (pj.x - pi.x) * (pt.y - pi.y) / (pj.y - pi.y) + pi.x:
			inside = !inside
		j = i
	return inside
