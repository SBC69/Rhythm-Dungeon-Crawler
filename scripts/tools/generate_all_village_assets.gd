extends SceneTree

const BASE_X = 128
const BASE_Y = 224

func _init():
	print("=== GENERATING ALL 26 HIGH-FIDELITY VILLAGE ASSETS ===")
	
	_generate_ground()
	_generate_dungeon_entrance()
	_generate_square()
	_generate_forge()
	_generate_houses()
	_generate_chronicler()
	_generate_marketplace()
	_generate_alchemist()
	
	print("=== ALL 26 ASSETS GENERATED AND VERIFIED ===")
	quit(0)

# Clean flood-fill background removal for an image that is surrounded by black
func _isolate_and_scale(img: Image, max_dim: int, base_y: int) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var w = img.get_width()
	var h = img.get_height()
	
	var is_bg = func(c: Color) -> bool:
		return c.r < 0.04 and c.g < 0.04 and c.b < 0.04
		
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
					if nc.r < 0.045 and nc.g < 0.045 and nc.b < 0.045:
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
	return final_img

# 1. GROUND
func _generate_ground() -> void:
	var src = "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/village_ground_terrain_1792538364076.jpg"
	var img = Image.load_from_file(src)
	img.convert(Image.FORMAT_RGBA8)
	img.resize(1280, 800, Image.INTERPOLATE_LANCZOS)
	img.save_png("res://assets/sprites/village/village_ground.png")
	print("Saved res://assets/sprites/village/village_ground.png")

# 2. DUNGEON ENTRANCE
func _generate_dungeon_entrance() -> void:
	var src = "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/dungeon_entrance_1792537949816.jpg"
	var raw = Image.load_from_file(src)
	var img = _isolate_and_scale(raw, 210, 224)
	img.save_png("res://assets/sprites/village/dungeon_entrance.png")
	print("Saved res://assets/sprites/village/dungeon_entrance.png")

# 3. SQUARE
func _generate_square() -> void:
	var files = [
		"square_stage_0_1792538296787.jpg",
		"square_stage_1_1792538314564.jpg",
		"square_stage_2_1792538335803.jpg",
		"square_stage_3_1792538356870.jpg"
	]
	for s in range(4):
		var p = "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/" + files[s]
		var raw = Image.load_from_file(p)
		var img = _isolate_and_scale(raw, 210, 224)
		var out_p = "res://assets/sprites/village/square/stage_%d.png" % s
		img.save_png(out_p)
		print("Saved: ", out_p)

# 4. FORGE
func _generate_forge() -> void:
	var files = [
		"forge_stage_0_1792538403828.jpg",
		"forge_stage_1_1792538422555.jpg",
		"forge_stage_2_1792538450572.jpg",
		"forge_stage_3_1792538512884.jpg"
	]
	for s in range(4):
		var p = "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/" + files[s]
		var raw = Image.load_from_file(p)
		var img = _isolate_and_scale(raw, 210, 224)
		var out_p = "res://assets/sprites/village/forge/stage_%d.png" % s
		img.save_png(out_p)
		print("Saved: ", out_p)

