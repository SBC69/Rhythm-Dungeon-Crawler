extends Control

signal door_opened(door_index: int)
signal door_requested(door_index: int)

@export var door_index: int = 1
@export var door_title: String = "Door":
	set(value):
		door_title = value
		if is_inside_tree() and label != null:
			label.text = value
			_update_title_icon()

@onready var texture_rect: TextureRect = $VBoxContainer/DoorFrame/TextureRect
@onready var interior_light: Panel = $VBoxContainer/DoorFrame/InteriorLight
@onready var label: Label = $VBoxContainer/Label

var is_hovered: bool = false
var is_active: bool = true
var is_opened: bool = false
var door_token: int = 0
var opening_tween: Tween = null
static var fitted_art_cache: Dictionary = {}

func _ready() -> void:
	set_door_art(texture_rect.texture)
	focus_mode = Control.FOCUS_ALL
	if label != null:
		label.text = door_title
		_update_title_icon()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	gui_input.connect(_on_gui_input)

func set_door_art(source: Texture2D) -> void:
	if source == null:
		return
	if source is AtlasTexture:
		source = source.atlas
	# Fit the visible arch to the opening, excluding the PNG's transparent padding.
	if fitted_art_cache.has(source):
		texture_rect.texture = fitted_art_cache[source]
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		return
	var fitted := AtlasTexture.new()
	fitted.atlas = source
	fitted.region = _visible_art_bounds(source)
	fitted_art_cache[source] = fitted
	texture_rect.texture = fitted
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE

static func _visible_art_bounds(source: Texture2D) -> Rect2i:
	var image := source.get_image()
	image.convert(Image.FORMAT_RGBA8)
	var pixels := image.get_data()
	var width := image.get_width()
	var height := image.get_height()
	var left := width
	var top := height
	var right := -1
	var bottom := -1
	# Almost transparent export noise must not make the whole PNG count as visible.
	for y in range(height):
		var row := y * width * 4
		for x in range(width):
			if pixels[row + x * 4 + 3] < 16:
				continue
			left = mini(left, x)
			top = mini(top, y)
			right = maxi(right, x)
			bottom = maxi(bottom, y)
	return Rect2i(left, top, right - left + 1, bottom - top + 1) if right >= left else Rect2i(Vector2i.ZERO, image.get_size())

func _on_focus_entered() -> void:
	_on_mouse_entered()

func _on_focus_exited() -> void:
	_on_mouse_exited()

func set_door_title(new_title: String) -> void:
	door_title = new_title
	if label != null:
		label.text = new_title
		_update_title_icon()

func _update_title_icon() -> void:
	UiIcons.label(label, "crown" if door_title == tr("DOOR_BOSS") else "", 14)

func reset_door() -> void:
	if opening_tween != null and opening_tween.is_valid():
		opening_tween.kill()
	door_token += 1
	is_opened = false
	texture_rect.scale = Vector2.ONE
	texture_rect.modulate = Color.WHITE
	interior_light.modulate.a = 0.0
	label.modulate.a = 1.0
	if label != null:
		label.text = door_title

func set_active(active: bool) -> void:
	is_active = active
	focus_mode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
	modulate = Color(1, 1, 1, 1) if active else Color(0.5, 0.5, 0.5, 0.6)

func _on_mouse_entered() -> void:
	if not is_active or is_opened:
		return
	is_hovered = true
	SoundManager.play_click()
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(texture_rect, "scale", Vector2(1.05, 1.05), 0.15)
	tween.parallel().tween_property(texture_rect, "modulate", Color(1.25, 1.15, 1.35), 0.15)

func _on_mouse_exited() -> void:
	if not is_active or is_opened:
		return
	is_hovered = false
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(texture_rect, "scale", Vector2(1.0, 1.0), 0.15)
	tween.parallel().tween_property(texture_rect, "modulate", Color(1.0, 1.0, 1.0), 0.15)

func open_door() -> void:
	if is_opened or not is_active:
		return
	door_requested.emit(door_index)

func animate_accepted_open() -> void:
	is_opened = true
	is_active = false
	door_token += 1
	var captured_token = door_token

	# Play wooden creak sound
	SoundManager.play_door_creak()

	# Swing open animation: perspective foreshortening on left hinge
	texture_rect.pivot_offset = Vector2(14, texture_rect.size.y * 0.5)

	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	opening_tween = tween
	# Door swings inward (scale.x shrinks toward hinge)
	tween.tween_property(texture_rect, "scale:x", 0.05, 0.42)
	tween.parallel().tween_property(texture_rect, "scale:y", 0.95, 0.42)
	tween.parallel().tween_property(texture_rect, "modulate", Color(0.35, 0.3, 0.4), 0.42)
	# Interior light flares up as door opens
	tween.parallel().tween_property(interior_light, "modulate:a", 0.85, 0.35)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.2)
	await get_tree().create_timer(0.42).timeout

	if captured_token != door_token:
		return

	emit_signal("door_opened", door_index)

func _on_gui_input(event: InputEvent) -> void:
	if not is_active or is_opened:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		open_door()
	elif event.is_action_pressed("ui_accept"):
		accept_event()
		open_door()
