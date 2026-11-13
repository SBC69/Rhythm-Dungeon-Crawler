extends Node

signal changed

const ACTIONS := {
	"ui_up": "UI_CONTROL_UP", "ui_down": "UI_CONTROL_DOWN",
	"ui_left": "UI_CONTROL_LEFT", "ui_right": "UI_CONTROL_RIGHT",
	"ui_accept": "UI_CONTROL_ACCEPT", "ui_cancel": "UI_CONTROL_CANCEL",
	"ui_focus_next": "UI_CONTROL_NEXT", "ui_focus_prev": "UI_CONTROL_PREVIOUS",
	"ui_page_up": "UI_CONTROL_PAGE_UP", "ui_page_down": "UI_CONTROL_PAGE_DOWN",
	"rhythm_attack": "UI_CONTROL_ATTACK", "rhythm_guard": "UI_CONTROL_GUARD",
	"inventory": "UI_CONTROL_INVENTORY"
}
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const BUSES := {"master": "Master", "effects": "Effects", "rhythm": "Rhythm"}
const LANGUAGES := {"en": "English", "ru": "Русский", "es": "Español", "zh_CN": "简体中文"}
const DEFAULT_LANGUAGE := "en"

var config_path := "user://settings.cfg"
var resolution := Vector2i(1280, 720)
var volumes := {"master": 1.0, "effects": 1.0, "rhythm": 1.0}
var muted := false
var language := DEFAULT_LANGUAGE
var defaults: Dictionary = {}

func _ready() -> void:
	# Keep the existing UI font and bundle CJK coverage for exported games.
	var font := ThemeDB.fallback_font.duplicate() as Font
	font.fallbacks = [load("res://assets/fonts/NotoSansSC.ttf") as Font]
	var theme := load("res://assets/ui/dungeon_theme.tres") as Theme
	theme.default_font = font
	for action in ["rhythm_attack", "rhythm_guard", "inventory"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	for key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		InputMap.action_add_event("rhythm_attack", key_event(key))
	InputMap.action_add_event("rhythm_guard", key_event(KEY_SHIFT))
	InputMap.action_add_event("inventory", key_event(KEY_I))
	for action in ACTIONS:
		defaults[action] = keyboard_events(action)
	for channel in ["effects", "rhythm"]:
		if AudioServer.get_bus_index(BUSES[channel]) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, BUSES[channel])
			AudioServer.set_bus_send(index, "Master")
	load_settings()

func key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	return event

func keyboard_events(action: String) -> Array[InputEventKey]:
	var result: Array[InputEventKey] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			result.append(event.duplicate())
	return result

func _replace_keys(action: String, keys: Array) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	for event in keys:
		InputMap.action_add_event(action, event)

func normalized_key(source: InputEventKey) -> InputEventKey:
	var event := key_event(source.keycode if source.keycode != 0 else source.physical_keycode)
	event.ctrl_pressed = source.ctrl_pressed and event.keycode != KEY_CTRL
	event.alt_pressed = source.alt_pressed and event.keycode != KEY_ALT
	event.shift_pressed = source.shift_pressed and event.keycode != KEY_SHIFT
	event.meta_pressed = source.meta_pressed and event.keycode != KEY_META
	return event

func binding_conflict(action: String, source: InputEventKey) -> String:
	var key := normalized_key(source)
	for other in ACTIONS:
		# Rhythm actions may share keys with menu actions, as in the defaults.
		if other == action or other.begins_with("rhythm_") != action.begins_with("rhythm_"):
			continue
		for existing in keyboard_events(other):
			if normalized_key(existing).get_keycode_with_modifiers() == key.get_keycode_with_modifiers():
				return other
	return ""

func rebind(action: String, source: InputEventKey) -> Error:
	if not ACTIONS.has(action) or normalized_key(source).keycode == 0 or not binding_conflict(action, source).is_empty():
		return ERR_INVALID_PARAMETER
	_replace_keys(action, [normalized_key(source)])
	changed.emit()
	return save_settings()

func reset_bindings() -> Error:
	for action in defaults:
		_replace_keys(action, defaults[action])
	changed.emit()
	return save_settings()

func binding_text(action: String) -> String:
	var names: PackedStringArray = []
	for event in keyboard_events(action):
		var key := normalized_key(event)
		var text := OS.get_keycode_string(key.get_keycode_with_modifiers())
		if key.get_keycode_with_modifiers() == KEY_SPACE:
			text = tr("UI_KEY_SPACE")
		elif key.get_keycode_with_modifiers() == KEY_ENTER:
			text = "Enter"
		if not text in names:
			names.append(text)
	return " / ".join(names)

