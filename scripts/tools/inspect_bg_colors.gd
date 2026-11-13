extends SceneTree

func _init():
	var img = Image.load_from_file("C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/houses_stage_1_1792538627543.jpg")
	var corners = [Vector2i(0,0), Vector2i(10,10), Vector2i(50,50), Vector2i(100,100)]
	for c in corners:
		print("Pixel at ", c, ": ", img.get_pixel(c.x, c.y))
	quit()
