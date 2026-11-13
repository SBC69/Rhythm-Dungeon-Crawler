extends SceneTree
func _init():
	var img = Image.load_from_file("C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/dungeon_entrance_1792537949816.jpg")
	if img != null:
		print("Loaded image: ", img.get_size(), " format: ", img.get_format())
	else:
		print("Failed to load image")
	quit()