func rhythm_key_pressed(event: InputEvent, action: String) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	var key := normalized_key(event)
	for binding in keyboard_events(action):
		if normalized_key(binding).get_keycode_with_modifiers() == key.get_keycode_with_modifiers():
			return true
	return false

func available_resolutions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var limit := Vector2i(10000, 10000)
	if DisplayServer.get_name() != "headless":
		limit = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	for size in RESOLUTIONS:
		if size.x <= limit.x and size.y <= limit.y:
			result.append(size)
	if result.is_empty():
		result.append(resolution)
	return result

func set_resolution(size: Vector2i) -> Error:
	if not size in available_resolutions():
		return ERR_INVALID_PARAMETER
	resolution = size
	_apply_resolution()
	changed.emit()
	return save_settings()

func _apply_resolution() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var rect := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var size := Vector2i(mini(resolution.x, rect.size.x), mini(resolution.y, rect.size.y))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(rect.position + (rect.size - size) / 2)

func set_volume(channel: String, value: float) -> Error:
	if not volumes.has(channel) or not is_finite(value):
		return ERR_INVALID_PARAMETER
	volumes[channel] = clampf(value, 0.0, 1.0)
	_apply_audio()
	changed.emit()
	return save_settings()

func set_muted(value: bool) -> Error:
	muted = value
	_apply_audio()
	changed.emit()
	return save_settings()

func set_language(locale: String) -> Error:
	if not LANGUAGES.has(locale):
		return ERR_INVALID_PARAMETER
	language = locale
	TranslationServer.set_locale(language)
	changed.emit()
	return save_settings()

func _apply_audio() -> void:
	for channel in BUSES:
		var index := AudioServer.get_bus_index(BUSES[channel])
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, float(volumes[channel]))))
		AudioServer.set_bus_mute(index, float(volumes[channel]) <= 0.0 or (channel == "master" and muted))

func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("display", "resolution", resolution)
	config.set_value("general", "language", language)
	config.set_value("audio", "muted", muted)
	for channel in volumes:
		config.set_value("audio", channel, volumes[channel])
	for action in ACTIONS:
		var keys: Array = []
		for event in keyboard_events(action):
			keys.append({"code": int(event.keycode), "ctrl": event.ctrl_pressed, "alt": event.alt_pressed, "shift": event.shift_pressed, "meta": event.meta_pressed})
		config.set_value("controls", action, keys)
	return config.save(config_path)

func load_settings() -> void:
	var config := ConfigFile.new()
	language = DEFAULT_LANGUAGE
	if config.load(config_path) == OK:
		var saved_language = config.get_value("general", "language", DEFAULT_LANGUAGE)
		if saved_language is String and LANGUAGES.has(saved_language):
			language = saved_language
		var saved_size = config.get_value("display", "resolution", resolution)
		if saved_size is Vector2i and saved_size in RESOLUTIONS:
			resolution = saved_size
		muted = config.get_value("audio", "muted", false) == true
		for channel in volumes:
			var value = config.get_value("audio", channel, 1.0)
			if (value is float or value is int) and is_finite(float(value)):
				volumes[channel] = clampf(float(value), 0.0, 1.0)
		# Restore the complete map before loading; checks below reject conflicts.
		for action in defaults:
			_replace_keys(action, defaults[action])
		var saved_bindings: Dictionary = {}
		for action in ACTIONS:
			var raw_keys = config.get_value("controls", action, [])
			if not raw_keys is Array:
				continue
			var keys: Array[InputEventKey] = []
			for data in raw_keys:
				if not data is Dictionary or not data.get("code", 0) is int or int(data.get("code", 0)) <= 0:
					continue
				var key := key_event(int(data.code))
				key.ctrl_pressed = data.get("ctrl", false) == true
				key.alt_pressed = data.get("alt", false) == true
				key.shift_pressed = data.get("shift", false) == true
				key.meta_pressed = data.get("meta", false) == true
				keys.append(key)
			if not keys.is_empty():
				saved_bindings[action] = keys
		for action in saved_bindings:
			_replace_keys(action, saved_bindings[action])
		# Older settings have no inventory binding. Keep their existing custom keys.
		if not saved_bindings.has("inventory"):
			for code in [KEY_I, KEY_B, KEY_F10, KEY_F11, KEY_F12]:
				var candidate := key_event(code)
				if binding_conflict("inventory", candidate).is_empty():
					_replace_keys("inventory", [candidate])
					break
		var conflicts := false
		for action in ACTIONS:
			for key in keyboard_events(action):
				if not binding_conflict(action, key).is_empty():
					conflicts = true
		if conflicts:
			for action in defaults:
				_replace_keys(action, defaults[action])
	TranslationServer.set_locale(language)
	_apply_audio()
	_apply_resolution()
	changed.emit()
