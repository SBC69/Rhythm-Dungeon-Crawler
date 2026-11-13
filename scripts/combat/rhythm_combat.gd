class_name CombatRhythmView
extends VBoxContainer

signal completed(result: Dictionary)

const GOLD := Color("edc77a")
const MINT := Color("81eed0")
const CORAL := Color("f18e77")
const GUARD_COLOR := Color("82bdf0")
const MUTED := Color("9c91b0")
const TARGET_X: float = 72.0
const EFFECT_DURATION: float = 0.32

var round_state: RhythmRound
var running: bool = false
var started_usec: int = 0
var last_beat: int = -1
var next_sound_note: int = 0
var info: Label
var lane: Control
var feedback: Label
var hit_button: Button
var guard_button: Button
var lane_style: StyleBoxFlat
var tempo: Label
var stats: Label
var combo_label: Label
var progress: Control
var controls_hint: Label
var timing_hint: Label
var combo: int = 0
var effect_left: float = 0.0
var effect_color: Color = MINT
var beat_pulse: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lane_style = _lane_style()
	add_theme_constant_override("separation", 6)
	var heading := HBoxContainer.new()
	add_child(heading)
	info = _label(14, GOLD)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(info)
	tempo = _label(12, MUTED)
	heading.add_child(tempo)
	var counters := HBoxContainer.new()
	add_child(counters)
	stats = _label(12, MUTED)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	counters.add_child(stats)
	combo_label = _label(12, Color.WHITE)
	counters.add_child(combo_label)
	progress = Control.new()
	progress.custom_minimum_size.y = 8
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.draw.connect(_draw_progress)
	add_child(progress)
	controls_hint = _label(14, GOLD)
	controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(controls_hint)
	timing_hint = _label(12, MINT)
	timing_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timing_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timing_hint.text = "UI_RHYTHM_TIMING_HELP"
	add_child(timing_hint)
	lane = Control.new()
	lane.custom_minimum_size = Vector2(0, 92)
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane.draw.connect(_draw_lane)
	add_child(lane)
	feedback = _label(15, Color.WHITE)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.custom_minimum_size.y = 24
	add_child(feedback)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	add_child(actions)
	hit_button = _action_button("", RhythmRound.ATTACK, GOLD)
	guard_button = _action_button("", RhythmRound.GUARD, GUARD_COLOR)
	actions.add_child(hit_button)
	actions.add_child(guard_button)
	UserSettings.changed.connect(_refresh_controls)
	_refresh_controls()
	visible = false

func _refresh_controls() -> void:
	var attack := UserSettings.binding_text("rhythm_attack")
	var guard := UserSettings.binding_text("rhythm_guard")
	controls_hint.text = tr("UI_RHYTHM_KEYS") % [attack, guard]
	hit_button.text = tr("UI_RHYTHM_ATTACK_BUTTON") % attack.split(" / ")[0]
	guard_button.text = tr("UI_RHYTHM_GUARD_BUTTON") % guard.split(" / ")[0]
	hit_button.tooltip_text = tr("UI_RHYTHM_ATTACK_HELP") % attack
	guard_button.tooltip_text = tr("UI_RHYTHM_GUARD_HELP") % guard

