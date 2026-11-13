extends Control

signal curse_resolved(raw_damage: int, drain: int)

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var desc_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DescLabel
@onready var trap_texture: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/TrapTexture
@onready var roll_label: Label = $PanelContainer/MarginContainer/VBoxContainer/RollLabel
@onready var outcome_label: Label = $PanelContainer/MarginContainer/VBoxContainer/OutcomeLabel
@onready var action_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ActionButton

var curse_data: Dictionary = {}
var has_rolled: bool = false
var is_rolling: bool = false
var remaining_rerolls: int = 0
var pending_outcome: Dictionary = {}
var reroll_button: Button

func _ready() -> void:
	UiIcons.label(title_label, "warning", 20)
	UiIcons.button(action_button, "dice")
	action_button.pressed.connect(_on_action_pressed)
	var parent_box = action_button.get_parent()
	reroll_button = Button.new()
	UiIcons.button(reroll_button, "dice")
	reroll_button.name = "RerollButton"
	reroll_button.custom_minimum_size = Vector2(240, 42)
	reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reroll_button.add_theme_font_size_override("font_size", 14)
	reroll_button.modulate = Color(1.0, 0.85, 0.3)
	reroll_button.visible = false
	parent_box.add_child(reroll_button)
	parent_box.move_child(reroll_button, action_button.get_index())
	reroll_button.pressed.connect(_on_reroll_pressed)

func setup_curse(data: Dictionary) -> void:
	UiIcons.label(outcome_label, "")
	UiIcons.button(action_button, "dice")
	curse_data = data
	has_rolled = false
	is_rolling = false
	pending_outcome.clear()
	# D11: without ring 0 rerolls, with ring 1
	remaining_rerolls = GameManager.extra_rerolls

	title_label.text = tr(str(data.get("name", "Curse")))
	var ring_hint = tr(" (1 ring reroll available)") if remaining_rerolls > 0 else ""
	desc_label.text = tr(str(data.get("flavor", ""))) + tr("\nRoll 2d6 to save (target: %d+ or doubles).%s") % [data.get("dc", 6), ring_hint]

	roll_label.text = tr("Dice: [ ? ] and [ ? ]")
	outcome_label.text = tr("Press the button for a saving roll!")
	outcome_label.modulate = Color(1.0, 0.9, 0.5)

	if reroll_button != null:
		reroll_button.visible = false
	action_button.text = tr("SAVING ROLL (2d6)")
	action_button.disabled = false
	action_button.modulate = Color(1.0, 0.8, 0.3)

func _on_action_pressed() -> void:
	if not has_rolled:
		_roll_save()
	else:
		if not pending_outcome.is_empty():
			emit_signal("curse_resolved", int(pending_outcome.get("raw_damage", 0)), int(pending_outcome.get("drain", 0)))

func _on_reroll_pressed() -> void:
	if remaining_rerolls > 0 and not is_rolling:
		remaining_rerolls -= 1
		reroll_button.visible = false
		_roll_save()

func _roll_save() -> void:
	is_rolling = true
	action_button.disabled = true
	if reroll_button != null:
		reroll_button.disabled = true
	SoundManager.play_dice_roll()

	for i in range(8):
		roll_label.text = tr("Dice: [ %d ] and [ %d ]") % [randi_range(1, 6), randi_range(1, 6)]
		await get_tree().create_timer(0.05).timeout

	var d1 = randi_range(1, 6)
	var d2 = randi_range(1, 6)
	var is_doubles = (d1 == d2) # D12: any doubles saves completely!
	var dice_bonus = GameManager.dice_bonus
	var sum = d1 + d2 + dice_bonus
	var dc = int(curse_data.get("dc", 6))
	var base_dmg = int(curse_data.get("damage_on_fail", 10))
	var drain = int(curse_data.get("power_drain", 0))

	var bonus_text = tr(" (+%d bonus)") % dice_bonus if dice_bonus > 0 else ""
	roll_label.text = tr("Dice: [ %d ] and [ %d ] (Total: %d%s, Target: %d)") % [d1, d2, sum, bonus_text, dc]

	has_rolled = true
	is_rolling = false

	var reduction = 0
	if not GameManager.equipped_armor.is_empty():
		reduction = int(GameManager.equipped_armor.get("damage_reduction", 0))

	if is_doubles or sum >= dc:
		# Complete success
		UiIcons.label(outcome_label, "spark")
		UiIcons.button(action_button, "")
		SoundManager.play_victory()
		pending_outcome = {"type": "success", "raw_damage": 0, "drain": 0}
		if is_doubles:
			outcome_label.text = tr("DOUBLES (%d-%d)! You escape the trap unharmed!") % [d1, d2]
		else:
			outcome_label.text = tr("SUCCESS! Roll %d >= %d. The trap misses you!") % [sum, dc]
		outcome_label.modulate = Color(0.4, 1.0, 0.4)
		if reroll_button != null:
			reroll_button.visible = false
		action_button.text = tr("CONTINUE ONWARD")
		action_button.modulate = Color(0.4, 1.0, 0.4)
		action_button.disabled = false
	elif sum >= dc - 2:
		# Partial hit (D11/D12: partial does not apply power drain)
		UiIcons.label(outcome_label, "warning")
		UiIcons.button(action_button, "")
		var half_dmg = maxi(1, int(floori(base_dmg / 2.0)))
		var forecast = CombatRules.calculate_damage(half_dmg, reduction, GameManager.player_hp)
		pending_outcome = {"type": "partial", "raw_damage": half_dmg, "drain": 0}
		outcome_label.text = tr("PARTIAL DAMAGE! You take a glancing hit (-%d HP).") % forecast["resolved_damage"]
		outcome_label.modulate = Color(1.0, 0.7, 0.3)

		if remaining_rerolls > 0 and reroll_button != null:
			reroll_button.visible = true
			reroll_button.disabled = false
			reroll_button.text = tr("REROLL (%d left)") % remaining_rerolls
		elif reroll_button != null:
			reroll_button.visible = false
		
		action_button.text = tr("TAKE DAMAGE (-%d HP)") % forecast["resolved_damage"]
		action_button.modulate = Color(1.0, 0.7, 0.3)
		action_button.disabled = false
	else:
		# Full hit
		UiIcons.label(outcome_label, "warning")
		UiIcons.button(action_button, "")
		var forecast = CombatRules.calculate_damage(base_dmg, reduction, GameManager.player_hp)
		pending_outcome = {"type": "full", "raw_damage": base_dmg, "drain": drain}
		var drain_text = tr(", -%d power") % drain if drain > 0 else ""
		outcome_label.text = tr("FAILURE! The trap triggers (-%d HP%s)!") % [forecast["resolved_damage"], drain_text]
		outcome_label.modulate = Color(1.0, 0.3, 0.3)

		if remaining_rerolls > 0 and reroll_button != null:
			reroll_button.visible = true
			reroll_button.disabled = false
			reroll_button.text = tr("REROLL (%d left)") % remaining_rerolls
		elif reroll_button != null:
			reroll_button.visible = false

		action_button.text = tr("TAKE DAMAGE (-%d HP)") % forecast["resolved_damage"]
		action_button.modulate = Color(1.0, 0.4, 0.4)
		action_button.disabled = false
