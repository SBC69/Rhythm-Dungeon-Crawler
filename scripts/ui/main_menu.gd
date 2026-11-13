extends Control

signal continue_requested
signal new_game_requested
signal village_requested
signal quit_requested

var continue_button: Button
var new_game_button: Button
var village_button: Button
var quit_button: Button
var settings_button: Button
var settings_panel: Control
var controls_hint: Label
var status: Label
var wallet: Label
var content: HBoxContainer

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var backdrop := TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.texture = load("res://assets/sprites/dungeon/corridor.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.035, 0.02, 0.06, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	content = HBoxContainer.new()
	content.add_theme_constant_override("separation", 72)
	center.add_child(content)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 400
	column.add_theme_constant_override("separation", 12)
	content.add_child(column)
	var title := TextureRect.new()
	title.name = "GameLogo"
	title.texture = preload("res://assets/branding/rdc-logo.png")
	title.custom_minimum_size = Vector2(400, 168)
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	title.tooltip_text = "Rhythm Dungeon Crawler"
	column.add_child(title)
	column.add_child(_label("UI_MENU_SUBTITLE", 14, Color("b7a4c9")))
	var separator := HSeparator.new()
	separator.custom_minimum_size.y = 12
	column.add_child(separator)
	continue_button = _button("UI_MENU_CONTINUE", continue_requested)
	new_game_button = _button("UI_MENU_NEW_GAME", new_game_requested)
	village_button = _button("UI_MENU_VILLAGE", village_requested)
	settings_button = Button.new()
	settings_button.text = "UI_SETTINGS"
	settings_button.custom_minimum_size.y = 46
	settings_button.add_theme_font_size_override("font_size", 16)
	settings_button.pressed.connect(func(): settings_panel.open())
	quit_button = _button("UI_MENU_QUIT", quit_requested)
	for button in [continue_button, new_game_button, village_button, settings_button, quit_button]:
		column.add_child(button)
	status = _label("", 12, Color("b7a4c9"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 36
	column.add_child(status)
	wallet = _label("", 13, Color("edc77a"))
	column.add_child(wallet)
	controls_hint = _label("", 11, Color("8f819f"))
	controls_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(controls_hint)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(340, 460)
	art.texture = load("res://assets/sprites/monsters/crypt_knight-pixel.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(art)
	settings_panel = preload("res://scripts/ui/settings_panel.gd").new()
	add_child(settings_panel)
	settings_panel.closed.connect(func(): settings_button.grab_focus())
	UserSettings.changed.connect(_refresh_controls_hint)
	_refresh_controls_hint()

func _refresh_controls_hint() -> void:
	controls_hint.text = tr("UI_MENU_BINDINGS") % [UserSettings.binding_text("ui_focus_next"), UserSettings.binding_text("ui_accept").split(" / ")[0], UserSettings.binding_text("ui_cancel")]
	if continue_button.visible:
		status.text = tr("UI_MENU_RUN_SUMMARY") % [GameManager.current_floor, GameManager.current_room]
	else:
		status.text = "UI_MENU_WELCOME"
	wallet.text = tr("UI_MENU_WALLET") % int(GameManager.player_profile.get("wallet_gold", 0))
	status.tooltip_text = "UI_MENU_ACTIVE_RUN" if continue_button.visible else ""
	new_game_button.tooltip_text = status.tooltip_text
	village_button.tooltip_text = status.tooltip_text

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	if font_size >= 18:
		label.theme_type_variation = &"DungeonHeading"
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(key: String, action: Signal) -> Button:
	var button := Button.new()
	button.text = key
	button.custom_minimum_size.y = 46
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(func(): action.emit())
	return button

func setup(gold: int, can_continue: bool, blocked: bool, summary: String = "") -> void:
	settings_panel.visible = false
	continue_button.visible = can_continue
	continue_button.disabled = blocked
	new_game_button.disabled = can_continue or blocked
	village_button.disabled = can_continue or blocked
	status.text = summary if can_continue else tr("UI_MENU_WELCOME")
	status.tooltip_text = tr("UI_MENU_ACTIVE_RUN") if can_continue else ""
	new_game_button.tooltip_text = tr("UI_MENU_ACTIVE_RUN") if can_continue else ""
	village_button.tooltip_text = new_game_button.tooltip_text
	wallet.text = tr("UI_MENU_WALLET") % gold
	_focus_primary.call_deferred()

func _focus_primary() -> void:
	if not is_visible_in_tree():
		return
	for button in [continue_button, new_game_button, village_button, settings_button, quit_button]:
		if button.visible and not button.disabled:
			button.grab_focus()
			break
