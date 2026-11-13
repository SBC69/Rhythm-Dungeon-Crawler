extends ColorRect

signal closed

var panel: PanelContainer
var pages: Dictionary = {}
var tabs: Dictionary = {}
var binding_buttons: Dictionary = {}
var volume_sliders: Dictionary = {}
var volume_labels: Dictionary = {}
var resolution_select: OptionButton
var language_select: OptionButton
var resolution_sizes: Array[Vector2i] = []
var apply_resolution_button: Button
var mute_button: CheckButton
var close_button: Button
var reset_button: Button
var status: Label
var scroll: ScrollContainer
var capture_action := ""
var _modifier: InputEventKey
var _release_code := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.025, 0.018, 0.04, 0.96)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 610)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	column.add_child(_label("UI_SETTINGS", 24))
	var language_row := HBoxContainer.new()
	column.add_child(language_row)
	var language_label := _label("UI_SETTINGS_LANGUAGE")
	language_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_row.add_child(language_label)
	language_select = OptionButton.new()
	language_select.custom_minimum_size = Vector2(240, 40)
	language_select.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for locale in UserSettings.LANGUAGES:
		language_select.add_item(UserSettings.LANGUAGES[locale])
		language_select.set_item_metadata(language_select.item_count - 1, locale)
	language_select.item_selected.connect(_language_selected)
	language_row.add_child(language_select)
	var tab_row := HBoxContainer.new()
	column.add_child(tab_row)
	for id in ["controls", "display", "audio"]:
		var button := _button("UI_SETTINGS_" + id.to_upper())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(show_page.bind(id))
		tab_row.add_child(button)
		tabs[id] = button
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	for id in tabs:
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 10)
		scroll.add_child(page)
		pages[id] = page
	_build_controls()
	_build_display()
	_build_audio()
	status = _label("", 12)
	status.custom_minimum_size = Vector2(640, 32)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	close_button = _button("UI_CLOSE")
	close_button.pressed.connect(close)
	column.add_child(close_button)
	UserSettings.changed.connect(_refresh)
	_refresh()
	show_page("controls")
	visible = false

