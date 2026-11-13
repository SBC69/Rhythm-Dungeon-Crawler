extends Control

signal escape_resolved(success: bool, raw_damage: int)

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var dc_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DCLabel
@onready var dice1_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DiceContainer/Die1/NumberLabel
@onready var dice2_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DiceContainer/Die2/NumberLabel
@onready var die1_panel: PanelContainer = $PanelContainer/MarginContainer/VBoxContainer/DiceContainer/Die1
@onready var die2_panel: PanelContainer = $PanelContainer/MarginContainer/VBoxContainer/DiceContainer/Die2
@onready var result_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ResultLabel
@onready var reroll_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Buttons/RerollButton
@onready var action_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Buttons/ActionButton

var monster_data: Dictionary = {}
var target_dc: int = 7
var power_diff: int = 1
var remaining_rerolls: int = 1
var is_rolling: bool = false
var has_rolled: bool = false

var last_d1: int = 1
var last_d2: int = 1

func _ready() -> void:
	UiIcons.label(title_label, "dice", 20)
	reroll_button.pressed.connect(_on_reroll_pressed)
	action_button.pressed.connect(_on_action_pressed)

func _get_damage_forecast() -> Dictionary:
	var raw_penalty = power_diff * 10
	var reduction = 0
	if not GameManager.equipped_armor.is_empty():
		reduction = int(GameManager.equipped_armor.get("damage_reduction", 0))
	return CombatRules.calculate_damage(raw_penalty, reduction, GameManager.player_hp)

func setup_escape(monster: Dictionary) -> void:
	UiIcons.label(result_label, "")
	monster_data = monster
	var player_pow = GameManager.get_total_player_power()
	var monster_pow = int(monster.get("power", 1))
	power_diff = maxi(1, monster_pow - player_pow)

	# Target DC: base 7 + power difference, capped at 11 so 11 and 12 can still win without doubles
	target_dc = CombatRules.calculate_escape_dc(power_diff)

	remaining_rerolls = 1 + GameManager.extra_rerolls
	is_rolling = false
	has_rolled = false

	title_label.text = tr("ESCAPE FROM: %s") % tr(str(monster.get("name", "")))
	var bonus_text = ""
	if GameManager.dice_bonus > 0:
		bonus_text = tr(" (Amulet bonus: +%d)") % GameManager.dice_bonus
	
	var dmg_forecast = _get_damage_forecast()
	var estimated_damage = dmg_forecast["resolved_damage"]
	var armor_hint = ""
	if dmg_forecast["armor_reduction"] > 0:
		armor_hint = tr(" [Armor -%d]") % dmg_forecast["armor_reduction"]
	dc_label.text = tr("Target: %d+ or DOUBLES%s\nPower gap: %d (failure: -%d HP%s)") % [target_dc, bonus_text, power_diff, estimated_damage, armor_hint]

	dice1_label.text = "?"
	dice2_label.text = "?"
	result_label.text = tr("Roll the dice to escape!")
	result_label.modulate = Color.WHITE

	reroll_button.visible = false
	action_button.visible = true
	action_button.text = tr("ROLL DICE")
	action_button.modulate = Color(1.0, 0.85, 0.3)

func _start_roll_animation() -> void:
	is_rolling = true
	action_button.disabled = true
	reroll_button.disabled = true
	SoundManager.play_dice_roll()

	# Roll animation
	for i in range(10):
		dice1_label.text = str(randi_range(1, 6))
		dice2_label.text = str(randi_range(1, 6))
		await get_tree().create_timer(0.05).timeout

	last_d1 = randi_range(1, 6)
	last_d2 = randi_range(1, 6)
	dice1_label.text = str(last_d1)
	dice2_label.text = str(last_d2)

	is_rolling = false
	has_rolled = true
	_evaluate_roll()

func _evaluate_roll() -> void:
	var total = last_d1 + last_d2 + GameManager.dice_bonus
	var is_doubles = (last_d1 == last_d2)
	var is_critical = is_doubles or (last_d1 + last_d2 == 12)

	if is_critical or total >= target_dc:
		# Success!
		SoundManager.play_victory()
		if is_critical:
			UiIcons.label(result_label, "spark")
			result_label.text = tr("CRITICAL SUCCESS (Doubles %d-%d)! You dodge the attack in a flash!") % [last_d1, last_d2]
		else:
			UiIcons.label(result_label, "check")
			result_label.text = tr("SUCCESS! Roll: %d (target %d). You escape the monster!") % [total, target_dc]
		result_label.modulate = Color(0.4, 1.0, 0.4)

		reroll_button.visible = false
		action_button.visible = true
		action_button.disabled = false
		action_button.text = tr("RETREAT TO THE CORRIDOR")
		action_button.modulate = Color(0.4, 1.0, 0.4)
	else:
		# Failure
		UiIcons.label(result_label, "close")
		SoundManager.play_damage()
		var dmg_forecast = _get_damage_forecast()
		var estimated_damage = dmg_forecast["resolved_damage"]
		var lethal_hint = tr(" [LETHAL]") if dmg_forecast["is_lethal"] else ""
		result_label.text = tr("FAILURE! Roll: %d (need %d+). The enemy catches you (-%d HP)!") % [total, target_dc, estimated_damage]
		result_label.modulate = Color(1.0, 0.35, 0.35)

		if remaining_rerolls > 0:
			reroll_button.visible = true
			reroll_button.disabled = false
			reroll_button.text = tr("REROLL (%d left)") % remaining_rerolls
			action_button.visible = true
			action_button.disabled = false
			action_button.text = tr("TAKE DAMAGE (-%d HP%s)") % [estimated_damage, lethal_hint]
			action_button.modulate = Color(1.0, 0.4, 0.4)
		else:
			reroll_button.visible = false
			action_button.visible = true
			action_button.disabled = false
			action_button.text = tr("TAKE DAMAGE (-%d HP%s)") % [estimated_damage, lethal_hint]
			action_button.modulate = Color(1.0, 0.4, 0.4)

func _on_reroll_pressed() -> void:
	if remaining_rerolls > 0 and not is_rolling:
		remaining_rerolls -= 1
		_start_roll_animation()

func _on_action_pressed() -> void:
	if not has_rolled:
		_start_roll_animation()
		return

	var total = last_d1 + last_d2 + GameManager.dice_bonus
	var is_doubles = (last_d1 == last_d2)
	var is_critical = is_doubles or (last_d1 + last_d2 == 12)

	if is_critical or total >= target_dc:
		# Safe escape
		emit_signal("escape_resolved", true, 0)
	else:
		# Take x10 damage
		emit_signal("escape_resolved", false, power_diff * GameManager.balance_config.get_damage_per_power_gap())
