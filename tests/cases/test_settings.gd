class_name TestSettings
extends RefCounted

static func register_tests(registry: Dictionary) -> void:
	registry["T-SETTINGS"] = {"fn": Callable(TestSettings, "test_settings"), "desc": "Keyboard settings UI, remapping conflicts, persistence, resolution and audio buses"}
	registry["T-RHYTHM-CUSTOM-KEYS"] = {"fn": Callable(TestSettings, "test_rhythm_keys"), "desc": "Visible rhythm instructions and real input follow saved custom attack and guard keys"}
	registry["T-LANGUAGE"] = {"fn": Callable(TestSettings, "test_language"), "desc": "English default, live four-language settings, saved locale, legacy saves and complete font coverage"}

static func _snapshot(settings: Node) -> Dictionary:
	var bindings: Dictionary = {}
	for action in settings.ACTIONS:
		bindings[action] = settings.keyboard_events(action)
	return {"path": settings.config_path, "resolution": settings.resolution, "volumes": settings.volumes.duplicate(), "muted": settings.muted, "bindings": bindings, "language": settings.language}

static func _restore(settings: Node, snapshot: Dictionary) -> void:
	settings.config_path = snapshot.path
	settings.resolution = snapshot.resolution
	settings.volumes = snapshot.volumes
	settings.muted = snapshot.muted
	settings.language = snapshot.language
	TranslationServer.set_locale(snapshot.language)
	for action in snapshot.bindings:
		settings._replace_keys(action, snapshot.bindings[action])
	settings._apply_audio()
	settings._apply_resolution()
	settings.changed.emit()

static func test_language(fix: GameFixture) -> void:
	var settings = fix.root.get_node("UserSettings")
	var snapshot := _snapshot(settings)
	settings.config_path = "user://test-language-%d.cfg" % Time.get_ticks_usec()
	settings.load_settings()
	fix.assert_eq(settings.language, "en", "A fresh install uses English regardless of OS locale")
	fix.assert_eq(TranslationServer.translate("UI_SETTINGS"), "Settings", "English is actually applied")
	var main = await fix.create_main(true)
	var panel = main.main_menu.settings_panel
	panel.open()
	fix.assert_eq(panel.language_select.item_count, 4, "All four languages are available")
	var expected := {"en": "Settings", "ru": "Настройки", "es": "Ajustes", "zh_CN": "设置"}
	var old_card := {"id": "rusty_sword", "name": "Ржавый меч", "type": 0, "power": 2}
	var upgraded_card := old_card.duplicate()
	upgraded_card.upgrade_level = 3
	upgraded_card.name = "Ржавый меч +3"
	var source := FileAccess.open("res://localization/messages.csv", FileAccess.READ)
	var header := source.get_csv_line()
	var messages: Array[PackedStringArray] = []
	while not source.eof_reached():
		var row := source.get_csv_line()
		if row.size() == header.size():
			messages.append(row)
		elif row.size() > 1:
			fix.assert_true(false, "Translation CSV row is malformed")
	fix.assert_true(not messages.is_empty(), "Source translation table has entries")
	for index in range(panel.language_select.item_count):
		var locale: String = panel.language_select.get_item_metadata(index)
		panel.language_select.select(index)
		panel.language_select.item_selected.emit(index)
		await fix.tree.process_frame
		fix.assert_eq(settings.language, locale, "Dropdown applies language")
		fix.assert_eq(TranslationServer.translate("UI_SETTINGS"), expected[locale], "Requested translation is loaded")
		fix.assert_true(panel.visible, "Changing language keeps settings open")
		fix.assert_eq(main.main_menu.wallet.text, TranslationServer.translate("UI_MENU_WALLET") % int(main.get_node("/root/GameManager").player_profile.get("wallet_gold", 0)), "Main menu refreshes its formatted text live")
		fix.assert_eq(CardPresenter.get_display_name(old_card), TranslationServer.translate("CARD_RUSTY_SWORD"), "Old saved items follow the selected language")
		fix.assert_eq(CardPresenter.get_display_name(upgraded_card), TranslationServer.translate("CARD_RUSTY_SWORD") + " +3", "Localized upgraded items retain their upgrade level")
		var enemy := {"id": "skeleton", "name": "Скелет-воин", "title": "Хранитель катакомб", "flavor": "Древние кости сжимают зазубренный меч.", "power": 4}
		main.monster_view.setup_monster(enemy)
		fix.assert_eq(main.monster_view.name_label.text, TranslationServer.translate("Skeleton Warrior"), "Old saved enemies are localized")
		var config := ConfigFile.new()
		fix.assert_eq(config.load(settings.config_path), OK, "Language settings save successfully")
		fix.assert_eq(config.get_value("general", "language"), locale, "Selected language is stored")
		settings.language = "invalid"
		TranslationServer.set_locale("en" if locale != "en" else "ru")
		settings.load_settings()
		fix.assert_eq(settings.language, locale, "Reload restores selected language")
		fix.assert_eq(TranslationServer.translate("UI_SETTINGS"), expected[locale], "Reload applies translation")
		var translation := load("res://localization/messages.%s.translation" % locale) as Translation
		fix.assert_true(translation != null, "Translation resource exists")
		for row in messages:
			var message := row[header.find(locale)]
			fix.assert_eq(TranslationServer.translate(row[0]), message, "Imported translation matches source: " + locale + "/" + row[0])
			for character in message:
				if character.unicode_at(0) >= 0x4e00 and character.unicode_at(0) <= 0x9fff:
					fix.assert_true(panel.get_theme_font("font").has_char(character.unicode_at(0)), "Bundled UI font covers Chinese character " + character)
	fix.assert_eq(settings.set_language("fr"), ERR_INVALID_PARAMETER, "Unsupported language is rejected")
	fix.assert_eq(settings.language, "zh_CN", "Rejected language leaves current language intact")
	var legacy := ConfigFile.new()
	legacy.set_value("audio", "effects", 0.5)
	legacy.save(settings.config_path)
	settings.load_settings()
	fix.assert_eq(settings.language, "en", "Older settings without a language use English")
	fix.assert_eq(settings.volumes.effects, 0.5, "Older audio settings are preserved")
	legacy.set_value("general", "language", "unknown")
	legacy.save(settings.config_path)
	settings.load_settings()
	fix.assert_eq(settings.language, "en", "Invalid saved language falls back to English")
	_restore(settings, snapshot)
	await fix.teardown()

