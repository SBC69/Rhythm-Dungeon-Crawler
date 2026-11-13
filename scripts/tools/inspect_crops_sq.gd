extends SceneTree

func _init():
	var sq0 = Image.load_from_file("C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/square_stage_0_1792538296787.jpg")
	var sq1 = Image.load_from_file("C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/square_stage_1_1792538314564.jpg")
	print("sq0 size: ", sq0.get_size(), " sq1 size: ", sq1.get_size())
	
	# Crop the right gothic stone library from sq0 (around x: 450-980, y: 60-700 on 1024x1024)
	var lib = Image.create(530, 640, false, Image.FORMAT_RGBA8)
	sq0.convert(Image.FORMAT_RGBA8)
	lib.blit_rect(sq0, Rect2i(450, 60, 530, 640), Vector2i.ZERO)
	lib.save_png("C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/crop_sq0_library.png")
	
	# Crop the market stall from sq1 (around x: 600-980, y: 300-780 on 1024x1024)
	var mkt = Image.create(380, 480, false, Image.FORMAT_RGBA8)
	sq1.convert(Image.FORMAT_RGBA8)
	mkt.blit_rect(sq1, Rect2i(600, 300, 380, 480), Vector2i.ZERO)
	mkt.save_png("C:/Users/sapav/.gemini/antigravity/brain/db5b623a-845d-4f8f-8c50-e28a7412a872/crop_sq1_market.png")
	
	print("Saved crops for inspection")
	quit()