func _action_button(text: String, action: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", color)
	button.button_down.connect(_press.bind(action))
	return button

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_border_width_all(2)
	style.border_color = border
	style.set_corner_radius_all(2)
	return style

func start(player_power: int, monster_power: int, monster: Dictionary = {}, equipment: Array = [], player_stats: Dictionary = {}) -> void:
	round_state = RhythmRound.new(player_power, monster_power, monster, equipment, player_stats)
	info.tooltip_text = str(round_state.settings.pattern_hint) + "\n" + RhythmEquipment.summary(equipment)
	running = true
	last_beat = -1
	next_sound_note = 0
	combo = 0
	effect_left = 0.0
	beat_pulse = 0.0
	started_usec = Time.get_ticks_usec()
	visible = true
	hit_button.disabled = false
	guard_button.disabled = false
	feedback.text = tr("GET READY")
	feedback.modulate = GOLD
	_update_info()
	lane.queue_redraw()

func stop() -> void:
	running = false
	effect_left = 0.0
	visible = false

func _input(event: InputEvent) -> void:
	if not running or not is_visible_in_tree():
		return
	var key_hit := UserSettings.rhythm_key_pressed(event, "rhythm_attack")
	var key_guard := UserSettings.rhythm_key_pressed(event, "rhythm_guard")
	var pad_hit: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A
	var pad_guard: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B
	var mouse_guard: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	if key_hit or pad_hit or key_guard or pad_guard or mouse_guard:
		get_viewport().set_input_as_handled()
		_press(RhythmRound.GUARD if key_guard or pad_guard or mouse_guard else RhythmRound.ATTACK)

func _process(delta: float) -> void:
	if not running or not is_visible_in_tree():
		return
	effect_left = maxf(0.0, effect_left - delta)
	beat_pulse = maxf(0.0, beat_pulse - delta * 4.0)
	var previous_misses := round_state.misses
	round_state.advance_to(_time())
	var beat := floori(round_state.elapsed / float(round_state.settings.interval))
	if beat != last_beat and round_state.elapsed < round_state.note_times[0]:
		last_beat = beat
		beat_pulse = 1.0
		SoundManager.play_rhythm_beat(beat % 4 == 0)
	# After the count-in, the audible rhythm follows attacks, including half beats.
	# Skip old sounds after a long frame instead of playing a burst of catch-up audio.
	var sound_note := -1
	while next_sound_note < round_state.note_times.size() and round_state.note_times[next_sound_note] <= round_state.elapsed:
		sound_note = next_sound_note
		next_sound_note += 1
	if sound_note >= 0:
		beat_pulse = 1.0
		SoundManager.play_rhythm_beat(round_state.accented[sound_note])
	if round_state.misses > previous_misses:
		combo = 0
		_show_feedback(tr("MISSED"), CORAL)
	elif round_state.elapsed < round_state.note_times[0] - round_state.hit_window_for_note(0):
		feedback.text = tr("COUNT IN  %d / 4   ·   WATCH THE LINE") % (mini(3, beat) + 1)
		feedback.modulate = GOLD
	_update_info()
	lane.queue_redraw()
	_finish_if_ready()

func _time() -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000000.0

func _show_feedback(message: String, color: Color) -> void:
	feedback.text = message
	feedback.modulate = color
	effect_color = color
	effect_left = EFFECT_DURATION

func _press(action: String = RhythmRound.ATTACK) -> void:
	if not running:
		return
	var previous_misses := round_state.misses
	var judgement := round_state.press_at(_time(), action)
	if round_state.misses > previous_misses:
		combo = 0
	match judgement:
		"perfect", "hit":
			combo += 1
			_show_feedback(tr("PERFECT!") if judgement == "perfect" else tr("HIT"), MINT if judgement == "perfect" else GOLD)
			SoundManager.play_rhythm_hit()
		"miss":
			combo = 0
			_show_feedback(tr("MISS  ·  KEEP THE RHYTHM"), CORAL)
		"wrong":
			combo = 0
			_show_feedback(tr("WRONG MOVE: DIAMOND — ATTACK, SHIELD — GUARD"), CORAL)
	_update_info()
	lane.queue_redraw()
	_finish_if_ready()

func _update_info() -> void:
	info.text = str(round_state.settings.pattern_name).to_upper()
	tempo.text = "%d BPM" % round_state.settings.bpm
	stats.text = tr("UI_RHYTHM_SCORE_TARGET") % [round_state.hits, round_state.note_times.size(), roundi(float(round_state.settings.required_accuracy) * 100)]
	combo_label.text = tr("COMBO ×%d") % combo if combo > 1 else ""
	combo_label.modulate = MINT if combo >= 5 else GOLD
	progress.queue_redraw()

func _finish_if_ready() -> void:
	if not running or not round_state.finished:
		return
	running = false
	hit_button.disabled = true
	guard_button.disabled = true
	var result := round_state.outcome()
	feedback.text = tr("UI_RHYTHM_RESULT_TARGET") % [floori(float(result.accuracy) * 100.0 + 0.000001), roundi(float(result.required_accuracy) * 100.0), tr("UI_RHYTHM_WIN") if result.success else tr("UI_RHYTHM_LOSS")]
	feedback.modulate = MINT if result.success else CORAL
	completed.emit(result)

func _draw_progress() -> void:
	if round_state == null:
		return
	var width := progress.size.x
	progress.draw_rect(Rect2(0, 2, width, 4), Color("302738"))
	var accuracy := clampf(round_state.accuracy(), 0.0, 1.0)
	var required_accuracy := float(round_state.settings.required_accuracy)
	progress.draw_rect(Rect2(0, 2, width * accuracy, 4), MINT if accuracy >= required_accuracy else GOLD)
	var goal_x := floorf(width * required_accuracy)
	progress.draw_rect(Rect2(goal_x, 0, 2, 8), Color("fff1c8"))

func _draw_diamond(at: Vector2, radius: float, color: Color) -> void:
	lane.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius, 0), at + Vector2(0, radius), at + Vector2(-radius, 0)]), color)

