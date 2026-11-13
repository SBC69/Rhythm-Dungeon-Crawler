extends Control

signal monster_defeated
signal rhythm_failed(raw_damage: int)
signal escape_requested(monster_data: Dictionary)

const RhythmCombat = preload("res://scripts/combat/rhythm_combat.gd")

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/TitleLabel
@onready var name_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/NameLabel
@onready var monster_texture: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/MonsterTexture
@onready var flavor_label: Label = $PanelContainer/MarginContainer/VBoxContainer/FlavorLabel
@onready var power_comparison_label: Label = $PanelContainer/MarginContainer/VBoxContainer/PowerComparison
@onready var status_hint_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatusHint
@onready var victory_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Buttons/VictoryButton
@onready var fight_penalty_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Buttons/FightPenaltyButton
@onready var escape_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Buttons/EscapeButton

var current_monster: Dictionary = {}
var breathing_time: float = 0.0
var is_resolving: bool = false
var current_encounter_id: String = ""
var current_run_generation: int = 0
var active_tween: Tween = null
var rhythm_game: CombatRhythmView
var locked_controller: EncounterController

func _ready() -> void:
	UiIcons.label(power_comparison_label, "sword")
	UiIcons.button(victory_button, "sword")
	UiIcons.button(fight_penalty_button, "sword")
	UiIcons.button(escape_button, "dice")
	rhythm_game = RhythmCombat.new()
	$PanelContainer/MarginContainer/VBoxContainer.add_child(rhythm_game)
	rhythm_game.completed.connect(_on_rhythm_completed)
	visibility_changed.connect(_on_visibility_changed)
	victory_button.pressed.connect(_on_victory_pressed)
	fight_penalty_button.pressed.connect(_on_fight_penalty_pressed)
	escape_button.pressed.connect(_on_escape_pressed)
	GameManager.player_stats_changed.connect(update_combat_evaluation)

func _process(delta: float) -> void:
	if current_run_generation != GameManager.run_generation and is_resolving:
		_cancel_rhythm()
		return
	if is_resolving:
		return
	breathing_time += delta
	var scale_factor = 1.0 + 0.025 * sin(breathing_time * 3.0)
	monster_texture.scale = Vector2(scale_factor, scale_factor)

func setup_monster(monster_data: Dictionary) -> void:
	_cancel_rhythm()
	monster_texture.visible = true
	monster_texture.custom_minimum_size = Vector2(130, 130)
	monster_texture.pivot_offset = Vector2(65, 65)
	flavor_label.visible = true
	power_comparison_label.visible = true
	status_hint_label.visible = true
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
		active_tween = null
	
	is_resolving = false
	current_run_generation = GameManager.run_generation
	current_encounter_id = str(monster_data.get("encounter_id", "enc_%d_%d" % [Time.get_ticks_msec(), randi()]))
	monster_data["encounter_id"] = current_encounter_id
	
	current_monster = monster_data
	if not current_monster.has("q"):
		# Older saved encounters may predate the depth field used by the rhythm curve.
		var context := {"floor_number": GameManager.current_floor, "dungeon_index": GameManager.get_current_dungeon_index(), "mode": RunMode.mode_to_string(GameManager.run_mode)}
		current_monster["q"] = EncounterFactory.calculate_q_for_context(context, GameManager.balance_config.config_data)
	name_label.text = tr(str(monster_data.get("name", "Monster")))
	var title := UiIcons.plain_text(str(monster_data.get("title", "")))
	# Old saves may have an elite prefix embedded in the title.
	if monster_data.get("is_elite", false):
		var template: Dictionary = EncounterFactory.MONSTER_TEMPLATES.get(str(monster_data.get("id", "")), {})
		title_label.text = tr("[ ELITE ENEMY ] ") + tr(str(template.get("title", title)))
	else:
		title_label.text = tr(title)
	flavor_label.text = tr(str(monster_data.get("flavor", "")))

	if monster_data.get("is_boss", false):
		UiIcons.label(title_label, "crown")
		name_label.modulate = Color(1.0, 0.3, 0.3)
		title_label.text = tr("[ FLOOR BOSS ] ") + title_label.text
	else:
		UiIcons.label(title_label, "crown" if monster_data.get("is_elite", false) else "")
		name_label.modulate = Color(1.0, 0.9, 0.7)

	var sprite_path := EncounterFactory.sprite_for(monster_data)
	if ResourceLoader.exists(sprite_path):
		monster_texture.texture = load(sprite_path)
	var raw_tint = monster_data.get("tint", Color.WHITE)
	if EncounterFactory.MONSTER_TEMPLATES.has(str(monster_data.get("id", ""))) or str(monster_data.get("id", "")) == "boss_archon":
		raw_tint = Color.WHITE
	if raw_tint is Array and raw_tint.size() >= 4:
		monster_texture.modulate = Color(raw_tint[0], raw_tint[1], raw_tint[2], raw_tint[3])
	elif raw_tint is Color:
		monster_texture.modulate = raw_tint
	else:
		monster_texture.modulate = Color.WHITE
	monster_texture.scale = Vector2.ONE

	victory_button.disabled = false
	fight_penalty_button.disabled = false
	escape_button.disabled = false

	update_combat_evaluation()

func _lock_buttons() -> void:
	victory_button.disabled = true
	fight_penalty_button.disabled = true
	escape_button.disabled = true

