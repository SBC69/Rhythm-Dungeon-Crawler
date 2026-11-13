# scripts/village/village_building_node.gd
class_name VillageBuildingNode
extends Button

signal building_clicked(object_id: String)

var object_id: String = ""
var is_building: bool = true
var base_anchor: Vector2 = Vector2.ZERO
var sprite_pattern: String = ""
var fixed_sprite_path: String = ""
var display_name: String = ""
var current_stage: int = 0

var sprite_rect: TextureRect
var tag_container: PanelContainer
var tag_label: Label
var focus_frame: Panel

func setup_node(id: String, cfg: Dictionary, anchor_offset: Vector2) -> void:
	object_id = id
	is_building = cfg.get("is_building", true)
	var ax = float(cfg.get("x", 0))
	var ay = float(cfg.get("y", 0))
	base_anchor = Vector2(ax, ay)
	display_name = tr("UI_DUNGEON_ENTRANCE" if id == "dungeon_entrance" else "VILLAGE_" + id.to_upper())
	sprite_pattern = cfg.get("sprite_pattern", "")
	fixed_sprite_path = cfg.get("sprite", "")

	# Position top-left so that base_anchor aligns with anchor_offset (128, 224)
	position = base_anchor - anchor_offset
	size = Vector2(256, 256)
	custom_minimum_size = Vector2(256, 256)
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Style overrides to make button transparent except on focus
	var empty_style = StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty_style)
	add_theme_stylebox_override("hover", empty_style)
	add_theme_stylebox_override("pressed", empty_style)
	add_theme_stylebox_override("disabled", empty_style)

	var focus_style = StyleBoxFlat.new()
	focus_style.draw_center = false
	focus_style.border_width_left = 2
	focus_style.border_width_top = 2
	focus_style.border_width_right = 2
	focus_style.border_width_bottom = 2
	focus_style.border_color = Color(1.0, 0.85, 0.3, 0.95)
	focus_style.corner_radius_top_left = 12
	focus_style.corner_radius_top_right = 12
	focus_style.corner_radius_bottom_right = 12
	focus_style.corner_radius_bottom_left = 12
	add_theme_stylebox_override("focus", focus_style)

	_create_visuals()
	pressed.connect(_on_pressed)

func _create_visuals() -> void:
	sprite_rect = TextureRect.new()
	sprite_rect.name = "SpriteRect"
	sprite_rect.size = Vector2(256, 256)
	sprite_rect.custom_minimum_size = Vector2(256, 256)
	sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(sprite_rect)

	# Hover / focus frame glow
	focus_frame = Panel.new()
	focus_frame.name = "FocusFrame"
	focus_frame.size = Vector2(256, 256)
	focus_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ff_style = StyleBoxFlat.new()
	ff_style.draw_center = true
	ff_style.bg_color = Color(1.0, 0.85, 0.3, 0.08)
	ff_style.border_width_left = 2
	ff_style.border_width_top = 2
	ff_style.border_width_right = 2
	ff_style.border_width_bottom = 2
	ff_style.border_color = Color(1.0, 0.85, 0.3, 0.8)
	ff_style.corner_radius_top_left = 12
	ff_style.corner_radius_top_right = 12
	ff_style.corner_radius_bottom_right = 12
	ff_style.corner_radius_bottom_left = 12
	focus_frame.add_theme_stylebox_override("panel", ff_style)
	focus_frame.visible = false
	add_child(focus_frame)

	# Name tag badge at bottom
	tag_container = PanelContainer.new()
	tag_container.name = "TagContainer"
	tag_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag_style = StyleBoxFlat.new()
	tag_style.bg_color = Color(0.08, 0.06, 0.12, 0.88)
	tag_style.border_width_left = 1
	tag_style.border_width_top = 1
	tag_style.border_width_right = 1
	tag_style.border_width_bottom = 1
	tag_style.border_color = Color(0.7, 0.6, 0.3, 0.8)
	tag_style.corner_radius_top_left = 6
	tag_style.corner_radius_top_right = 6
	tag_style.corner_radius_bottom_right = 6
	tag_style.corner_radius_bottom_left = 6
	tag_style.content_margin_left = 8
	tag_style.content_margin_right = 8
	tag_style.content_margin_top = 2
	tag_style.content_margin_bottom = 2
	tag_container.add_theme_stylebox_override("panel", tag_style)

	tag_label = Label.new()
	tag_label.name = "TagLabel"
	tag_label.clip_text = true
	tag_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.add_theme_font_size_override("font_size", 11)
	tag_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	tag_container.add_child(tag_label)

	tag_container.position = Vector2(16, 226)
	tag_container.custom_minimum_size = Vector2(224, 24)
	tag_container.size = Vector2(224, 24)
	add_child(tag_container)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

static func load_texture_safe(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			return ImageTexture.create_from_image(img)
	return null

func update_stage(stage: int) -> void:
	display_name = tr("UI_DUNGEON_ENTRANCE" if object_id == "dungeon_entrance" else "VILLAGE_" + object_id.to_upper())
	tooltip_text = display_name
	current_stage = stage
	var sprite_path = ""
	if is_building:
		sprite_path = sprite_pattern % stage
		tag_label.text = "%s [%d/3]" % [display_name, stage]
	else:
		sprite_path = fixed_sprite_path
		tag_label.text = display_name

	var tex = load_texture_safe(sprite_path)
	if tex != null:
		sprite_rect.texture = tex

func _on_pressed() -> void:
	building_clicked.emit(object_id)

func _on_mouse_entered() -> void:
	focus_frame.visible = true
	sprite_rect.modulate = Color(1.15, 1.15, 1.15, 1.0)

func _on_mouse_exited() -> void:
	if not has_focus():
		focus_frame.visible = false
		sprite_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_focus_entered() -> void:
	focus_frame.visible = true
	sprite_rect.modulate = Color(1.2, 1.2, 1.1, 1.0)

func _on_focus_exited() -> void:
	focus_frame.visible = false
	sprite_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
