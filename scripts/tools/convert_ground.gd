extends SceneTree

func _init():
	var src = "C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/village_ground_terrain_1792538364076.jpg"
	var dest = "res://assets/sprites/village/village_ground.png"
	var img = Image.load_from_file(src)
	if img == null:
		print("Failed to load ground")
		quit(1)
	img.convert(Image.FORMAT_RGBA8)
	img.resize(1280, 800, Image.INTERPOLATE_LANCZOS)
	img.save_png(dest)
	print("Saved village_ground.png: ", img.get_size())
	quit(0)
