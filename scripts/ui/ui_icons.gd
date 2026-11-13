class_name UiIcons
extends RefCounted

# UI pictograms are project-owned textures, independent of Unicode/emoji fonts.
const ROOT := "res://assets/ui/icons/"
const ICON_KEY := &"_ui_icon_id"
const SIZE_KEY := &"_ui_icon_size"
const ONLY_KEY := &"_ui_icon_only"
static var _textures: Dictionary = {}

static func plain_text(value: String) -> String:
	# Older saved encounters may still contain decorative Unicode pictograms.
	var result := ""
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if (code >= 0x1F000 and code <= 0x1FAFF) or (code >= 0x2300 and code <= 0x23FF) or (code >= 0x2600 and code <= 0x27BF) or code in [0xFE0E, 0xFE0F, 0x200D, 0x20E3]:
			continue
		result += value.substr(index, 1)
	return result.strip_edges()

static func texture(id: String) -> Texture2D:
	if id.is_empty():
		return null
	if not _textures.has(id):
		_textures[id] = load(ROOT + id + ".svg") as Texture2D
	return _textures[id]

static func button(target: Button, id: String, icon_size: int = 16) -> void:
	if target == null:
		return
	target.icon = texture(id)
	target.expand_icon = true
	target.add_theme_constant_override("icon_max_width", icon_size)
	target.add_theme_constant_override("h_separation", 6)
	target.set_meta(ICON_KEY, id)

static func label(target: Label, id: String, icon_size: int = 16) -> void:
	if target == null:
		return
	target.set_meta(ICON_KEY, id)
	target.set_meta(SIZE_KEY, icon_size)
	target.set_meta(ONLY_KEY, false)
	if not target.has_meta(&"_ui_icon_original_style"):
		target.set_meta(&"_ui_icon_original_style", target.get_theme_stylebox("normal").duplicate())
		target.set_meta(&"_ui_icon_had_override", target.has_theme_stylebox_override("normal"))
	if id.is_empty():
		if target.get_meta(&"_ui_icon_had_override", false):
			target.add_theme_stylebox_override("normal", target.get_meta(&"_ui_icon_original_style"))
		else:
			target.remove_theme_stylebox_override("normal")
	else:
		var spacing: StyleBox = target.get_meta(&"_ui_icon_original_style").duplicate()
		spacing.content_margin_left = spacing.get_content_margin(SIDE_LEFT) + icon_size + 4
		target.add_theme_stylebox_override("normal", spacing)
	_connect_draw(target)
	target.queue_redraw()

static func icon_only(target: Label, id: String, icon_size: int = 28) -> void:
	if target == null:
		return
	target.text = ""
	target.set_meta(ICON_KEY, id)
	target.set_meta(SIZE_KEY, icon_size)
	target.set_meta(ONLY_KEY, true)
	target.custom_minimum_size = Vector2(maxf(target.custom_minimum_size.x, icon_size), maxf(target.custom_minimum_size.y, icon_size))
	_connect_draw(target)
	target.queue_redraw()

static func _connect_draw(target: Label) -> void:
	var callback := _draw_label.bind(target)
	if not target.draw.is_connected(callback):
		target.draw.connect(callback)

static func _draw_label(target: Label) -> void:
	var id: String = target.get_meta(ICON_KEY, "")
	var only: bool = target.get_meta(ONLY_KEY, false)
	if id.is_empty() or (target.text.is_empty() and not only):
		return
	var art := texture(id)
	if art == null:
		return
	var icon_size: int = target.get_meta(SIZE_KEY, 16)
	var at: Vector2
	if only:
		at = (target.size - Vector2.ONE * icon_size) * 0.5
	else:
		var bounds := target.get_character_bounds(0)
		at = Vector2(bounds.position.x - icon_size - 4, bounds.position.y + (bounds.size.y - icon_size) * 0.5)
		at.x = maxf(0.0, at.x)
		at.y = maxf(0.0, at.y)
	target.draw_texture_rect(art, Rect2(at.floor(), Vector2.ONE * icon_size), false)

