extends SceneTree

const BASE_X = 128
const BASE_Y = 224

func _init():
	print("Starting village sprite synthesis...")
	
	# Clean re-process of square, forge, houses stage 0 & 1
	_reprocess_existing_clean()
	
	# Synthesize houses stage 2 & 3
	_synthesize_houses()
	
	# Synthesize chronicler stage 0, 1, 2, 3
	_synthesize_chronicler()
	
	# Synthesize marketplace stage 0, 1, 2, 3
	_synthesize_marketplace()
	
	# Synthesize alchemist stage 0, 1, 2, 3
	_synthesize_alchemist()
	
	print("All 24 building sprites + dungeon entrance + ground are ready!")
	quit(0)

func _reprocess_existing_clean() -> void:
	var items = [
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
	for it in items:
		_process_file_clean(it["src"], it["dest"], it["max_dim"], it["base_y"])

func _process_file_clean(src_path: String, dest_path: String, max_dim: int, base_y: int) -> Image:
	var img = Image.load_from_file(src_path)
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	var w = img.get_width()
	var h = img.get_height()
	
	var is_bg = func(c: Color) -> bool:
		return c.r < 0.08 and c.g < 0.08 and c.b < 0.08
		
	var visited = []
	visited.resize(w * h)
	visited.fill(false)
	var queue: Array[Vector2i] = []
	
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
					if nc.r < 0.10 and nc.g < 0.10 and nc.b < 0.10:
						visited[n_idx] = true
						queue.append(Vector2i(nx, ny))
						
	for y in range(h):
		for x in range(w):
			var idx = y * w + x
			if visited[idx]:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var c = img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
				
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
		return null
		
	var crop_w = max_x - min_x + 1
	var crop_h = max_y - min_y + 1
	var cropped = Image.create(crop_w, crop_h, false, Image.FORMAT_RGBA8)
	cropped.blit_rect(img, Rect2i(min_x, min_y, crop_w, crop_h), Vector2i.ZERO)
	
	var scale_factor = float(max_dim) / maxf(crop_w, crop_h)
	var new_w = int(round(crop_w * scale_factor))
	var new_h = int(round(crop_h * scale_factor))
	cropped.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
	
	var final_img = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	final_img.fill(Color(0, 0, 0, 0))
	var dest_x = 128 - int(round(new_w * 0.5))
	var dest_y = base_y - new_h
	if dest_y < 0: dest_y = 0
	final_img.blit_rect(cropped, Rect2i(0, 0, new_w, new_h), Vector2i(dest_x, dest_y))
	final_img.save_png(dest_path)
	print("Saved clean: ", dest_path)
	return final_img

# --- SYNTHESIS METHODS ---

func _synthesize_houses() -> void:
	# houses stage 2: 2 cottages restored, warm windows, lanterns, flower boxes
	var base_h1 = Image.load_from_file("res://assets/sprites/village/houses/stage_1.png")
	if base_h1 == null: return
	base_h1.convert(Image.FORMAT_RGBA8)
	
	var h2 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	h2.blit_rect(base_h1, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	
	# In stage 1, center cottage is restored. Let's repair the left cottage:
	# Add solid wooden roof shingles (slate/dark wood), repair wall, lit warm amber window
	_draw_iso_slanted_roof(h2, 45, 115, 65, 45, Color(0.28, 0.22, 0.20), Color(0.18, 0.14, 0.12))
	_draw_glowing_window(h2, 60, 140, 14, 18, Color(1.0, 0.75, 0.25))
	_draw_flower_box(h2, 57, 160, 20, 6)
	_draw_lantern_post(h2, 38, 175, 30)
	h2.save_png("res://assets/sprites/village/houses/stage_2.png")
	print("Synthesized houses/stage_2.png")
	
	# houses stage 3: all 3 cottages fully restored! Chimney smoke, gardens, welcoming windows
	var h3 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	h3.blit_rect(h2, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	# Repair right cottage too:
	_draw_iso_slanted_roof(h3, 160, 105, 60, 42, Color(0.25, 0.24, 0.28), Color(0.16, 0.15, 0.18))
	_draw_glowing_window(h3, 175, 130, 14, 18, Color(1.0, 0.8, 0.3))
	_draw_glowing_window(h3, 120, 110, 12, 14, Color(1.0, 0.85, 0.35))
	_draw_flower_box(h3, 172, 150, 20, 6)
	# Add chimney smoke on cottages
	_draw_smoke_puff(h3, 100, 70, Color(0.8, 0.8, 0.85, 0.7))
	_draw_smoke_puff(h3, 195, 65, Color(0.75, 0.75, 0.8, 0.6))
	_draw_lantern_post(h3, 218, 170, 32)
	h3.save_png("res://assets/sprites/village/houses/stage_3.png")
	print("Synthesized houses/stage_3.png")

func _synthesize_chronicler() -> void:
	# Base stone structure adapted from dark gothic masonry
	# Stage 0: Abandoned dark stone scriptorium, boarded windows, scattered wet parchment sheets
	var c0 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	# Build stone gothic building base
	_draw_gothic_study_building(c0, false, 0)
	# Add boarded windows
	_draw_boarded_window(c0, 110, 115, 18, 26)
	_draw_boarded_window(c0, 145, 130, 18, 24)
	# Scattered parchment sheets and torn scrolls on threshold
	_draw_scattered_parchments(c0, 115, 185, 12)
	c0.save_png("res://assets/sprites/village/chronicler/stage_0.png")
	print("Synthesized chronicler/stage_0.png")
	
	# Stage 1: Repaired stone building, open door, scholar desk, open chronicle ledger, warm lantern
	var c1 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	_draw_gothic_study_building(c1, true, 1)
	_draw_scholar_desk_with_book(c1, 120, 160)
	_draw_lantern_post(c1, 95, 180, 28)
	c1.save_png("res://assets/sprites/village/chronicler/stage_1.png")
	print("Synthesized chronicler/stage_1.png")
	
	# Stage 2: Well-equipped archive, bookcases with tomes, scroll racks, study table, heraldic banners
	var c2 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	_draw_gothic_study_building(c2, true, 2)
	_draw_scholar_desk_with_book(c2, 110, 155)
	_draw_bookcase(c2, 150, 125)
	_draw_banner(c2, 85, 105, Color(0.2, 0.4, 0.7), Color(0.9, 0.8, 0.2))
	_draw_lantern_post(c2, 80, 175, 32)
	_draw_lantern_post(c2, 185, 185, 32)
	c2.save_png("res://assets/sprites/village/chronicler/stage_2.png")
	print("Synthesized chronicler/stage_2.png")
	
	# Stage 3: Grand Hall of Records, memorial plaque wall, gargoyles, stained glass, ornate gothic facade
	var c3 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	_draw_gothic_study_building(c3, true, 3)
	_draw_stained_glass(c3, 128, 85, 24, 38)
	_draw_memorial_plaque_wall(c3, 145, 135)
	_draw_gargoyle(c3, 68, 82)
	_draw_gargoyle(c3, 188, 92)
	_draw_banner(c3, 75, 110, Color(0.5, 0.1, 0.15), Color(1.0, 0.85, 0.3))
	_draw_banner(c3, 185, 115, Color(0.1, 0.3, 0.5), Color(1.0, 0.85, 0.3))
	_draw_lantern_post(c3, 65, 180, 36)
	_draw_lantern_post(c3, 195, 190, 36)
	c3.save_png("res://assets/sprites/village/chronicler/stage_3.png")
	print("Synthesized chronicler/stage_3.png")

func _synthesize_marketplace() -> void:
	# Stage 0: Smashed wooden stalls, splintered wood, fallen crates, torn canvas rags
	var m0 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	_draw_cobblestone_pad(m0, 128, 205, 160, 75)
	_draw_ruined_market_stalls(m0, 128, 170)
	m0.save_png("res://assets/sprites/village/marketplace/stage_0.png")
	print("Synthesized marketplace/stage_0.png")
	
	# Stage 1: Single repaired merchant wooden stall with canvas awning, adventurer cloaks & gear
	var m1 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	_draw_cobblestone_pad(m1, 128, 205, 160, 75)
	_draw_merchant_stall(m1, 128, 175, 90, 65, Color(0.35, 0.45, 0.3), Color(0.25, 0.32, 0.22), "gear")
	_draw_lantern_post(m1, 65, 185, 28)
	m1.save_png("res://assets/sprites/village/marketplace/stage_1.png")
	print("Synthesized marketplace/stage_1.png")
	
	# Stage 2: Two merchant booths: card display racks & dice rolling trays, striped awnings
	var m2 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	_draw_cobblestone_pad(m2, 128, 205, 180, 85)
	_draw_merchant_stall(m2, 95, 165, 75, 55, Color(0.65, 0.2, 0.2), Color(0.85, 0.8, 0.65), "cards")
	_draw_merchant_stall(m2, 165, 185, 75, 55, Color(0.2, 0.35, 0.6), Color(0.85, 0.8, 0.65), "dice")
	_draw_lantern_post(m2, 45, 175, 30)
	_draw_lantern_post(m2, 215, 195, 30)
	m2.save_png("res://assets/sprites/village/marketplace/stage_2.png")
	print("Synthesized marketplace/stage_2.png")
	
	# Stage 3: Grand bustling bazaar: multiple stalls with rich canopies, banners, hanging lamps, decorative wares
	var m3 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	_draw_cobblestone_pad(m3, 128, 205, 190, 90)
	_draw_merchant_stall(m3, 85, 155, 70, 55, Color(0.55, 0.15, 0.2), Color(0.9, 0.75, 0.3), "cards")
	_draw_merchant_stall(m3, 170, 165, 75, 58, Color(0.15, 0.4, 0.3), Color(0.9, 0.75, 0.3), "dice")
	_draw_merchant_stall(m3, 128, 195, 80, 55, Color(0.2, 0.2, 0.5), Color(0.95, 0.8, 0.4), "bazaar")
	_draw_festive_pennants(m3, 70, 115, 190, 125)
	_draw_lantern_post(m3, 38, 170, 34)
	_draw_lantern_post(m3, 218, 180, 34)
	m3.save_png("res://assets/sprites/village/marketplace/stage_3.png")
	print("Synthesized marketplace/stage_3.png")

func _synthesize_alchemist() -> void:
	# Stage 0: Dilapidated stone cottage, broken chimney, cracked walls, withered vines
	var a0 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	_draw_alchemist_cottage_base(a0, 0)
	a0.save_png("res://assets/sprites/village/alchemist/stage_0.png")
	print("Synthesized alchemist/stage_0.png")
	
	# Stage 1: Repaired cottage, herbalist drying rack with dried plants, vials, mortar & pestle
	var a1 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	_draw_alchemist_cottage_base(a1, 1)
	_draw_herb_drying_rack(a1, 75, 170)
	_draw_apothecary_table(a1, 155, 180, 1)
	_draw_lantern_post(a1, 60, 190, 26)
	a1.save_png("res://assets/sprites/village/alchemist/stage_1.png")
	print("Synthesized alchemist/stage_1.png")
	
	# Stage 2: Stone lab, glowing potion flasks and alembics, distillation coils, glowing reagents
	var a2 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	_draw_alchemist_cottage_base(a2, 2)
	_draw_herb_drying_rack(a2, 70, 165)
	_draw_apothecary_table(a2, 150, 175, 2)
	_draw_smoke_puff(a2, 95, 65, Color(0.4, 0.7, 0.5, 0.6)) # Light green vapor from chimney
	_draw_lantern_post(a2, 50, 185, 30)
	_draw_lantern_post(a2, 205, 190, 30)
	a2.save_png("res://assets/sprites/village/alchemist/stage_2.png")
	print("Synthesized alchemist/stage_2.png")
	
	# Stage 3: Fully restored master gothic laboratory: mystical purple & emerald glow, bubbling retorts, magical smoke
	var a3 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	_draw_alchemist_cottage_base(a3, 3)
	_draw_herb_drying_rack(a3, 65, 160)
	_draw_apothecary_table(a3, 150, 175, 3)
	# Mystical purple/green smoke from gothic chimney
	_draw_smoke_puff(a3, 95, 55, Color(0.65, 0.25, 0.85, 0.75))
	_draw_smoke_puff(a3, 90, 40, Color(0.3, 0.85, 0.6, 0.65))
	_draw_runic_sign(a3, 115, 125, Color(0.8, 0.4, 1.0))
	_draw_lantern_post(a3, 45, 180, 34)
	_draw_lantern_post(a3, 210, 185, 34)
	a3.save_png("res://assets/sprites/village/alchemist/stage_3.png")
	print("Synthesized alchemist/stage_3.png")

# --- DRAWING PRIMITIVES & PIXEL ART COMPOSITION ---

func _set_pixel_alpha(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		if col.a >= 1.0:
			img.set_pixel(x, y, col)
		elif col.a > 0.0:
			var bg = img.get_pixel(x, y)
			img.set_pixel(x, y, bg.blend(col))

func _fill_iso_polygon(img: Image, pts: Array[Vector2], col: Color) -> void:
	if pts.size() < 3: return
	var min_y = 9999.0
	var max_y = -9999.0
	for p in pts:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	var iy_start = maxi(0, int(floor(min_y)))
	var iy_end = mini(img.get_height() - 1, int(ceil(max_y)))
	for y in range(iy_start, iy_end + 1):
		var nodes: Array[float] = []
		var j = pts.size() - 1
		for i in range(pts.size()):
			var p1 = pts[i]
			var p2 = pts[j]
			if (p1.y < y and p2.y >= y) or (p2.y < y and p1.y >= y):
				var node_x = p1.x + (y - p1.y) / (p2.y - p1.y) * (p2.x - p1.x)
				nodes.append(node_x)
			j = i
		nodes.sort()
		for k in range(0, nodes.size(), 2):
			if k + 1 < nodes.size():
				var x_start = maxi(0, int(floor(nodes[k])))
				var x_end = mini(img.get_width() - 1, int(ceil(nodes[k + 1])))
				for x in range(x_start, x_end + 1):
					# Subtle stone/brick texture noise
					var noise = (sin(x * 12.9898 + y * 78.233) * 43758.5453)
					noise = (noise - floor(noise)) * 0.08 - 0.04
					var final_col = Color(clampf(col.r + noise, 0, 1), clampf(col.g + noise, 0, 1), clampf(col.b + noise, 0, 1), col.a)
					_set_pixel_alpha(img, x, y, final_col)

func _draw_cobblestone_pad(img: Image, cx: int, cy: int, rw: int, rh: int) -> void:
	var pts: Array[Vector2] = [
		Vector2(cx, cy - rh * 0.5),
		Vector2(cx + rw * 0.5, cy),
		Vector2(cx, cy + rh * 0.5),
		Vector2(cx - rw * 0.5, cy)
	]
	_fill_iso_polygon(img, pts, Color(0.22, 0.22, 0.25))
	# Border flagstones
	for i in range(pts.size()):
		var p1 = pts[i]
		var p2 = pts[(i + 1) % pts.size()]
		var dist = p1.distance_to(p2)
		for s in range(int(dist)):
			var p = p1.lerp(p2, float(s) / dist)
			_set_pixel_alpha(img, int(p.x), int(p.y), Color(0.12, 0.12, 0.14))

func _draw_iso_slanted_roof(img: Image, cx: int, cy: int, w: int, h: int, col_lit: Color, col_dark: Color) -> void:
	var top_pt = Vector2(cx, cy - h)
	var left_pt = Vector2(cx - w * 0.5, cy)
	var right_pt = Vector2(cx + w * 0.5, cy)
	var bottom_pt = Vector2(cx, cy + h * 0.3)
	_fill_iso_polygon(img, [top_pt, left_pt, bottom_pt], col_dark)
	_fill_iso_polygon(img, [top_pt, right_pt, bottom_pt], col_lit)
	# Draw slate roof shingle lines
	for i in range(1, 5):
		var t = float(i) / 5.0
		var p1 = top_pt.lerp(left_pt, t)
		var p2 = bottom_pt.lerp(right_pt, t)
		var d = p1.distance_to(p2)
		for s in range(int(d)):
			var p = p1.lerp(p2, float(s) / d)
			_set_pixel_alpha(img, int(p.x), int(p.y), Color(0.08, 0.08, 0.1, 0.6))

func _draw_glowing_window(img: Image, x: int, y: int, w: int, h: int, glow_col: Color) -> void:
	# Wooden/stone frame
	for ix in range(x - 2, x + w + 2):
		for iy in range(y - 2, y + h + 2):
			_set_pixel_alpha(img, ix, iy, Color(0.12, 0.1, 0.1))
	# Amber glowing glass
	for ix in range(x, x + w):
		for iy in range(y, y + h):
			var dist = Vector2(ix, iy).distance_to(Vector2(x + w * 0.5, y + h * 0.5))
			var col = glow_col.lerp(Color(1.0, 1.0, 0.8), clampf(1.0 - dist / 10.0, 0, 1))
			_set_pixel_alpha(img, ix, iy, col)
	# Window cross bars
	var mid_x = x + int(w * 0.5)
	var mid_y = y + int(h * 0.5)
	for iy in range(y, y + h):
		_set_pixel_alpha(img, mid_x, iy, Color(0.15, 0.12, 0.1))
	for ix in range(x, x + w):
		_set_pixel_alpha(img, ix, mid_y, Color(0.15, 0.12, 0.1))
	# Window light spill glow
	_draw_radial_glow(img, x + w * 0.5, y + h + 4, 18, Color(glow_col.r, glow_col.g, glow_col.b, 0.25))

func _draw_flower_box(img: Image, x: int, y: int, w: int, h: int) -> void:
	# Wood planter box
	for ix in range(x, x + w):
		for iy in range(y, y + h):
			_set_pixel_alpha(img, ix, iy, Color(0.3, 0.2, 0.14))
	# Green leaves and red/purple flowers
	for ix in range(x - 1, x + w + 1):
		_set_pixel_alpha(img, ix, y - 1, Color(0.18, 0.45, 0.2))
		if ix % 3 == 0:
			_set_pixel_alpha(img, ix, y - 2, Color(0.85, 0.25, 0.35))
		elif ix % 3 == 1:
			_set_pixel_alpha(img, ix, y - 2, Color(0.35, 0.65, 0.3))

func _draw_radial_glow(img: Image, cx: float, cy: float, radius: float, col: Color) -> void:
	var ir = int(ceil(radius))
	for y in range(int(cy) - ir, int(cy) + ir + 1):
		for x in range(int(cx) - ir, int(cx) + ir + 1):
			var d = Vector2(x, y).distance_to(Vector2(cx, cy))
			if d <= radius:
				var a = (1.0 - d / radius) * col.a
				_set_pixel_alpha(img, x, y, Color(col.r, col.g, col.b, a))

func _draw_lantern_post(img: Image, x: int, y: int, height: int) -> void:
	# Iron pole
	for iy in range(y - height, y + 1):
		_set_pixel_alpha(img, x, iy, Color(0.12, 0.12, 0.14))
		_set_pixel_alpha(img, x + 1, iy, Color(0.18, 0.18, 0.2))
	# Lantern housing
	var ly = y - height
	for ix in range(x - 4, x + 6):
		for iy in range(ly - 8, ly + 2):
			if ix == x - 4 or ix == x + 5 or iy == ly - 8 or iy == ly + 1:
				_set_pixel_alpha(img, ix, iy, Color(0.15, 0.15, 0.18))
			else:
				_set_pixel_alpha(img, ix, iy, Color(1.0, 0.85, 0.35))
	# Warm glow
	_draw_radial_glow(img, x + 0.5, ly - 3, 24, Color(1.0, 0.75, 0.2, 0.35))

func _draw_smoke_puff(img: Image, x: int, y: int, col: Color) -> void:
	var particles = [
		Vector3(0, 0, 5),
		Vector3(3, -7, 7),
		Vector3(8, -16, 9),
		Vector3(14, -26, 12),
		Vector3(22, -38, 15)
	]
	for p in particles:
		_draw_radial_glow(img, x + p.x, y + p.y, p.z, col)

func _draw_boarded_window(img: Image, x: int, y: int, w: int, h: int) -> void:
	# Dark opening
	for ix in range(x, x + w):
		for iy in range(y, y + h):
			_set_pixel_alpha(img, ix, iy, Color(0.06, 0.06, 0.08))
	# Diagonal wood planks
	for i in range(3):
		var py = y + 3 + i * 7
		for ix in range(x - 2, x + w + 2):
			_set_pixel_alpha(img, ix, py, Color(0.28, 0.2, 0.14))
			_set_pixel_alpha(img, ix, py + 1, Color(0.2, 0.14, 0.1))

func _draw_scattered_parchments(img: Image, cx: int, cy: int, count: int) -> void:
	var rnd = [
		Vector2(-15, 0), Vector2(-8, 5), Vector2(5, 2), Vector2(14, 8),
		Vector2(-5, -6), Vector2(10, -4), Vector2(-12, 10), Vector2(2, 12)
	]
	for i in range(mini(count, rnd.size())):
		var pt = Vector2(cx, cy) + rnd[i]
		for px in range(int(pt.x), int(pt.x) + 7):
			for py in range(int(pt.y), int(pt.y) + 9):
				_set_pixel_alpha(img, px, py, Color(0.78, 0.72, 0.58, 0.85))
		# ink scribbles
		_set_pixel_alpha(img, int(pt.x) + 2, int(pt.y) + 3, Color(0.2, 0.18, 0.15))
		_set_pixel_alpha(img, int(pt.x) + 4, int(pt.y) + 3, Color(0.2, 0.18, 0.15))
		_set_pixel_alpha(img, int(pt.x) + 3, int(pt.y) + 5, Color(0.2, 0.18, 0.15))

func _draw_gothic_study_building(img: Image, repaired: bool, stage: int) -> void:
	# Base gothic stone archive building
	var bx = 128
	var by = 195
	var bw = 140
	var bh = 95
	# Stone walls
	var left_wall: Array[Vector2] = [
		Vector2(bx, by),
		Vector2(bx - bw * 0.5, by - 35),
		Vector2(bx - bw * 0.5, by - 35 - bh),
		Vector2(bx, by - bh)
	]
	var right_wall: Array[Vector2] = [
		Vector2(bx, by),
		Vector2(bx + bw * 0.5, by - 35),
		Vector2(bx + bw * 0.5, by - 35 - bh),
		Vector2(bx, by - bh)
	]
	var stone_dark = Color(0.22, 0.22, 0.26)
	var stone_lit = Color(0.32, 0.32, 0.38)
	if not repaired:
		stone_dark = Color(0.18, 0.18, 0.20)
		stone_lit = Color(0.25, 0.25, 0.28)
	_fill_iso_polygon(img, left_wall, stone_dark)
	_fill_iso_polygon(img, right_wall, stone_lit)
	
	# Steep gothic roof
	var roof_top = Vector2(bx, by - bh - 65)
	var r_left: Array[Vector2] = [
		roof_top,
		Vector2(bx - bw * 0.5 - 5, by - 35 - bh),
		Vector2(bx, by - bh)
	]
	var r_right: Array[Vector2] = [
		roof_top,
		Vector2(bx + bw * 0.5 + 5, by - 35 - bh),
		Vector2(bx, by - bh)
	]
	var roof_col_left = Color(0.14, 0.14, 0.18)
	var roof_col_right = Color(0.24, 0.24, 0.30)
	_fill_iso_polygon(img, r_left, roof_col_left)
	_fill_iso_polygon(img, r_right, roof_col_right)
	
	# Entrance portal
	var door_x = bx - 15
	var door_y = by - 40
	for ix in range(door_x, door_x + 28):
		for iy in range(door_y, by):
			if iy < door_y + 8 and abs(ix - (door_x + 14)) > (iy - door_y) * 2:
				continue
			_set_pixel_alpha(img, ix, iy, Color(0.1, 0.1, 0.12))
	if repaired:
		# Warm interior light from library door
		_draw_radial_glow(img, door_x + 14, by - 15, 20, Color(1.0, 0.8, 0.3, 0.4))

func _draw_scholar_desk_with_book(img: Image, x: int, y: int) -> void:
	# Wooden desk
	for ix in range(x - 14, x + 15):
		for iy in range(y - 8, y + 2):
			_set_pixel_alpha(img, ix, iy, Color(0.32, 0.22, 0.15))
	# Open leather book
	for ix in range(x - 10, x + 11):
		for iy in range(y - 12, y - 6):
			_set_pixel_alpha(img, ix, iy, Color(0.85, 0.8, 0.65))
	_set_pixel_alpha(img, x, y - 9, Color(0.4, 0.15, 0.1)) # Spine
	# Quill & inkpot
	_set_pixel_alpha(img, x + 8, y - 10, Color(0.1, 0.1, 0.1))
	_set_pixel_alpha(img, x + 9, y - 13, Color(0.9, 0.9, 0.9))

func _draw_bookcase(img: Image, x: int, y: int) -> void:
	# Tall dark oak shelving
	for ix in range(x - 12, x + 13):
		for iy in range(y - 35, y):
			_set_pixel_alpha(img, ix, iy, Color(0.22, 0.15, 0.1))
	# Colorful book spines (red, blue, gold, green)
	for row in range(3):
		var ry = y - 28 + row * 10
		for ix in range(x - 9, x + 10):
			var c = Color(0.6, 0.15, 0.15)
			if ix % 4 == 1: c = Color(0.2, 0.3, 0.6)
			elif ix % 4 == 2: c = Color(0.7, 0.6, 0.2)
			elif ix % 4 == 3: c = Color(0.2, 0.5, 0.3)
			for iy in range(ry, ry + 7):
				_set_pixel_alpha(img, ix, iy, c)

func _draw_banner(img: Image, x: int, y: int, bg_col: Color, trim_col: Color) -> void:
	# Hanging heraldic banner
	for ix in range(x - 8, x + 9):
		for iy in range(y, y + 28):
			if iy > y + 20 and abs(ix - x) < (iy - (y + 20)) * 2:
				continue # V-cut bottom
			if ix == x - 8 or ix == x + 8:
				_set_pixel_alpha(img, ix, iy, trim_col)
			else:
				_set_pixel_alpha(img, ix, iy, bg_col)
	# Gold crest in center
	_set_pixel_alpha(img, x, y + 8, trim_col)
	_set_pixel_alpha(img, x, y + 9, trim_col)
	_set_pixel_alpha(img, x - 1, y + 9, trim_col)
	_set_pixel_alpha(img, x + 1, y + 9, trim_col)

func _draw_stained_glass(img: Image, x: int, y: int, w: int, h: int) -> void:
	# Gothic arched stained glass
	for ix in range(x - int(w * 0.5), x + int(w * 0.5)):
		for iy in range(y - int(h * 0.5), y + int(h * 0.5)):
			var dist = Vector2(ix, iy).distance_to(Vector2(x, y))
			if dist < w * 0.45:
				var c = Color(0.3, 0.5, 0.9, 0.9)
				if (ix + iy) % 6 < 3: c = Color(0.9, 0.4, 0.2, 0.9)
				_set_pixel_alpha(img, ix, iy, c)
	_draw_radial_glow(img, x, y, 25, Color(0.5, 0.6, 1.0, 0.35))

func _draw_memorial_plaque_wall(img: Image, x: int, y: int) -> void:
	# Carved bronze & stone plaques
	for r in range(2):
		for c in range(3):
			var px = x + c * 10
			var py = y + r * 12
			for ix in range(px, px + 8):
				for iy in range(py, py + 9):
					_set_pixel_alpha(img, ix, iy, Color(0.75, 0.6, 0.3))
			_set_pixel_alpha(img, px + 3, py + 4, Color(0.2, 0.15, 0.05))

func _draw_gargoyle(img: Image, x: int, y: int) -> void:
	# Stone gargoyle statue perched on buttress
	for ix in range(x - 5, x + 6):
		for iy in range(y - 10, y + 2):
			_set_pixel_alpha(img, ix, iy, Color(0.25, 0.25, 0.28))
	# Wings and horns
	_set_pixel_alpha(img, x - 5, y - 8, Color(0.35, 0.35, 0.38))
	_set_pixel_alpha(img, x + 5, y - 8, Color(0.35, 0.35, 0.38))

func _draw_ruined_market_stalls(img: Image, cx: int, cy: int) -> void:
	# Broken splintered planks, fallen beams, overturned barrels
	var rnd = [
		Vector2(-40, 5), Vector2(-20, -10), Vector2(10, 8), Vector2(35, -5),
		Vector2(-10, 15), Vector2(25, 20)
	]
	for pt in rnd:
		# Broken timber plank
		var p = Vector2(cx, cy) + pt
		for i in range(18):
			_set_pixel_alpha(img, int(p.x) + i, int(p.y) + int(i * 0.4), Color(0.25, 0.18, 0.12))
	# Smashed crate
	for ix in range(cx - 25, cx - 12):
		for iy in range(cy + 5, cy + 16):
			_set_pixel_alpha(img, ix, iy, Color(0.3, 0.22, 0.15))
	# Torn canvas scrap
	for ix in range(cx + 8, cx + 24):
		for iy in range(cy - 12, cy - 4):
			_set_pixel_alpha(img, ix, iy, Color(0.55, 0.5, 0.45, 0.7))

func _draw_merchant_stall(img: Image, cx: int, cy: int, w: int, h: int, col1: Color, col2: Color, wares: String) -> void:
	# Wooden counter
	var counter_top: Array[Vector2] = [
		Vector2(cx, cy - 8),
		Vector2(cx + w * 0.4, cy),
		Vector2(cx, cy + 8),
		Vector2(cx - w * 0.4, cy)
	]
	_fill_iso_polygon(img, counter_top, Color(0.38, 0.26, 0.18))
	# Wooden posts
	var post_h = h
	var posts = [
		Vector2(cx - w * 0.38, cy),
		Vector2(cx + w * 0.38, cy),
		Vector2(cx, cy - 8 - 4)
	]
	for p in posts:
		for iy in range(int(p.y) - post_h, int(p.y) + 1):
			_set_pixel_alpha(img, int(p.x), iy, Color(0.28, 0.18, 0.12))
			_set_pixel_alpha(img, int(p.x) + 1, iy, Color(0.32, 0.22, 0.15))
			
	# Striped fabric canopy
	var can_top = Vector2(cx, cy - post_h - 15)
	var can_left = Vector2(cx - w * 0.45, cy - post_h + 5)
	var can_right = Vector2(cx + w * 0.45, cy - post_h + 5)
	var can_front = Vector2(cx, cy - post_h + 15)
	_fill_iso_polygon(img, [can_top, can_left, can_front], col1)
	_fill_iso_polygon(img, [can_top, can_right, can_front], col2)
	# Scalloped awning edge
	for ix in range(int(can_left.x), int(can_right.x)):
		if ix % 6 < 3:
			_set_pixel_alpha(img, ix, int(can_front.y) + 2, col1)
		else:
			_set_pixel_alpha(img, ix, int(can_front.y) + 2, col2)
			
	# Wares on display
	if wares == "gear":
		# Cloaks, boots, leather bags
		for ix in range(cx - 15, cx - 2):
			for iy in range(cy - 6, cy + 2):
				_set_pixel_alpha(img, ix, iy, Color(0.2, 0.4, 0.25)) # Green cloak
		for ix in range(cx + 2, cx + 14):
			for iy in range(cy - 5, cy + 3):
				_set_pixel_alpha(img, ix, iy, Color(0.4, 0.25, 0.15)) # Leather backpack
	elif wares == "cards":
		# Card displays
		for c in range(4):
			var px = cx - 14 + c * 8
			var py = cy - 6
			for ix in range(px, px + 5):
				for iy in range(py - 8, py):
					_set_pixel_alpha(img, ix, iy, Color(0.85, 0.82, 0.7))
					if ix == px or ix == px + 4 or iy == py - 8 or iy == py - 1:
						_set_pixel_alpha(img, ix, iy, Color(0.2, 0.2, 0.3))
	elif wares == "dice":
		# Dice trays with bone and copper dice
		for ix in range(cx - 12, cx + 12):
			for iy in range(cy - 4, cy + 4):
				_set_pixel_alpha(img, ix, iy, Color(0.25, 0.18, 0.12)) # Tray
		# Bone dice (white)
		for ix in range(cx - 8, cx - 4):
			for iy in range(cy - 3, cy + 1):
				_set_pixel_alpha(img, ix, iy, Color(0.9, 0.88, 0.8))
		# Copper dice (orange/bronze)
		for ix in range(cx + 2, cx + 6):
			for iy in range(cy - 2, cy + 2):
				_set_pixel_alpha(img, ix, iy, Color(0.85, 0.5, 0.25))
	elif wares == "bazaar":
		# Exotic potion flasks, jewels, cloth
		for ix in range(cx - 16, cx - 8):
			for iy in range(cy - 6, cy):
				_set_pixel_alpha(img, ix, iy, Color(0.8, 0.2, 0.5))
		for ix in range(cx - 4, cx + 4):
			for iy in range(cy - 7, cy):
				_set_pixel_alpha(img, ix, iy, Color(0.2, 0.7, 0.8))
		for ix in range(cx + 8, cx + 16):
			for iy in range(cy - 6, cy):
				_set_pixel_alpha(img, ix, iy, Color(0.9, 0.75, 0.2))

func _draw_festive_pennants(img: Image, x1: int, y1: int, x2: int, y2: int) -> void:
	var dist = Vector2(x1, y1).distance_to(Vector2(x2, y2))
	var cols = [Color(0.85, 0.2, 0.2), Color(0.9, 0.75, 0.2), Color(0.2, 0.5, 0.8), Color(0.3, 0.7, 0.3)]
	for s in range(int(dist)):
		var t = float(s) / dist
		var sag = sin(t * PI) * 8.0
		var px = int(lerpf(x1, x2, t))
		var py = int(lerpf(y1, y2, t) + sag)
		_set_pixel_alpha(img, px, py, Color(0.15, 0.15, 0.15)) # String
		if s % 12 == 6:
			# Pennant triangle hanging down
			var col = cols[(s / 12) % cols.size()]
			for dy in range(6):
				for dx in range(-dy / 2, dy / 2 + 1):
					_set_pixel_alpha(img, px + dx, py + dy, col)

func _draw_alchemist_cottage_base(img: Image, stage: int) -> void:
	var bx = 128
	var by = 195
	var bw = 130
	var bh = 90
	
	# Masonry cottage walls
	var left_wall: Array[Vector2] = [
		Vector2(bx, by),
		Vector2(bx - bw * 0.5, by - 32),
		Vector2(bx - bw * 0.5, by - 32 - bh),
		Vector2(bx, by - bh)
	]
	var right_wall: Array[Vector2] = [
		Vector2(bx, by),
		Vector2(bx + bw * 0.5, by - 32),
		Vector2(bx + bw * 0.5, by - 32 - bh),
		Vector2(bx, by - bh)
	]
	var stone_left = Color(0.22, 0.20, 0.24)
	var stone_right = Color(0.30, 0.28, 0.32)
	_fill_iso_polygon(img, left_wall, stone_left)
	_fill_iso_polygon(img, right_wall, stone_right)
	
	# Roof
	var roof_top = Vector2(bx, by - bh - 55)
	var r_left: Array[Vector2] = [
		roof_top,
		Vector2(bx - bw * 0.5 - 6, by - 32 - bh),
		Vector2(bx, by - bh)
	]
	var r_right: Array[Vector2] = [
		roof_top,
		Vector2(bx + bw * 0.5 + 6, by - 32 - bh),
		Vector2(bx, by - bh)
	]
	var roof_l = Color(0.18, 0.15, 0.22)
	var roof_r = Color(0.28, 0.22, 0.32)
	if stage == 0:
		roof_l = Color(0.12, 0.12, 0.14)
		roof_r = Color(0.18, 0.18, 0.20)
	_fill_iso_polygon(img, r_left, roof_l)
	_fill_iso_polygon(img, r_right, roof_r)
	
	# Stone Chimney on left roof
	var ch_x = bx - 32
	var ch_y = by - bh - 40
	for ix in range(ch_x - 8, ch_x + 9):
		for iy in range(ch_y - 25, ch_y + 10):
			_set_pixel_alpha(img, ix, iy, Color(0.24, 0.22, 0.26))
			
	if stage == 0:
		# Broken cracks and dead vines
		for i in range(12):
			_set_pixel_alpha(img, bx - 10 + i, by - 50 + i * 2, Color(0.1, 0.1, 0.1))
			_set_pixel_alpha(img, bx + 20 + i, by - 60 - i, Color(0.15, 0.2, 0.12))
		_draw_boarded_window(img, bx + 15, by - 65, 16, 22)
	else:
		# Mystical glowing arched windows
		var win_glow = Color(0.3, 0.85, 0.4) # Emerald herbal glow
		if stage >= 2: win_glow = Color(0.7, 0.3, 0.9) # Arcane purple
		_draw_glowing_window(img, bx + 15, by - 65, 16, 22, win_glow)
		if stage >= 2:
			_draw_glowing_window(img, bx - 45, by - 65, 14, 18, Color(0.2, 0.9, 0.7))

func _draw_herb_drying_rack(img: Image, x: int, y: int) -> void:
	# Wooden A-frame rack with hung herbs
	for iy in range(y - 25, y + 1):
		_set_pixel_alpha(img, x - 10 + int((y - iy) * 0.3), iy, Color(0.3, 0.2, 0.15))
		_set_pixel_alpha(img, x + 10 - int((y - iy) * 0.3), iy, Color(0.3, 0.2, 0.15))
	# Cross bar
	for ix in range(x - 12, x + 13):
		_set_pixel_alpha(img, ix, y - 20, Color(0.32, 0.22, 0.16))
	# Hanging bundles of green and golden herbs
	for b in range(4):
		var hx = x - 8 + b * 5
		var col = Color(0.2, 0.5, 0.25)
		if b % 2 == 1: col = Color(0.65, 0.6, 0.25)
		for hy in range(y - 19, y - 8):
			_set_pixel_alpha(img, hx, hy, col)

func _draw_apothecary_table(img: Image, x: int, y: int, stage: int) -> void:
	# Stone workbench
	for ix in range(x - 18, x + 19):
		for iy in range(y - 8, y + 3):
			_set_pixel_alpha(img, ix, iy, Color(0.28, 0.28, 0.32))
	# Glass vials and potion bottles
	if stage >= 1:
		# Red and green vials
		_draw_vial(img, x - 10, y - 10, Color(0.9, 0.2, 0.25))
		_draw_vial(img, x - 4, y - 9, Color(0.25, 0.85, 0.35))
		# Mortar & pestle
		for ix in range(x + 5, x + 12):
			for iy in range(y - 7, y - 2):
				_set_pixel_alpha(img, ix, iy, Color(0.2, 0.2, 0.22))
		_set_pixel_alpha(img, x + 9, y - 9, Color(0.3, 0.2, 0.15))
	if stage >= 2:
		# Glass alembic distillation retort with glowing cyan liquid
		_draw_vial(img, x + 2, y - 12, Color(0.2, 0.7, 0.95))
		_draw_vial(img, x + 12, y - 11, Color(0.85, 0.3, 0.95))
		_draw_radial_glow(img, x, y - 10, 16, Color(0.3, 0.8, 0.6, 0.35))
	if stage >= 3:
		# Glowing magical runic apparatus
		_draw_radial_glow(img, x, y - 10, 22, Color(0.6, 0.2, 0.9, 0.45))

func _draw_vial(img: Image, x: int, y: int, col: Color) -> void:
	for ix in range(x - 2, x + 3):
		for iy in range(y - 4, y + 1):
			_set_pixel_alpha(img, ix, iy, col)
	# Glass highlight
	_set_pixel_alpha(img, x - 1, y - 3, Color(1, 1, 1, 0.8))
	# Cork stopper
	_set_pixel_alpha(img, x, y - 6, Color(0.5, 0.35, 0.2))
	_set_pixel_alpha(img, x, y - 5, Color(0.5, 0.35, 0.2))

func _draw_runic_sign(img: Image, x: int, y: int, glow_col: Color) -> void:
	# Hanging alchemist sign with glowing potion flask icon
	for ix in range(x - 10, x + 11):
		for iy in range(y - 8, y + 8):
			_set_pixel_alpha(img, ix, iy, Color(0.12, 0.1, 0.14))
	_draw_radial_glow(img, x, y, 14, Color(glow_col.r, glow_col.g, glow_col.b, 0.4))
	_set_pixel_alpha(img, x, y - 3, glow_col)
	_set_pixel_alpha(img, x - 2, y + 2, glow_col)
	_set_pixel_alpha(img, x + 2, y + 2, glow_col)
	_set_pixel_alpha(img, x, y + 2, glow_col)
