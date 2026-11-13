# scripts/tools/generate_village_sprites.gd
extends SceneTree

const BASE_X = 128
const BASE_Y = 224

func _iso(x: float, y: float, z: float) -> Vector2:
	var sx = BASE_X + (x - y) * 1.5
	var sy = BASE_Y + (x + y) * 0.75 - z
	return Vector2(sx, sy)

func _set_p(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		if col.a <= 0.0:
			return
		if col.a >= 1.0:
			img.set_pixel(x, y, col)
		else:
			var bg = img.get_pixel(x, y)
			img.set_pixel(x, y, bg.blend(col))

func _draw_line(img: Image, p1: Vector2, p2: Vector2, col: Color) -> void:
	var dist = p1.distance_to(p2)
	var steps = int(maxf(1.0, dist * 1.5))
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var p = p1.lerp(p2, t)
		_set_p(img, int(round(p.x)), int(round(p.y)), col)

func _fill_poly(img: Image, pts: Array[Vector2], col: Color) -> void:
	if pts.size() < 3:
		return
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
					_set_p(img, x, y, col)

func _draw_iso_box(img: Image, x: float, y: float, z: float, sx: float, sy: float, sz: float, col_top: Color, col_left: Color, col_right: Color, col_border: Color = Color(0,0,0,0)) -> void:
	# Vertices: bottom: (0,0), (sx,0), (sx,sy), (0,sy) at z
	# top: same at z+sz
	var b0 = _iso(x, y, z)
	var b1 = _iso(x + sx, y, z)
	var b2 = _iso(x + sx, y + sy, z)
	var b3 = _iso(x, y + sy, z)

	var t0 = _iso(x, y, z + sz)
	var t1 = _iso(x + sx, y, z + sz)
	var t2 = _iso(x + sx, y + sy, z + sz)
	var t3 = _iso(x, y + sy, z + sz)

	# Left face: (b0, b3, t3, t0) -> x side facing left
	var left_pts: Array[Vector2] = [b0, b3, t3, t0]
	_fill_poly(img, left_pts, col_left)

	# Right face: (b0, b1, t1, t0) -> y side facing right
	var right_pts: Array[Vector2] = [b0, b1, t1, t0]
	_fill_poly(img, right_pts, col_right)

	# Top face: (t0, t1, t2, t3)
	var top_pts: Array[Vector2] = [t0, t1, t2, t3]
	_fill_poly(img, top_pts, col_top)

	if col_border.a > 0:
		_draw_line(img, t0, t1, col_border)
		_draw_line(img, t1, t2, col_border)
		_draw_line(img, t2, t3, col_border)
		_draw_line(img, t3, t0, col_border)
		_draw_line(img, b0, t0, col_border)
		_draw_line(img, b1, t1, col_border)
		_draw_line(img, b3, t3, col_border)

func _draw_iso_roof(img: Image, x: float, y: float, z: float, sx: float, sy: float, sz: float, col_left: Color, col_right: Color, col_border: Color = Color(0,0,0,0)) -> void:
	var b0 = _iso(x, y, z)
	var b1 = _iso(x + sx, y, z)
	var b2 = _iso(x + sx, y + sy, z)
	var b3 = _iso(x, y + sy, z)

	var ridge0 = _iso(x, y + sy * 0.5, z + sz)
	var ridge1 = _iso(x + sx, y + sy * 0.5, z + sz)

	# Front slope: b0, b1, ridge1, ridge0
	var slope1: Array[Vector2] = [b0, b1, ridge1, ridge0]
	_fill_poly(img, slope1, col_right)

	# Back slope: b3, b2, ridge1, ridge0
	var slope2: Array[Vector2] = [b3, b2, ridge1, ridge0]
	_fill_poly(img, slope2, col_left)

	# Gable left: b0, b3, ridge0
	var gable_l: Array[Vector2] = [b0, b3, ridge0]
	_fill_poly(img, gable_l, col_left.darkened(0.15))

	# Gable right: b1, b2, ridge1
	var gable_r: Array[Vector2] = [b1, b2, ridge1]
	_fill_poly(img, gable_r, col_right.darkened(0.15))

	if col_border.a > 0:
		_draw_line(img, ridge0, ridge1, col_border)
		_draw_line(img, b0, ridge0, col_border)
		_draw_line(img, b1, ridge1, col_border)
		_draw_line(img, b0, b1, col_border)

var _started := false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run.call_deferred()
	return false

func _run() -> void:
	print("--- Generating 24 Village Sprites + Dungeon Entrance + Village Ground ---")
	# Procedural fallbacks are previews. Never silently overwrite reviewed production art.
	var base_dir = "res://assets/sprites/village" if "--write-assets" in OS.get_cmdline_user_args() else "user://village-sprite-preview"
	DirAccess.make_dir_recursive_absolute(base_dir)

	for obj in ["square", "houses", "chronicler", "marketplace", "forge", "alchemist"]:
		DirAccess.make_dir_recursive_absolute(base_dir.path_join(obj))
		for stage in [0, 1, 2, 3]:
			var img = Image.create(256, 256, false, Image.FORMAT_RGBA8)
			img.fill(Color(0, 0, 0, 0))
			_render_object(img, obj, stage)
			var path = base_dir.path_join("%s/stage_%d.png" % [obj, stage])
			img.save_png(path)
			print("Saved: ", path)

	# Dungeon entrance
	var img_dung = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img_dung.fill(Color(0, 0, 0, 0))
	_render_dungeon_entrance(img_dung)
	img_dung.save_png(base_dir.path_join("dungeon_entrance.png"))
	print("Saved: ", base_dir.path_join("dungeon_entrance.png"))

	# Ground layout
	var img_ground = Image.create(1280, 800, false, Image.FORMAT_RGBA8)
	_render_ground(img_ground)
	img_ground.save_png(base_dir.path_join("village_ground.png"))
	print("Saved: ", base_dir.path_join("village_ground.png"))

	print("ALL VILLAGE ASSETS GENERATED CLEANLY.")
	quit(0)

func _render_object(img: Image, obj: String, stage: int) -> void:
	match obj:
		"square": _render_square(img, stage)
		"houses": _render_houses(img, stage)
		"chronicler": _render_chronicler(img, stage)
		"marketplace": _render_marketplace(img, stage)
		"forge": _render_forge(img, stage)
		"alchemist": _render_alchemist(img, stage)

# All six silhouettes share the 128,224 ground anchor. Details follow the approved catalog.
func _box(img: Image, x: float, y: float, z: float, w: float, d: float, h: float, color: Color) -> void:
	_draw_iso_box(img, x, y, z, w, d, h, color.lightened(0.12), color.darkened(0.25), color, Color(0.10, 0.09, 0.12, 0.9))

func _foundation(img: Image, stage: int) -> void:
	_box(img, -40, -40, 0, 80, 80, 3, Color("756b57") if stage > 0 else Color("4b5042"))
	for i in range(5):
		_draw_line(img, _iso(-38 + i * 16, -38, 3), _iso(-38 + i * 16, 38, 3), Color("5b5548"))

func _house(img: Image, x: float, y: float, complete: bool, roof_color: Color) -> void:
	_box(img, x, y, 3, 26, 28, 32 if complete else 14, Color("bcab88") if complete else Color("687064"))
	if complete:
		_draw_iso_roof(img, x - 1, y - 1, 35, 28, 30, 19, roof_color, roof_color.darkened(0.18), Color("443c36"))
		_box(img, x + 7, y - 1, 3, 9, 2, 17, Color("523e31"))
		_box(img, x + 19, y - 1, 19, 5, 2, 7, Color("ffd787"))
		_box(img, x + 19, y + 18, 40, 5, 5, 16, Color("827c71"))
	else:
		_box(img, x + 3, y + 4, 3, 8, 7, 5, Color("59574e"))
		_draw_line(img, _iso(x, y, 15), _iso(x + 26, y, 5), Color("493b2b"))

func _sign(img: Image, x: float, y: float, broken: bool = false) -> void:
	_box(img, x, y, 3, 2, 2, 13 if broken else 26, Color("725334"))
	_box(img, x - 7, y, 12 if broken else 24, 17, 3, 6, Color("bd9556"))

func _person(img: Image, x: float, y: float, color: Color) -> void:
	_box(img, x, y, 4, 4, 4, 9, color)
	_box(img, x, y, 13, 4, 4, 4, Color("e0ba92"))

func _table(img: Image, x: float, y: float, width: float = 24) -> void:
	for dx in [0, width - 3]:
		_box(img, x + dx, y, 3, 3, 11, 14, Color("715035"))
	_box(img, x - 1, y - 1, 17, width + 2, 13, 3, Color("ac8455"))

func _book(img: Image, x: float, y: float, z: float, color: Color) -> void:
	_box(img, x, y, z, 9, 7, 2, color)
	_draw_line(img, _iso(x + 4, y, z + 2), _iso(x + 4, y + 7, z + 2), Color("f6e7b9"))

func _bottle(img: Image, x: float, y: float, z: float, color: Color) -> void:
	_box(img, x, y, z, 5, 5, 7, color)
	_box(img, x + 1, y + 1, z + 7, 3, 3, 4, color.lightened(0.35))

func _render_square(img: Image, stage: int) -> void:
	_foundation(img, stage)
	_sign(img, -30, 9, stage == 0)
	if stage == 0:
		for i in range(5):
			_box(img, -23 + i * 8, -15 + (i % 2) * 12, 3, 11, 9, 5 + i, Color("64665c"))
	if stage >= 2:
		_box(img, -15, -15, 3, 27, 27, 11, Color("ada995"))
		_box(img, -11, -11, 14, 19, 19, 1, Color("487c8a"))
		for xy in [Vector2(-29, -26), Vector2(27, 17)]:
			_box(img, xy.x, xy.y, 3, 3, 3, 29, Color("494443"))
			_box(img, xy.x - 2, xy.y - 2, 31, 7, 7, 7, Color("f2c56b"))
		_person(img, 24, -12, Color("879ca5"))
		_person(img, -15, 22, Color("b27564"))
	if stage == 3:
		_box(img, 13, 5, 3, 13, 13, 6, Color("b0a180"))
		_box(img, 16, 8, 9, 7, 7, 32, Color("c6ba8b"))
		_box(img, 14, 6, 41, 11, 11, 5, Color("e6c778"))

func _render_houses(img: Image, stage: int) -> void:
	_foundation(img, stage)
	# Three separate homes remain identifiable throughout restoration.
	_house(img, -35, -35, stage >= 1, Color("a45f4e"))
	_house(img, 7, -35, stage >= 2, Color("857c52"))
	_house(img, -17, 7, stage >= 3, Color("677e8b"))
	if stage >= 1:
		_person(img, 20, 20, Color("bd9673"))
	if stage >= 2:
		_box(img, 24, 5, 3, 7, 12, 4, Color("526f48"))

func _render_chronicler(img: Image, stage: int) -> void:
	_foundation(img, stage)
	# A cutaway room exposes the journal, comparison desk and memorial wall.
	_box(img, -31, -30, 3, 62, 3, 45 if stage > 0 else 23, Color("8c877d"))
	_box(img, -31, -30, 3, 3, 54, 38 if stage > 0 else 16, Color("75796c"))
	if stage == 0:
		_box(img, -10, -20, 3, 20, 3, 24, Color("51463b"))
		for i in range(4):
			_book(img, -10 + i * 8, 10, 3, Color("a5ad98"))
	else:
		_table(img, -15, -1, 30 if stage >= 2 else 24)
		_book(img, -8, 0, 20, Color("d3c39a"))
		if stage >= 2:
			_book(img, 4, 0, 20, Color("98a9a4"))
			_box(img, -26, -25, 3, 15, 8, 34, Color("705640"))
			for i in range(5):
				_box(img, -25 + i * 3, -26, 17, 2, 3, 13, Color("aba16b") if i % 2 else Color("8b6267"))
		if stage == 3:
			for i in range(3):
				_box(img, -3 + i * 10, -31, 23, 7, 2, 15, Color("d9c49a"))
				_draw_line(img, _iso(i * 10 - 1, -32, 32), _iso(i * 10 + 3, -32, 32), Color("6f5f50"))
		_sign(img, 27, 19)

func _render_marketplace(img: Image, stage: int) -> void:
	_foundation(img, stage)
	for i in range(3):
		var x = -34 + i * 23
		_table(img, x, -10, 19)
		if stage > i:
			for dx in [0, 17]:
				_box(img, x + dx, -9, 20, 2, 2, 20, Color("71553b"))
			var color = [Color("aa6a5d"), Color("698b99"), Color("bc9a62")][i]
			_draw_iso_roof(img, x - 2, -14, 39, 23, 20, 7, color.lightened(0.2), color)
			if i == 0:
				_box(img, x + 5, -10, 21, 9, 3, 12, Color("6a887a"))
			elif i == 1:
				_book(img, x + 1, -5, 20, Color("b7a0b0"))
				_box(img, x + 12, -4, 20, 5, 5, 5, Color("daceb2"))
			else:
				_sign(img, x + 6, 11)
				_draw_line(img, _iso(x, -12, 48), _iso(x + 18, -12, 48), Color("d8bf80"))

func _render_forge(img: Image, stage: int) -> void:
	_foundation(img, stage)
	_box(img, -26, -27, 3, 26, 26, 18 if stage == 0 else 31, Color("737779"))
	if stage > 0:
		_box(img, -20, -28, 6, 15, 2, 17, Color("ed9753"))
		_box(img, -22, -21, 34, 9, 9, 27, Color("7d7a70"))
		_draw_iso_roof(img, -31, 7, 48, 62, 16, 13, Color("7f6454"), Color("695346"))
		_box(img, 22, -22, 3, 3, 3, 35, Color("786046"))
	_box(img, 1, 7, 3, 9, 10, 12, Color("73695b"))
	_box(img, -2, 5, 15, 17, 14, 5, Color("899399"))
	if stage >= 2:
		_table(img, 8, -8, 24)
		_draw_line(img, _iso(12, -4, 21), _iso(29, -4, 21), Color("c4c8c5"))
	if stage == 3:
		_sign(img, 25, 17)
		_box(img, 22, 16, 26, 4, 4, 5, Color("aab6bd"))

func _render_alchemist(img: Image, stage: int) -> void:
	_foundation(img, stage)
	_box(img, -29, -29, 3, 58, 3, 40 if stage > 0 else 17, Color("8b927f"))
	_box(img, -29, -29, 3, 3, 52, 32 if stage > 0 else 10, Color("687d68"))
	if stage > 0:
		_table(img, -15, -2, 31)
		_bottle(img, -10, 0, 20, Color("7eae79"))
		_bottle(img, 2, 0, 20, Color("ae778c"))
		_box(img, -21, 12, 3, 9, 7, 3, Color("64864c"))
	if stage >= 2:
		_box(img, -20, -24, 21, 39, 7, 3, Color("8b684a"))
		for i in range(4):
			_bottle(img, -17 + i * 9, -23, 24, Color("7aa6a4") if i % 2 else Color("a4a16c"))
	if stage == 3:
		_table(img, 17, 12, 17)
		_bottle(img, 20, 13, 20, Color("bba072"))
		_draw_iso_roof(img, -33, -31, 44, 64, 14, 11, Color("617f6d"), Color("4f695a"))
		_sign(img, 27, -4)

func _render_dungeon_entrance(img: Image) -> void:
	# Stone archway into dark abyss with stairs and torches
	_draw_iso_box(img, -45, -35, 0, 90, 70, 20, Color(0.35, 0.35, 0.38), Color(0.22, 0.22, 0.25), Color(0.28, 0.28, 0.32))
	# Arch columns
	_draw_iso_box(img, -40, -30, 20, 18, 18, 55, Color(0.45, 0.45, 0.48), Color(0.3, 0.3, 0.34), Color(0.36, 0.36, 0.4))
	_draw_iso_box(img, 22, -30, 20, 18, 18, 55, Color(0.45, 0.45, 0.48), Color(0.3, 0.3, 0.34), Color(0.36, 0.36, 0.4))
	# Arch top lintel
	_draw_iso_box(img, -45, -32, 75, 90, 22, 18, Color(0.5, 0.5, 0.55), Color(0.35, 0.35, 0.4), Color(0.42, 0.42, 0.48))
	# Dark void inside arch
	_draw_iso_box(img, -22, -28, 20, 44, 14, 55, Color(0.05, 0.02, 0.08), Color(0.02, 0.01, 0.04), Color(0.03, 0.01, 0.05))
	# Red glowing dungeon eye / skull carving above arch
	_draw_iso_box(img, -10, -34, 93, 20, 4, 14, Color(1, 0.3, 0.3), Color(0.8, 0.15, 0.15), Color(0.9, 0.2, 0.2))
	# Torches on columns
	_draw_iso_box(img, -36, -32, 45, 6, 4, 10, Color(1, 0.6, 0.2), Color(0.85, 0.4, 0.1), Color(0.95, 0.5, 0.15))
	_draw_iso_box(img, 28, -32, 45, 6, 4, 10, Color(1, 0.6, 0.2), Color(0.85, 0.4, 0.1), Color(0.95, 0.5, 0.15))

func _render_ground(img: Image) -> void:
	# Grassland base
	var grass = Color(0.24, 0.38, 0.22)
	img.fill(grass)
	# Add subtle cobblestone paths connecting town nodes
	var path_col = Color(0.42, 0.38, 0.32)
	# Draw pathways connecting locations:
	# Dungeon (640, 110) to Square (640, 380)
	for y in range(80, 420):
		for x in range(615, 665):
			if (x + y * 2) % 11 < 9:
				img.set_pixel(x, y, path_col)
	# Square (640, 380) to Houses (300, 230)
	for t in range(100):
		var px = int(lerpf(640, 300, float(t) / 100.0))
		var py = int(lerpf(380, 230, float(t) / 100.0))
		for dx in range(-15, 16):
			for dy in range(-10, 11):
				_set_p(img, px + dx, py + dy, path_col)
	# Square (640, 380) to Chronicler (950, 210)
	for t in range(100):
		var px = int(lerpf(640, 950, float(t) / 100.0))
		var py = int(lerpf(380, 210, float(t) / 100.0))
		for dx in range(-15, 16):
			for dy in range(-10, 11):
				_set_p(img, px + dx, py + dy, path_col)
	# Square (640, 380) to Marketplace (340, 570)
	for t in range(100):
		var px = int(lerpf(640, 340, float(t) / 100.0))
		var py = int(lerpf(380, 570, float(t) / 100.0))
		for dx in range(-15, 16):
			for dy in range(-10, 11):
				_set_p(img, px + dx, py + dy, path_col)
	# Square (640, 380) to Forge (770, 610)
	for t in range(100):
		var px = int(lerpf(640, 770, float(t) / 100.0))
		var py = int(lerpf(380, 610, float(t) / 100.0))
		for dx in range(-15, 16):
			for dy in range(-10, 11):
				_set_p(img, px + dx, py + dy, path_col)
	# Square (640, 380) to Alchemist (1000, 430)
	for t in range(100):
		var px = int(lerpf(640, 1000, float(t) / 100.0))
		var py = int(lerpf(380, 430, float(t) / 100.0))
		for dx in range(-15, 16):
			for dy in range(-10, 11):
				_set_p(img, px + dx, py + dy, path_col)
