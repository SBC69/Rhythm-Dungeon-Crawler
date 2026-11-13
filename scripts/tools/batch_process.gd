extends SceneTree

func _init():
	var batch = [
		{"src": "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/square_stage_0_1792538296787.jpg", "dest": "res://assets/sprites/village/square/stage_0.png", "max_dim": 210, "base_y": 224},
		{"src": "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/square_stage_1_1792538314564.jpg", "dest": "res://assets/sprites/village/square/stage_1.png", "max_dim": 210, "base_y": 224},
		{"src": "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/square_stage_2_1792538335803.jpg", "dest": "res://assets/sprites/village/square/stage_2.png", "max_dim": 210, "base_y": 224},
		{"src": "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/square_stage_3_1792538356870.jpg", "dest": "res://assets/sprites/village/square/stage_3.png", "max_dim": 210, "base_y": 224},
		{"src": "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/forge_stage_0_1792538403828.jpg", "dest": "res://assets/sprites/village/forge/stage_0.png", "max_dim": 210, "base_y": 224},
		{"src": "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/forge_stage_1_1792538422555.jpg", "dest": "res://assets/sprites/village/forge/stage_1.png", "max_dim": 210, "base_y": 224},
		{"src": "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/forge_stage_2_1792538450572.jpg", "dest": "res://assets/sprites/village/forge/stage_2.png", "max_dim": 210, "base_y": 224},
		{"src": "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/forge_stage_3_1792538512884.jpg", "dest": "res://assets/sprites/village/forge/stage_3.png", "max_dim": 210, "base_y": 224},
		{"src": "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/houses_stage_0_1792538601048.jpg", "dest": "res://assets/sprites/village/houses/stage_0.png", "max_dim": 210, "base_y": 224},
		{"src": "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/houses_stage_1_1792538627543.jpg", "dest": "res://assets/sprites/village/houses/stage_1.png", "max_dim": 210, "base_y": 224},
	]
	
	for item in batch:
		process_clean(item["src"], item["dest"], item["max_dim"], item["base_y"])
	
	print("Clean batch finished successfully!")
	quit(0)

func process_clean(src_path: String, dest_path: String, target_max_dim: int, base_y: int) -> void:
	var img = Image.load_from_file(src_path)
	if img == null:
		print("Failed to load: ", src_path)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w = img.get_width()
	var h = img.get_height()
	
	var is_exterior_bg = func(c: Color) -> bool:
		# Black background in generated JPEGs: RGB components are close to 0
		return c.r < 0.08 and c.g < 0.08 and c.b < 0.08
		
	var visited = []
	visited.resize(w * h)
	visited.fill(false)
	var queue: Array[Vector2i] = []
	
	for x in range(w):
		for y in [0, h - 1]:
			if is_exterior_bg.call(img.get_pixel(x, y)):
				queue.append(Vector2i(x, y))
				visited[y * w + x] = true
	for y in range(h):
		for x in [0, w - 1]:
			var idx = y * w + x
			if not visited[idx] and is_exterior_bg.call(img.get_pixel(x, y)):
				queue.append(Vector2i(x, y))
				visited[idx] = true
				
	var q_idx = 0
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	while q_idx < queue.size():
		var pt = queue[q_idx]
		q_idx += 1
		for d in dirs:
			var nx = pt.x + d.x
			var ny = pt.y + d.y
			if nx >= 0 and nx < w and ny >= 0 and ny < h:
				var n_idx = ny * w + nx
				if not visited[n_idx]:
					var nc = img.get_pixel(nx, ny)
					if nc.r < 0.10 and nc.g < 0.10 and nc.b < 0.10:
						visited[n_idx] = true
						queue.append(Vector2i(nx, ny))
						
	# ONLY pixels that were visited by exterior flood fill become transparent!
	# Interior dark pixels remain 100% opaque!
	for y in range(h):
		for x in range(w):
			var idx = y * w + x
			if visited[idx]:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				# Check if this pixel borders a visited pixel (outer fringe)
				var on_border = false
				for d in dirs:
					var bx = x + d.x
					var by = y + d.y
					if bx >= 0 and bx < w and by >= 0 and by < h:
						if visited[by * w + bx]:
							on_border = true
							break
				var c = img.get_pixel(x, y)
				if on_border and c.r < 0.12 and c.g < 0.12 and c.b < 0.12:
					var a = clampf(maxf(c.r, maxf(c.g, c.b)) / 0.12, 0.1, 1.0)
					img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
				else:
					img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
					
	# Bounding box of content
	var min_x = w
	var max_x = 0
	var min_y = h
	var max_y = 0
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.05:
				if x < min_x: min_x = x
				if x > max_x: max_x = x
				if y < min_y: min_y = y
				if y > max_y: max_y = y
				
	if min_x >= max_x or min_y >= max_y:
		print("Empty crop for: ", src_path)
		return
		
	var crop_w = max_x - min_x + 1
	var crop_h = max_y - min_y + 1
	var cropped = Image.create(crop_w, crop_h, false, Image.FORMAT_RGBA8)
	cropped.blit_rect(img, Rect2i(min_x, min_y, crop_w, crop_h), Vector2i.ZERO)
	
	var scale_factor = float(target_max_dim) / maxf(crop_w, crop_h)
	var new_w = int(round(crop_w * scale_factor))
	var new_h = int(round(crop_h * scale_factor))
	cropped.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
	
	var final_img = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	final_img.fill(Color(0, 0, 0, 0))
	var dest_x = 128 - int(round(new_w * 0.5))
	var dest_y = base_y - new_h
	if dest_y < 0:
		dest_y = 0
	final_img.blit_rect(cropped, Rect2i(0, 0, new_w, new_h), Vector2i(dest_x, dest_y))
	final_img.save_png(dest_path)
	print("Saved clean ", dest_path, " [", new_w, "x", new_h, "] placed at (", dest_x, ",", dest_y, ")")