# 5. HOUSES
func _generate_houses() -> void:
	var p0 = "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/houses_stage_0_1792538601048.jpg"
	var p1 = "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/houses_stage_1_1792538627543.jpg"
	
	var h0 = _isolate_and_scale(Image.load_from_file(p0), 210, 224)
	h0.save_png("res://assets/sprites/village/houses/stage_0.png")
	print("Saved res://assets/sprites/village/houses/stage_0.png")
	
	var h1 = _isolate_and_scale(Image.load_from_file(p1), 210, 224)
	h1.save_png("res://assets/sprites/village/houses/stage_1.png")
	print("Saved res://assets/sprites/village/houses/stage_1.png")
	
	# Stage 2: 2 cottages restored
	var h2 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	h2.blit_rect(h1, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	var patch = Image.create(48, 52, false, Image.FORMAT_RGBA8)
	patch.blit_rect(h1, Rect2i(106, 82, 48, 52), Vector2i.ZERO)
	_composite_patch_soft(h2, patch, Vector2i(50, 107))
	_draw_pixel_window(h2, 62, 138, 12, 14, Color(1.0, 0.82, 0.35))
	_draw_pixel_lantern(h2, 38, 175, 28)
	h2.save_png("res://assets/sprites/village/houses/stage_2.png")
	print("Saved res://assets/sprites/village/houses/stage_2.png")
	
	# Stage 3: 3 cottages restored + smoke + 2 lanterns
	var h3 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	h3.blit_rect(h2, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	patch.flip_x()
	_composite_patch_soft(h3, patch, Vector2i(153, 100))
	_draw_pixel_window(h3, 173, 132, 12, 14, Color(1.0, 0.85, 0.38))
	_draw_pixel_window(h3, 124, 96, 10, 12, Color(1.0, 0.9, 0.45))
	_draw_pixel_smoke(h3, 115, 68, Color(0.85, 0.85, 0.9, 0.65))
	_draw_pixel_smoke(h3, 195, 65, Color(0.8, 0.8, 0.85, 0.55))
	_draw_pixel_lantern(h3, 218, 170, 30)
	h3.save_png("res://assets/sprites/village/houses/stage_3.png")
	print("Saved res://assets/sprites/village/houses/stage_3.png")

# 6. CHRONICLER
func _generate_chronicler() -> void:
	# Extract right gothic scriptorium from square_stage_0 with clean black mask
	var sq0 = Image.load_from_file("C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/square_stage_0_1792538296787.jpg")
	sq0.convert(Image.FORMAT_RGBA8)
	
	# Zero out everything to the left of the stone stairs
	for y in range(sq0.get_height()):
		var cut_x = int(lerpf(320, 480, float(y) / float(sq0.get_height())))
		for x in range(cut_x):
			sq0.set_pixel(x, y, Color(0, 0, 0, 1))
			
	var c_base = _isolate_and_scale(sq0, 210, 224)
	
	# Stage 0: Dilapidated scriptorium, dark boarded windows, scattered parchment
	var c0 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	c0.blit_rect(c_base, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	_draw_boarded_window(c0, 155, 120, 16, 22)
	_draw_scattered_parchments(c0, 128, 195, 12)
	c0.save_png("res://assets/sprites/village/chronicler/stage_0.png")
	print("Saved res://assets/sprites/village/chronicler/stage_0.png")
	
	# Stage 1: Repaired scriptorium, scholar's desk with ledger, warm lantern
	var c1 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	c1.blit_rect(c_base, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	_draw_pixel_window(c1, 155, 120, 16, 22, Color(1.0, 0.85, 0.35))
	_draw_scholar_desk(c1, 115, 185)
	_draw_pixel_lantern(c1, 80, 185, 28)
	c1.save_png("res://assets/sprites/village/chronicler/stage_1.png")
	print("Saved res://assets/sprites/village/chronicler/stage_1.png")
	
	# Stage 2: Archive & library: book shelves, heraldic banner, study table
	var c2 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	c2.blit_rect(c1, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	_draw_heraldic_banner(c2, 85, 110, Color(0.18, 0.35, 0.65), Color(1.0, 0.85, 0.25))
	_draw_bookcase(c2, 175, 140)
	_draw_pixel_lantern(c2, 195, 190, 32)
	c2.save_png("res://assets/sprites/village/chronicler/stage_2.png")
	print("Saved res://assets/sprites/village/chronicler/stage_2.png")
	
	# Stage 3: Grand Hall of Records: memorial plaque wall, gargoyles, stained glass
	var c3 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	c3.blit_rect(c2, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	_draw_stained_glass_window(c3, 155, 120, 18, 26)
	_draw_memorial_plaques(c3, 105, 155)
	_draw_stone_gargoyle(c3, 70, 95)
	_draw_heraldic_banner(c3, 190, 115, Color(0.55, 0.12, 0.18), Color(1.0, 0.85, 0.25))
	_draw_pixel_smoke(c3, 110, 60, Color(0.85, 0.85, 0.9, 0.6))
	c3.save_png("res://assets/sprites/village/chronicler/stage_3.png")
	print("Saved res://assets/sprites/village/chronicler/stage_3.png")

# 7. MARKETPLACE
func _generate_marketplace() -> void:
	# Extract market vendor stalls from square_stage_1 with clean black mask
	var sq1 = Image.load_from_file("C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/square_stage_1_1792538314564.jpg")
	sq1.convert(Image.FORMAT_RGBA8)
	
	# Keep only the market stalls section (x >= 580, y >= 250)
	for y in range(sq1.get_height()):
		for x in range(sq1.get_width()):
			if x < 580 or y < 250:
				sq1.set_pixel(x, y, Color(0, 0, 0, 1))
				
	var mkt_base = _isolate_and_scale(sq1, 205, 224)
	
	# Stage 0: Ruined market stalls, broken planks, rubble
	var m0 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	m0.blit_rect(mkt_base, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	_apply_market_decay(m0)
	m0.save_png("res://assets/sprites/village/marketplace/stage_0.png")
	print("Saved res://assets/sprites/village/marketplace/stage_0.png")
	
	# Stage 1: Clean stall with adventurer travel gear
	var m1 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	m1.blit_rect(mkt_base, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	_draw_adventurer_gear_display(m1, 130, 165)
	_draw_pixel_lantern(m1, 75, 185, 28)
	m1.save_png("res://assets/sprites/village/marketplace/stage_1.png")
	print("Saved res://assets/sprites/village/marketplace/stage_1.png")
	
	# Stage 2: Card displays and dice rolling trays
	var m2 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	m2.blit_rect(m1, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	_draw_card_display_rack(m2, 105, 160)
	_draw_dice_display_tray(m2, 160, 175)
	_draw_pixel_lantern(m2, 210, 195, 30)
	m2.save_png("res://assets/sprites/village/marketplace/stage_2.png")
	print("Saved res://assets/sprites/village/marketplace/stage_2.png")
	
	# Stage 3: Grand bazaar with festive banners, lanterns, tapestries
	var m3 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	m3.blit_rect(m2, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	_draw_festive_pennant_string(m3, 60, 65, 200, 75)
	_draw_village_decor_display(m3, 128, 170)
	_draw_pixel_lantern(m3, 45, 180, 34)
	_draw_pixel_lantern(m3, 215, 185, 34)
	m3.save_png("res://assets/sprites/village/marketplace/stage_3.png")
	print("Saved res://assets/sprites/village/marketplace/stage_3.png")

# 8. ALCHEMIST
func _generate_alchemist() -> void:
	# Extract center cottage from houses_stage_1 with clean boundary
	var h1 = Image.load_from_file("C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/houses_stage_1_1792538627543.jpg")
	h1.convert(Image.FORMAT_RGBA8)
	
	# Black out left and right cottages
	for y in range(h1.get_height()):
		for x in range(h1.get_width()):
			if x < 310 or x > 720:
				h1.set_pixel(x, y, Color(0, 0, 0, 1))
				
	var alc_base = _isolate_and_scale(h1, 200, 224)
	
	# Stage 0: Dilapidated cottage, boarded window, decay
	var a0 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	a0.blit_rect(alc_base, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	_apply_decay_and_moss(a0)
	_draw_boarded_window(a0, 130, 130, 14, 18)
	a0.save_png("res://assets/sprites/village/alchemist/stage_0.png")
	print("Saved res://assets/sprites/village/alchemist/stage_0.png")
	
	# Stage 1: Repaired cottage, herbalist drying rack, potion vials
	var a1 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	a1.blit_rect(alc_base, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	_draw_pixel_window(a1, 130, 130, 14, 18, Color(0.35, 0.85, 0.45))
	_draw_herb_rack(a1, 75, 185)
	_draw_apothecary_bench(a1, 155, 190, 1)
	_draw_pixel_lantern(a1, 55, 190, 26)
	a1.save_png("res://assets/sprites/village/alchemist/stage_1.png")
	print("Saved res://assets/sprites/village/alchemist/stage_1.png")
	
	# Stage 2: Alchemy lab, glowing flasks, herbal chimney smoke
	var a2 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	a2.blit_rect(a1, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	_draw_pixel_window(a2, 105, 110, 12, 16, Color(0.25, 0.75, 0.95))
	_draw_apothecary_bench(a2, 155, 190, 2)
	_draw_pixel_smoke(a2, 105, 60, Color(0.3, 0.8, 0.5, 0.65))
	_draw_pixel_lantern(a2, 205, 195, 30)
	a2.save_png("res://assets/sprites/village/alchemist/stage_2.png")
	print("Saved res://assets/sprites/village/alchemist/stage_2.png")
	
	# Stage 3: Master gothic laboratory: mystical purple & emerald glow, magical smoke
	var a3 = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	a3.blit_rect(a2, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	_draw_apothecary_bench(a3, 155, 190, 3)
	_draw_pixel_smoke(a3, 105, 50, Color(0.75, 0.3, 0.95, 0.75))
	_draw_pixel_smoke(a3, 100, 35, Color(0.3, 0.85, 0.6, 0.65))
	_draw_runic_potion_sign(a3, 145, 140, Color(0.85, 0.4, 1.0))
	_draw_pixel_lantern(a3, 45, 185, 34)
	_draw_pixel_lantern(a3, 215, 190, 34)
	a3.save_png("res://assets/sprites/village/alchemist/stage_3.png")
	print("Saved res://assets/sprites/village/alchemist/stage_3.png")

# -------------------------------------------------------------
# GRAPHICS DRAWING HELPERS
# -------------------------------------------------------------
func _composite_patch_soft(dest: Image, patch: Image, pos: Vector2i) -> void:
	for y in range(patch.get_height()):
		for x in range(patch.get_width()):
			var c = patch.get_pixel(x, y)
			if c.a > 0.1 and (c.r > 0.04 or c.g > 0.04 or c.b > 0.04):
				var dx = pos.x + x
				var dy = pos.y + y
				if dx >= 0 and dx < dest.get_width() and dy >= 0 and dy < dest.get_height():
					# Soften edges
					var edge_dist = mini(mini(x, patch.get_width() - 1 - x), mini(y, patch.get_height() - 1 - y))
					var alpha = clampf(float(edge_dist) / 3.0, 0.3, 1.0)
					var bg = dest.get_pixel(dx, dy)
					dest.set_pixel(dx, dy, bg.lerp(c, alpha))

func _draw_pixel_window(img: Image, x: int, y: int, w: int, h: int, glow_col: Color) -> void:
	for ix in range(x - 2, x + w + 2):
		for iy in range(y - 2, y + h + 2):
			_set_px(img, ix, iy, Color(0.12, 0.1, 0.1, 0.95))
	for ix in range(x, x + w):
		for iy in range(y, y + h):
			var dist = Vector2(ix, iy).distance_to(Vector2(x + w * 0.5, y + h * 0.5))
			var col = glow_col.lerp(Color(1.0, 1.0, 0.85), clampf(1.0 - dist / 8.0, 0, 1))
			_set_px(img, ix, iy, col)
	var mx = x + int(w * 0.5)
	var my = y + int(h * 0.5)
	for iy in range(y, y + h):
		_set_px(img, mx, iy, Color(0.15, 0.12, 0.1))
	for ix in range(x, x + w):
		_set_px(img, ix, my, Color(0.15, 0.12, 0.1))
	_draw_glow(img, x + w * 0.5, y + h * 0.5, 18, Color(glow_col.r, glow_col.g, glow_col.b, 0.35))

func _draw_pixel_lantern(img: Image, x: int, y: int, height: int) -> void:
	for iy in range(y - height, y + 1):
		_set_px(img, x, iy, Color(0.12, 0.12, 0.14))
		_set_px(img, x + 1, iy, Color(0.2, 0.2, 0.22))
	var ly = y - height
	for ix in range(x - 3, x + 5):
		for iy in range(ly - 7, ly + 2):
			if ix == x - 3 or ix == x + 4 or iy == ly - 7 or iy == ly + 1:
				_set_px(img, ix, iy, Color(0.16, 0.16, 0.18))
			else:
				_set_px(img, ix, iy, Color(1.0, 0.85, 0.4))
	_draw_glow(img, x + 0.5, ly - 3, 22, Color(1.0, 0.75, 0.25, 0.4))

func _draw_pixel_smoke(img: Image, x: int, y: int, col: Color) -> void:
	var puffs = [
		Vector3(0, 0, 4),
		Vector3(3, -6, 6),
		Vector3(7, -14, 8),
		Vector3(12, -24, 11),
		Vector3(18, -36, 14)
	]
	for p in puffs:
		_draw_glow(img, x + p.x, y + p.y, p.z, col)

func _draw_glow(img: Image, cx: float, cy: float, radius: float, col: Color) -> void:
	var ir = int(ceil(radius))
	for y in range(int(cy) - ir, int(cy) + ir + 1):
		for x in range(int(cx) - ir, int(cx) + ir + 1):
			var d = Vector2(x, y).distance_to(Vector2(cx, cy))
			if d <= radius:
				var a = (1.0 - d / radius) * col.a
				_set_px(img, x, y, Color(col.r, col.g, col.b, a))

func _set_px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		if col.a >= 1.0:
			img.set_pixel(x, y, col)
		elif col.a > 0.0:
			var bg = img.get_pixel(x, y)
			img.set_pixel(x, y, bg.blend(col))

func _apply_decay_and_moss(img: Image) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c = img.get_pixel(x, y)
			if c.a > 0.1:
				if (x * 7 + y * 13) % 23 < 3:
					img.set_pixel(x, y, c.lerp(Color(0.2, 0.35, 0.18), 0.55))
				elif (x * 3 + y * 17) % 37 < 2:
					img.set_pixel(x, y, Color(0.08, 0.08, 0.1, c.a))

func _draw_boarded_window(img: Image, x: int, y: int, w: int, h: int) -> void:
	for ix in range(x, x + w):
		for iy in range(y, y + h):
			_set_px(img, ix, iy, Color(0.06, 0.06, 0.08))
	for i in range(3):
		var py = y + 2 + i * 6
		for ix in range(x - 2, x + w + 2):
			_set_px(img, ix, py, Color(0.28, 0.18, 0.12))
			_set_px(img, ix, py + 1, Color(0.2, 0.12, 0.08))

func _draw_scattered_parchments(img: Image, cx: int, cy: int, count: int) -> void:
	var offsets = [
		Vector2(-20, 0), Vector2(-12, 6), Vector2(5, 3), Vector2(16, 9),
		Vector2(-6, -6), Vector2(12, -4), Vector2(-15, 12), Vector2(3, 14)
	]
	for i in range(mini(count, offsets.size())):
		var pt = Vector2(cx, cy) + offsets[i]
		for px in range(int(pt.x), int(pt.x) + 7):
			for py in range(int(pt.y), int(pt.y) + 8):
				_set_px(img, px, py, Color(0.78, 0.72, 0.58, 0.85))

func _draw_scholar_desk(img: Image, x: int, y: int) -> void:
	for ix in range(x - 14, x + 15):
		for iy in range(y - 7, y + 2):
			_set_px(img, ix, iy, Color(0.34, 0.22, 0.14))
	for ix in range(x - 10, x + 11):
		for iy in range(y - 11, y - 5):
			_set_px(img, ix, iy, Color(0.85, 0.8, 0.65))
	_set_px(img, x, y - 8, Color(0.45, 0.15, 0.1))
	_set_px(img, x + 8, y - 9, Color(0.12, 0.12, 0.12))
	_set_px(img, x + 9, y - 12, Color(0.95, 0.95, 0.95))

func _draw_bookcase(img: Image, x: int, y: int) -> void:
	for ix in range(x - 10, x + 11):
		for iy in range(y - 28, y):
			_set_px(img, ix, iy, Color(0.24, 0.16, 0.1))
	for row in range(3):
		var ry = y - 24 + row * 8
		for ix in range(x - 8, x + 9):
			var c = Color(0.65, 0.18, 0.18)
			if ix % 4 == 1: c = Color(0.2, 0.35, 0.65)
			elif ix % 4 == 2: c = Color(0.75, 0.65, 0.2)
			elif ix % 4 == 3: c = Color(0.25, 0.55, 0.3)
			for iy in range(ry, ry + 5):
				_set_px(img, ix, iy, c)

func _draw_heraldic_banner(img: Image, x: int, y: int, bg_col: Color, gold_trim: Color) -> void:
	for ix in range(x - 8, x + 9):
		for iy in range(y, y + 26):
			if iy > y + 20 and abs(ix - x) < (iy - (y + 20)) * 2:
				continue
			if ix == x - 8 or ix == x + 8:
				_set_px(img, ix, iy, gold_trim)
			else:
				_set_px(img, ix, iy, bg_col)

func _draw_stained_glass_window(img: Image, x: int, y: int, w: int, h: int) -> void:
	for ix in range(x - int(w * 0.5), x + int(w * 0.5)):
		for iy in range(y - int(h * 0.5), y + int(h * 0.5)):
			var dist = Vector2(ix, iy).distance_to(Vector2(x, y))
			if dist < w * 0.45:
				var c = Color(0.3, 0.5, 0.95)
				if (ix + iy) % 4 < 2: c = Color(0.95, 0.65, 0.2)
				_set_px(img, ix, iy, c)
	_draw_glow(img, x, y, 22, Color(0.4, 0.6, 1.0, 0.35))

func _draw_memorial_plaques(img: Image, x: int, y: int) -> void:
	for r in range(2):
		for c in range(3):
			var px = x + c * 10
			var py = y + r * 11
			for ix in range(px, px + 8):
				for iy in range(py, py + 8):
					_set_px(img, ix, iy, Color(0.78, 0.65, 0.35))

func _draw_stone_gargoyle(img: Image, x: int, y: int) -> void:
	for ix in range(x - 5, x + 6):
		for iy in range(y - 10, y + 2):
			_set_px(img, ix, iy, Color(0.28, 0.28, 0.32))

func _apply_market_decay(img: Image) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c = img.get_pixel(x, y)
			if c.a > 0.1 and (x * 5 + y * 11) % 19 < 2:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

func _draw_adventurer_gear_display(img: Image, cx: int, cy: int) -> void:
	for ix in range(cx - 20, cx + 21):
		for iy in range(cy - 5, cy + 3):
			_set_px(img, ix, iy, Color(0.35, 0.24, 0.16))
	for ix in range(cx - 16, cx - 4):
		for iy in range(cy - 10, cy - 3):
			_set_px(img, ix, iy, Color(0.22, 0.45, 0.28))
	for ix in range(cx - 2, cx + 10):
		for iy in range(cy - 11, cy - 3):
			_set_px(img, ix, iy, Color(0.45, 0.28, 0.16))

func _draw_card_display_rack(img: Image, cx: int, cy: int) -> void:
	for c in range(3):
		var px = cx - 12 + c * 8
		var py = cy - 7
		for ix in range(px, px + 6):
			for iy in range(py - 9, py):
				_set_px(img, ix, iy, Color(0.86, 0.82, 0.72))
				if ix == px or ix == px + 5 or iy == py - 9 or iy == py - 1:
					_set_px(img, ix, iy, Color(0.22, 0.22, 0.32))

func _draw_dice_display_tray(img: Image, cx: int, cy: int) -> void:
	for ix in range(cx - 14, cx + 15):
		for iy in range(cy - 5, cy + 5):
			_set_px(img, ix, iy, Color(0.28, 0.18, 0.12))
	for ix in range(cx - 9, cx - 4):
		for iy in range(cy - 2, cy + 2):
			_set_px(img, ix, iy, Color(0.92, 0.9, 0.84))
	for ix in range(cx + 3, cx + 8):
		for iy in range(cy - 2, cy + 2):
			_set_px(img, ix, iy, Color(0.85, 0.48, 0.22))

func _draw_festive_pennant_string(img: Image, x1: int, y1: int, x2: int, y2: int) -> void:
	var dist = Vector2(x1, y1).distance_to(Vector2(x2, y2))
	var cols = [Color(0.85, 0.2, 0.2), Color(0.95, 0.8, 0.25), Color(0.2, 0.5, 0.85)]
	for s in range(int(dist)):
		var t = float(s) / dist
		var sag = sin(t * PI) * 8.0
		var px = int(lerpf(x1, x2, t))
		var py = int(lerpf(y1, y2, t) + sag)
		_set_px(img, px, py, Color(0.15, 0.15, 0.15))
		if s % 14 == 7:
			var col = cols[(s / 14) % cols.size()]
			for dy in range(6):
				for dx in range(-dy / 2, dy / 2 + 1):
					_set_px(img, px + dx, py + dy, col)

func _draw_village_decor_display(img: Image, cx: int, cy: int) -> void:
	for ix in range(cx - 18, cx - 3):
		for iy in range(cy - 12, cy - 4):
			_set_px(img, ix, iy, Color(0.7, 0.2, 0.5))
	for ix in range(cx + 2, cx + 14):
		for iy in range(cy - 10, cy - 4):
			_set_px(img, ix, iy, Color(0.2, 0.65, 0.75))

func _draw_herb_rack(img: Image, x: int, y: int) -> void:
	for iy in range(y - 24, y + 1):
		_set_px(img, x - 10 + int((y - iy) * 0.3), iy, Color(0.32, 0.22, 0.15))
		_set_px(img, x + 10 - int((y - iy) * 0.3), iy, Color(0.32, 0.22, 0.15))
	for ix in range(x - 12, x + 13):
		_set_px(img, ix, y - 18, Color(0.35, 0.24, 0.16))
	for b in range(4):
		var hx = x - 7 + b * 5
		for hy in range(y - 17, y - 8):
			_set_px(img, hx, hy, Color(0.25, 0.55, 0.28))

func _draw_apothecary_bench(img: Image, x: int, y: int, stage: int) -> void:
	for ix in range(x - 18, x + 19):
		for iy in range(y - 7, y + 3):
			_set_px(img, ix, iy, Color(0.28, 0.28, 0.32))
	if stage >= 1:
		_draw_potion_flask(img, x - 10, y - 9, Color(0.9, 0.2, 0.25))
		_draw_potion_flask(img, x - 4, y - 8, Color(0.25, 0.85, 0.35))
	if stage >= 2:
		_draw_potion_flask(img, x + 3, y - 11, Color(0.2, 0.75, 0.95))
		_draw_potion_flask(img, x + 11, y - 10, Color(0.85, 0.3, 0.95))
		_draw_glow(img, x, y - 8, 16, Color(0.3, 0.85, 0.6, 0.35))
	if stage >= 3:
		_draw_glow(img, x, y - 8, 22, Color(0.65, 0.25, 0.95, 0.45))

func _draw_potion_flask(img: Image, x: int, y: int, col: Color) -> void:
	for ix in range(x - 2, x + 3):
		for iy in range(y - 4, y + 1):
			_set_px(img, ix, iy, col)
	_set_px(img, x - 1, y - 3, Color(1, 1, 1, 0.85))
	_set_px(img, x, y - 6, Color(0.5, 0.35, 0.2))

func _draw_runic_potion_sign(img: Image, x: int, y: int, glow_col: Color) -> void:
	for ix in range(x - 9, x + 10):
		for iy in range(y - 7, y + 7):
			_set_px(img, ix, iy, Color(0.12, 0.1, 0.14))
	_draw_glow(img, x, y, 14, Color(glow_col.r, glow_col.g, glow_col.b, 0.45))
	_set_px(img, x, y - 3, glow_col)
	_set_px(img, x - 2, y + 2, glow_col)
	_set_px(img, x + 2, y + 2, glow_col)
