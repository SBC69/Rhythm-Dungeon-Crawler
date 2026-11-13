extends Control

signal restart_requested

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var desc_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DescLabel
@onready var stats_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsLabel
@onready var restart_button: Button = $PanelContainer/MarginContainer/VBoxContainer/RestartButton

func _ready() -> void:
	UiIcons.label(title_label, "skull", 20)
	UiIcons.button(restart_button, "repeat")
	restart_button.pressed.connect(_on_restart_pressed)

func show_screen(is_triumph: bool) -> void:
	restart_button.text = tr("UI_RETURN_VILLAGE")
	UiIcons.button(restart_button, "castle")
	visible = true
	if is_triumph:
		UiIcons.label(title_label, "crown", 20)
		title_label.text = tr("ADVENTURER'S TRIUMPH!")
		title_label.modulate = Color(1.0, 0.85, 0.3)
		desc_label.text = tr("You emerge from the crypts alive, laden with glory and treasure!")
	else:
		UiIcons.label(title_label, "skull", 20)
		title_label.text = tr("YOU FELL IN THE DUNGEON...")
		title_label.modulate = Color(1.0, 0.3, 0.3)
		desc_label.text = tr("Your strength ran out, and the dungeon claimed another lost soul.")

	stats_label.text = tr("EXPEDITION RESULTS:\n")
	stats_label.text += tr("• Rooms cleared: %d\n") % GameManager.rooms_cleared_total
	stats_label.text += tr("• Floor reached: %d\n") % GameManager.current_floor
	stats_label.text += tr("• Monsters slain: %d\n") % GameManager.monsters_slain_total
	var combat_stats := GameManager.get_combat_stats()
	stats_label.text += "• " + tr("UI_HERO_COMBAT_STATS") % [combat_stats.attack, combat_stats.defense]

func _on_restart_pressed() -> void:
	SoundManager.play_click()
	visible = false
	emit_signal("restart_requested")