func _draw_lane() -> void:
	if round_state == null:
		return
	var width := lane.size.x
	var height := lane.size.y
	var center_y := floorf(height * 0.54)
	lane.draw_style_box(lane_style, Rect2(Vector2.ZERO, lane.size))
	var travel_time := float(round_state.settings.interval) * 3.0 * float(round_state.settings.preview_multiplier)
	var speed := maxf(1.0, width - TARGET_X - 18.0) / travel_time
	# Geometry uses the real equipment-adjusted judgement window.
	var window_width := round_state.next_hit_window() * speed
	lane.draw_rect(Rect2(TARGET_X - window_width, 25, window_width * 2, height - 40), Color(0.22, 0.66, 0.56, 0.16))
	var interval := float(round_state.settings.interval)
	for beat in range(floori(round_state.elapsed / interval) - 2, ceili(round_state.elapsed / interval + travel_time / interval) + 1):
		var x := floorf(TARGET_X + (float(beat) * interval - round_state.elapsed) * speed)
		if x > 4 and x < width - 4:
			lane.draw_line(Vector2(x, 30), Vector2(x, height - 14), Color("292435"), 1.0)
	for y in [center_y - 15, center_y + 15]:
		lane.draw_line(Vector2(5, y), Vector2(width - 5, y), Color("392d47"), 1.0)
	lane.draw_line(Vector2(5, center_y), Vector2(width - 5, center_y), Color("61516c"), 2.0)
	# Effects never shift the lane or the timing gate.
	lane.draw_rect(Rect2(TARGET_X - 2, 24, 4, height - 37), MINT.lerp(Color.WHITE, beat_pulse * 0.45))
	for y in [24.0, height - 15.0]:
		lane.draw_rect(Rect2(TARGET_X - 12, y, 24, 3), MINT)
	lane.draw_string(lane.get_theme_font("font"), Vector2(TARGET_X - 17, 17), tr("BEAT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MINT)
	lane.draw_string(lane.get_theme_font("font"), Vector2(width - 102, 17), tr("NOTES  ←"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)
	for i in range(round_state.note_times.size()):
		if round_state.judged[i]:
			continue
		var x := floorf(TARGET_X + (round_state.note_times[i] - round_state.elapsed) * speed)
		if x < 16 or x > width - 16:
			continue
		var in_window := absf(round_state.note_times[i] - round_state.elapsed) <= round_state.hit_window_for_note(i)
		var is_guard := round_state.note_actions[i] == RhythmRound.GUARD
		var color := MINT if in_window else (GUARD_COLOR if is_guard else (CORAL if round_state.accented[i] else GOLD))
		var at := Vector2(x, center_y)
		lane.draw_rect(Rect2(x + 16, center_y - 2, 14, 4), Color(color, 0.22))
		_draw_diamond(at + Vector2(0, 3), 15, Color("08070f"))
		_draw_diamond(at, 14, Color("17121e"))
		if is_guard:
			lane.draw_colored_polygon(PackedVector2Array([at + Vector2(-10, -11), at + Vector2(10, -11), at + Vector2(10, 3), at + Vector2(0, 13), at + Vector2(-10, 3)]), color)
			lane.draw_rect(Rect2(x - 6, center_y - 5, 12, 3), Color("182436"))
			lane.draw_rect(Rect2(x - 2, center_y - 5, 4, 13), Color("182436"))
		else:
			_draw_diamond(at, 11, color)
			_draw_diamond(at, 6, Color("392b3a"))
		if round_state.accented[i] and not is_guard:
			lane.draw_rect(Rect2(x - 3, center_y - 3, 6, 6), color.lightened(0.4))
		elif not is_guard:
			lane.draw_rect(Rect2(x - 2, center_y - 2, 4, 4), color.lightened(0.4))
	if round_state.elapsed < round_state.note_times[0]:
		var beat := mini(3, floori(round_state.elapsed / interval))
		for i in range(4):
			lane.draw_rect(Rect2(width * 0.5 - 25 + i * 16, height - 9, 9, 3), GOLD if i <= beat else Color("47384f"))
	if effect_left > 0.0:
		var life := effect_left / EFFECT_DURATION
		var radius := 15.0 + (1.0 - life) * 28.0
		for i in range(8):
			var direction := Vector2.from_angle(float(i) * TAU / 8.0)
			var point := (Vector2(TARGET_X, center_y) + direction * radius).floor()
			lane.draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), Color(effect_color, life))
		_draw_diamond(Vector2(TARGET_X, center_y), 8.0 * life, Color(effect_color, life * 0.8))

func _lane_style() -> StyleBoxFlat:
	return _panel_style(Color("100e1b"), Color("51415f"))
