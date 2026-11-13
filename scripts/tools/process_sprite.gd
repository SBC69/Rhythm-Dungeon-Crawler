extends SceneTree

func _init():
	var input_path = "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/dungeon_entrance_1792537949816.jpg"
	var out_path = "res://assets/sprites/village/dungeon_entrance.png"
	
	process_image(input_path, out_path, 210, 224)
	print("Done processing dungeon entrance")
	quit()

func process_image(src_path: String, dest_path: String, target_max_dim: int, base_y: int) -> void:
	var img = Image.load_from_file(src_path)
	if img == null:
		print("Error loading: ", src_path)
		return
	
	img.convert(Image.FORMAT_RGBA8)
	var w = img.get_width()
	var h = img.get_height()
	
	# Flood fill from edges to identify black background
	var visited = []
	visited.resize(w * h)
	visited.fill(false)
	
	var queue: Array[Vector2i] = []
	
	# Add border pixels that are near black (e.g. max(r,g,b) < 0.12)
	var is_bg = func(c: Color) -> bool:
		return c.r < 0.10 and c.g < 0.10 and c.b < 0.10
	
	for x in range(w):
		for y in [0, h - 1]:
			if is_bg.call(img.get_pixel(x, y)):
				queue.append(Vector2i(x, y))
				visited[y * w + x] = true
	for y in range(h):
		for x in [0, w - 1]:
			var idx = y * w + x
			if not visited[idx] and is_bg.call(img.get_pixel(x, y)):
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
					# slightly looser threshold for flood fill to catch compression artifacts near edges
					if nc.r < 0.12 and nc.g < 0.12 and nc.b < 0.12:
						visited[n_idx] = true
						queue.append(Vector2i(nx, ny))
	
	# Set visited to transparent
	for y in range(h):
		for x in range(w):
			if visited[y * w + x]:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var c = img.get_pixel(x, y)
				# soften very dark edge pixels slightly
				if c.r < 0.12 and c.g < 0.12 and c.b < 0.12:
					var alpha = maxf(c.r, maxf(c.g, c.b)) / 0.12
					img.set_pixel(x, y, Color(c.r, c.g, c.b, alpha))
	
	# Find bounding box of non-transparent content
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
		print("Warning: empty crop")
		return
		
	var crop_w = max_x - min_x + 1
	var crop_h = max_y - min_y + 1
	var cropped = Image.create(crop_w, crop_h, false, Image.FORMAT_RGBA8)
	cropped.blit_rect(img, Rect2i(min_x, min_y, crop_w, crop_h), Vector2i.ZERO)
	
	# Scale cropped image so it fits nicely
	var scale_factor = float(target_max_dim) / maxf(crop_w, crop_h)
	var new_w = int(round(crop_w * scale_factor))
	var new_h = int(round(crop_h * scale_factor))
	cropped.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
	
	# Create 256x256 final canvas
	var final_img = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	final_img.fill(Color(0, 0, 0, 0))
	
	# Center horizontally at 128, place bottom at base_y
	var dest_x = 128 - int(round(new_w * 0.5))
	var dest_y = base_y - new_h
	if dest_y < 0:
		dest_y = 0
	
	final_img.blit_rect(cropped, Rect2i(0, 0, new_w, new_h), Vector2i(dest_x, dest_y))
	final_img.save_png(dest_path)
	print("Saved to ", dest_path, " size: (256, 256) placed at (", dest_x, ", ", dest_y, ")")