func _label(text: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.add_theme_font_size_override("font_size", 13)
	return button

func _description(page: Control, key: String) -> void:
	var label := _label(key, 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(label)

func _build_controls() -> void:
	var page: VBoxContainer = pages.controls
	_description(page, "UI_SETTINGS_BIND_HELP")
	for action in UserSettings.ACTIONS:
		var row := HBoxContainer.new()
		page.add_child(row)
		var label := _label(UserSettings.ACTIONS[action])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := _button("")
		button.custom_minimum_size.x = 240
		button.pressed.connect(_start_capture.bind(action))
		row.add_child(button)
		binding_buttons[action] = button
	reset_button = _button("UI_SETTINGS_RESET_KEYS")
	reset_button.pressed.connect(func(): _report(UserSettings.reset_bindings()))
	page.add_child(reset_button)

func _build_display() -> void:
	var page: VBoxContainer = pages.display
	_description(page, "UI_SETTINGS_RESOLUTION_HELP")
	page.add_child(_label("UI_SETTINGS_RESOLUTION"))
	resolution_select = OptionButton.new()
	resolution_select.custom_minimum_size.y = 40
	page.add_child(resolution_select)
	apply_resolution_button = _button("UI_SETTINGS_APPLY_RESOLUTION")
	apply_resolution_button.pressed.connect(_apply_resolution)
	page.add_child(apply_resolution_button)

func _build_audio() -> void:
	var page: VBoxContainer = pages.audio
	for channel in UserSettings.BUSES:
		var row := HBoxContainer.new()
		page.add_child(row)
		var label := _label("UI_VOLUME_" + channel.to_upper())
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var amount := _label("")
		row.add_child(amount)
		volume_labels[channel] = amount
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size = Vector2(0, 28)
		slider.focus_mode = Control.FOCUS_ALL
		slider.value_changed.connect(_volume_changed.bind(channel))
		page.add_child(slider)
		volume_sliders[channel] = slider
	mute_button = CheckButton.new()
	mute_button.text = "UI_SETTINGS_MUTE"
	mute_button.toggled.connect(func(value: bool): _report(UserSettings.set_muted(value)))
	page.add_child(mute_button)
	_description(page, "UI_SETTINGS_AUDIO_HELP")

func open() -> void:
	_refresh()
	status.text = tr("UI_SETTINGS_AUTO_SAVE")
	visible = true
	show_page("controls")
	tabs.controls.grab_focus()

func close() -> void:
	_cancel_capture()
	visible = false
	closed.emit()

func show_page(id: String) -> void:
	_cancel_capture()
	for page_id in pages:
		pages[page_id].visible = page_id == id
		tabs[page_id].modulate = Color("edc77a") if page_id == id else Color.WHITE
	scroll.scroll_vertical = 0
	if status != null:
		status.text = tr("UI_SETTINGS_AUTO_SAVE")

func _refresh() -> void:
	for index in range(language_select.item_count):
		if language_select.get_item_metadata(index) == UserSettings.language:
			language_select.select(index)
	for action in binding_buttons:
		binding_buttons[action].text = tr("UI_SETTINGS_PRESS_KEY") if capture_action == action else UserSettings.binding_text(action)
	resolution_sizes = UserSettings.available_resolutions()
	resolution_select.clear()
	for size in resolution_sizes:
		resolution_select.add_item("%d × %d" % [size.x, size.y])
	var selected := resolution_sizes.find(UserSettings.resolution)
	resolution_select.select(maxi(0, selected))
	for channel in volume_sliders:
		var value := roundi(float(UserSettings.volumes[channel]) * 100.0)
		volume_sliders[channel].set_value_no_signal(value)
		volume_labels[channel].text = "%d%%" % value
	mute_button.set_pressed_no_signal(UserSettings.muted)

func _language_selected(index: int) -> void:
	_cancel_capture()
	_report(UserSettings.set_language(str(language_select.get_item_metadata(index))))

func _apply_resolution() -> void:
	if resolution_select.selected >= 0:
		_report(UserSettings.set_resolution(resolution_sizes[resolution_select.selected]))

func _volume_changed(value: float, channel: String) -> void:
	_report(UserSettings.set_volume(channel, value / 100.0))

func _report(error: Error) -> void:
	status.text = tr("UI_SETTINGS_SAVED") if error == OK else tr("UI_SETTINGS_SAVE_FAILED")
	status.modulate = Color("81eed0") if error == OK else Color("f18e77")

func _start_capture(action: String) -> void:
	capture_action = action
	_modifier = null
	_refresh()
	status.text = tr("UI_SETTINGS_CAPTURE_HELP")
	status.modulate = Color("edc77a")

func _cancel_capture() -> void:
	if capture_action.is_empty():
		return
	var action := capture_action
	capture_action = ""
	_modifier = null
	binding_buttons[action].text = UserSettings.binding_text(action)

func _capture(source: InputEventKey) -> void:
	var conflict := UserSettings.binding_conflict(capture_action, source)
	if not conflict.is_empty():
		status.text = tr("UI_SETTINGS_KEY_CONFLICT") % tr(UserSettings.ACTIONS[conflict])
		status.modulate = Color("f18e77")
		return
	var action := capture_action
	capture_action = ""
	_modifier = null
	_release_code = int(source.keycode)
	_report(UserSettings.rebind(action, source))
	binding_buttons[action].grab_focus()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and _release_code != 0 and not event.pressed and int(event.keycode) == _release_code:
		_release_code = 0
		get_viewport().set_input_as_handled()
		return
	if not capture_action.is_empty():
		# Do not let the key being assigned activate buttons or navigate the menu.
		get_viewport().set_input_as_handled()
		if not event is InputEventKey or event.echo:
			return
		if event.pressed and event.keycode == KEY_ESCAPE:
			_cancel_capture()
			status.text = tr("UI_SETTINGS_AUTO_SAVE")
		elif event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			if event.pressed:
				_modifier = event.duplicate()
			elif _modifier != null and _modifier.keycode == event.keycode:
				_capture(_modifier)
		elif event.pressed:
			_capture(event)
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close()