func update_combat_evaluation() -> void:
	if current_monster.is_empty() or is_resolving:
		return

	var player_pow = GameManager.get_total_player_power()
	var monster_pow = int(current_monster.get("power", 1))
	var player_stats := GameManager.get_combat_stats()
	var equipment := _rhythm_equipment()
	var settings := RhythmRound.settings_for(player_pow, monster_pow, current_monster, equipment, player_stats)
	power_comparison_label.text = tr("UI_COMBAT_STAT_COMPARISON") % [settings.player_attack, settings.player_defense, settings.monster_attack, settings.monster_defense]

	if player_pow >= monster_pow:
		victory_button.visible = true
		victory_button.text = tr("START RHYTHM BATTLE")
		victory_button.modulate = Color(0.4, 1.0, 0.4)
		fight_penalty_button.visible = false
		escape_button.visible = false
		var fail_damage := CombatRules.calculate_damage(10, int(GameManager.equipped_armor.get("damage_reduction", 0)), GameManager.player_hp)
		status_hint_label.text = tr("UI_RHYTHM_TARGET_RISK") % [roundi(float(settings.required_accuracy) * 100), int(fail_damage.resolved_damage)]
		status_hint_label.modulate = Color(0.5, 1.0, 0.6)
	else:
		var diff = monster_pow - player_pow
		var raw_penalty = diff * 10
		var reduction = 0
		if not GameManager.equipped_armor.is_empty():
			reduction = int(GameManager.equipped_armor.get("damage_reduction", 0))
		var estimated_damage = maxi(1, raw_penalty - reduction)

		victory_button.visible = false
		fight_penalty_button.visible = true
		fight_penalty_button.text = tr("RHYTHM BATTLE (risk -%d HP)") % estimated_damage
		fight_penalty_button.modulate = Color(1.0, 0.4, 0.3)

		escape_button.visible = true
		escape_button.text = tr("DICE ESCAPE")
		escape_button.modulate = Color(1.0, 0.85, 0.3)

		status_hint_label.text = tr("UI_RHYTHM_TARGET_RISK") % [roundi(float(settings.required_accuracy) * 100), estimated_damage]
		status_hint_label.modulate = Color(1.0, 0.6, 0.4)
	var threatening := int(settings.attack_gap) > 0 or int(settings.defense_gap) > 0 or float(settings.boss_bpm_bonus) > 0.0
	status_hint_label.modulate = Color(1.0, 0.6, 0.4) if threatening else Color(0.5, 1.0, 0.6)
	if victory_button.visible:
		victory_button.modulate = Color(1.0, 0.75, 0.4) if threatening else Color(0.4, 1.0, 0.4)
	status_hint_label.tooltip_text = RhythmEquipment.summary(equipment)
	status_hint_label.text += "\n" + tr("UI_RHYTHM_STAT_DEFICITS") % [maxi(0, int(settings.attack_gap)), maxi(0, int(settings.defense_gap))]
	if float(settings.boss_bpm_bonus) > 0.0:
		status_hint_label.text += "\n" + tr("UI_RHYTHM_BOSS_BONUS") % int(settings.boss_bpm_bonus)
	status_hint_label.text += "\n%s: %s" % [settings.pattern_name, settings.pattern_hint]
	status_hint_label.text += tr("\n%d BPM • %d notes • Timing ±%d ms") % [settings.bpm, settings.note_count, roundi(float(settings.hit_window) * 1000.0)]

func _on_victory_pressed() -> void:
	_start_rhythm()

func _on_fight_penalty_pressed() -> void:
	_start_rhythm()

func _start_rhythm() -> void:
	if is_resolving or not is_visible_in_tree() or current_monster.is_empty() or current_run_generation != GameManager.run_generation:
		return
	is_resolving = true
	_lock_buttons()
	locked_controller = GameManager.encounter_controller
	if locked_controller != null:
		locked_controller.combat_input_locked = true
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	monster_texture.custom_minimum_size = Vector2(64, 64)
	monster_texture.pivot_offset = Vector2(32, 32)
	flavor_label.visible = false
	power_comparison_label.visible = false
	status_hint_label.visible = false
	victory_button.get_parent().visible = false
	rhythm_game.start(GameManager.get_total_player_power(), int(current_monster.get("power", 1)), current_monster, _rhythm_equipment(), GameManager.get_combat_stats())

func _rhythm_equipment() -> Array:
	return [GameManager.equipped_weapon, GameManager.equipped_armor, GameManager.equipped_amulet]

func _on_rhythm_completed(result: Dictionary) -> void:
	if not is_resolving or not is_visible_in_tree() or current_run_generation != GameManager.run_generation:
		_cancel_rhythm()
		return
	if not bool(result.success):
		rhythm_failed.emit(int(result.raw_damage))
		return
	if GameManager.player_hp > 0 and not GameManager.is_game_over:
		monster_texture.visible = true
		SoundManager.play_victory()
		_animate_monster_defeat()

func _cancel_rhythm() -> void:
	if rhythm_game != null:
		rhythm_game.stop()
	if locked_controller != null:
		locked_controller.combat_input_locked = false
		locked_controller = null
	if is_instance_valid(victory_button):
		victory_button.get_parent().visible = true

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_cancel_rhythm()

func _exit_tree() -> void:
	_cancel_rhythm()

func _animate_monster_defeat() -> void:
	var captured_gen = current_run_generation
	var captured_enc = current_encounter_id
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween()
	active_tween.tween_property(monster_texture, "modulate", Color(2.5, 0.2, 0.2), 0.1)
	active_tween.tween_property(monster_texture, "scale", Vector2(1.2, 0.8), 0.1)
	active_tween.tween_property(monster_texture, "modulate:a", 0.0, 0.2)
	await active_tween.finished
	if captured_gen != GameManager.run_generation or captured_enc != current_encounter_id or not is_visible_in_tree():
		return
	emit_signal("monster_defeated")

func _on_escape_pressed() -> void:
	if is_resolving:
		return
	is_resolving = true
	_lock_buttons()
	SoundManager.play_click()
	emit_signal("escape_requested", current_monster)