static func test_settings(fix: GameFixture) -> void:
	var settings = fix.root.get_node("UserSettings")
	var snapshot := _snapshot(settings)
	settings.config_path = "user://test-settings.cfg"
	var main = await fix.create_main(true)
	await TestUI._keyboard_focus(fix, main.main_menu.settings_button)
	await fix.simulate_key(KEY_ENTER)
	var panel = main.main_menu.settings_panel
	fix.assert_true(panel.visible, "Main menu opens settings using the keyboard")
	for i in range(22):
		await fix.simulate_key(KEY_TAB)
		fix.assert_true(panel.is_ancestor_of(fix.root.gui_get_focus_owner()), "Tab cannot reach the background menu")
	await TestUI._keyboard_focus(fix, panel.binding_buttons.rhythm_attack)
	await fix.simulate_key(KEY_ENTER)
	fix.assert_eq(panel.capture_action, "rhythm_attack", "Enter starts key capture")
	await fix.simulate_key(KEY_F)
	fix.assert_eq(settings.binding_text("rhythm_attack"), "F", "Captured key is applied")
	fix.assert_true(panel.capture_action.is_empty(), "Key capture ends after a valid key")
	await TestUI._keyboard_focus(fix, panel.binding_buttons.rhythm_guard)
	await fix.simulate_key(KEY_ENTER)
	await fix.simulate_key(KEY_F)
	fix.assert_eq(panel.capture_action, "rhythm_guard", "Conflicting attack/guard key is rejected")
	fix.assert_true(panel.status.text.contains(TranslationServer.translate("UI_CONTROL_ATTACK")), "Conflict names the existing action")
	await fix.simulate_key(KEY_ESCAPE)
	fix.assert_true(panel.visible and panel.capture_action.is_empty(), "Escape cancels capture without closing settings")
	await TestUI._keyboard_focus(fix, panel.tabs.audio)
	await fix.simulate_key(KEY_ENTER)
	panel.volume_sliders.effects.value = 50
	await TestUI._keyboard_focus(fix, panel.volume_sliders.effects)
	await fix.simulate_key(KEY_RIGHT)
	fix.assert_true(float(settings.volumes.effects) > 0.5, "Arrow changes the actual effects volume")
	fix.assert_true(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Effects")), linear_to_db(float(settings.volumes.effects))), "Effects bus applies the slider")
	panel.volume_sliders.rhythm.value = 25
	fix.assert_true(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Rhythm")), linear_to_db(0.25)), "Rhythm volume uses its own bus")
	await TestUI._keyboard_focus(fix, panel.mute_button)
	await fix.simulate_key(KEY_ENTER)
	fix.assert_true(AudioServer.is_bus_mute(0), "Mute disables the master bus")
	await TestUI._keyboard_focus(fix, panel.tabs.display)
	await fix.simulate_key(KEY_ENTER)
	var index: int = panel.resolution_sizes.size() - 1
	panel.resolution_select.select(index)
	var expected_size: Vector2i = panel.resolution_sizes[index]
	await TestUI._keyboard_focus(fix, panel.apply_resolution_button)
	await fix.simulate_key(KEY_ENTER)
	fix.assert_eq(settings.resolution, expected_size, "Apply commits the selected resolution")
	var config := ConfigFile.new()
	fix.assert_eq(config.load(settings.config_path), OK, "Settings are stored on disk")
	fix.assert_eq(config.get_value("display", "resolution"), expected_size, "Resolution is persisted")
	fix.assert_eq(config.get_value("audio", "muted"), true, "Mute is persisted")
	settings._replace_keys("rhythm_attack", [settings.key_event(KEY_SPACE)])
	settings.volumes.rhythm = 1.0
	settings.muted = false
	settings.load_settings()
	fix.assert_eq(settings.binding_text("rhythm_attack"), "F", "Reload restores the remapped key")
	fix.assert_eq(settings.volumes.rhythm, 0.25, "Reload restores rhythm volume")
	fix.assert_true(settings.muted, "Reload restores mute")
	await TestUI._keyboard_focus(fix, panel.tabs.controls)
	await fix.simulate_key(KEY_ENTER)
	await TestUI._keyboard_focus(fix, panel.binding_buttons.rhythm_guard)
	await fix.simulate_key(KEY_ENTER)
	await fix.simulate_key(KEY_G, true)
	fix.assert_true(settings.binding_text("rhythm_guard").contains("Shift") and settings.binding_text("rhythm_guard").contains("G"), "Capture supports modifier combinations")
	await fix.simulate_key(KEY_ENTER)
	await fix.simulate_key(KEY_SHIFT)
	fix.assert_eq(settings.binding_text("rhythm_guard"), "Shift", "A modifier alone is captured on release")
	await TestUI._keyboard_focus(fix, panel.reset_button)
	await fix.simulate_key(KEY_ENTER)
	fix.assert_true(settings.binding_text("rhythm_attack").contains(TranslationServer.translate("UI_KEY_SPACE")), "Reset restores the default keys")
	await TestUI._keyboard_focus(fix, panel.binding_buttons.ui_accept)
	await fix.simulate_key(KEY_ENTER)
	await fix.simulate_key(KEY_E)
	fix.assert_eq(settings.binding_text("ui_accept"), "E", "The menu confirmation action can be remapped")
	await fix.simulate_key(KEY_ESCAPE)
	fix.assert_false(panel.visible, "Escape closes settings")
	fix.assert_eq(fix.root.gui_get_focus_owner(), main.main_menu.settings_button, "Closing restores settings button focus")
	await fix.simulate_key(KEY_ENTER)
	fix.assert_false(panel.visible, "The old confirmation key no longer activates a button")
	await fix.simulate_key(KEY_E)
	fix.assert_true(panel.visible, "Custom confirmation key opens settings")
	await TestUI._keyboard_focus(fix, panel.binding_buttons.ui_cancel)
	await fix.simulate_key(KEY_E)
	await fix.simulate_key(KEY_Q)
	await fix.simulate_key(KEY_Q)
	fix.assert_false(panel.visible, "Custom back key closes settings")
	var legacy_config := ConfigFile.new()
	legacy_config.load(settings.config_path)
	legacy_config.erase_section_key("controls", "inventory")
	legacy_config.set_value("controls", "ui_up", [{"code": int(KEY_I)}])
	legacy_config.save(settings.config_path)
	settings.load_settings()
	fix.assert_eq(settings.binding_text("ui_up"), "I", "Adding inventory preserves custom keys from older settings")
	fix.assert_false(settings.binding_text("inventory") == "I", "A free inventory key is chosen when I is already assigned")
	_restore(settings, snapshot)
	await fix.teardown()

static func test_rhythm_keys(fix: GameFixture) -> void:
	var settings = fix.root.get_node("UserSettings")
	var snapshot := _snapshot(settings)
	settings.config_path = "user://test-rhythm-settings.cfg"
	fix.assert_eq(settings.rebind("rhythm_attack", settings.key_event(KEY_F)), OK, "Attack can be remapped")
	fix.assert_eq(settings.rebind("rhythm_guard", settings.key_event(KEY_G)), OK, "Guard can be remapped")
	var main = await fix.create_main()
	await fix.enter_regular_encounter(main)
	main.monster_view._start_rhythm()
	var rhythm = main.monster_view.rhythm_game
	rhythm.set_process(false)
	fix.assert_true(rhythm.controls_hint.is_visible_in_tree(), "Keys are visible throughout rhythm combat")
	fix.assert_true(rhythm.controls_hint.text.contains("F") and rhythm.controls_hint.text.contains("G"), "On-screen instructions show current keys")
	fix.assert_true(rhythm.timing_hint.is_visible_in_tree(), "Timing instruction is visible")
	fix.assert_true(rhythm.hit_button.text.contains("F") and rhythm.guard_button.text.contains("G"), "Action buttons show current keys too")
	for action in [RhythmRound.ATTACK, RhythmRound.GUARD]:
		rhythm.start(10, 10, main.monster_view.current_monster)
		var index: int = rhythm.round_state.note_actions.find(action)
		fix.assert_true(index >= 0, "Test pattern has the requested action")
		rhythm.started_usec = Time.get_ticks_usec() - int(rhythm.round_state.note_times[index] * 1000000.0)
		var before: int = rhythm.round_state.hits
		await fix.simulate_key(KEY_SPACE if action == RhythmRound.ATTACK else KEY_SHIFT)
		fix.assert_eq(rhythm.round_state.hits, before, "Old key no longer scores hits")
		rhythm.started_usec = Time.get_ticks_usec() - int(rhythm.round_state.note_times[index] * 1000000.0)
		await fix.simulate_key(KEY_F if action == RhythmRound.ATTACK else KEY_G)
		fix.assert_eq(rhythm.round_state.hits, before + 1, "Custom key scores the matching note")
	settings.rebind("rhythm_attack", settings.key_event(KEY_LEFT))
	settings.rebind("rhythm_guard", settings.key_event(KEY_TAB))
	for action in [RhythmRound.ATTACK, RhythmRound.GUARD]:
		rhythm.start(10, 10, main.monster_view.current_monster)
		var index: int = rhythm.round_state.note_actions.find(action)
		rhythm.started_usec = Time.get_ticks_usec() - int(rhythm.round_state.note_times[index] * 1000000.0)
		var before: int = rhythm.round_state.hits
		await fix.simulate_key(KEY_LEFT if action == RhythmRound.ATTACK else KEY_TAB)
		fix.assert_eq(rhythm.round_state.hits, before + 1, "Rhythm bindings take priority over menu navigation during combat")
	_restore(settings, snapshot)
	await fix.teardown()
