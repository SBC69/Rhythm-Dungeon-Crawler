extends Control

signal mode_selected(mode: RunMode.Mode, dungeon_id: String)
signal continue_endless_requested
signal back_requested

@onready var timed_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TimedButton
@onready var endless_button: Button = $PanelContainer/MarginContainer/VBoxContainer/EndlessButton
@onready var continue_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ContinueButton
@onready var wallet_label: Label = $PanelContainer/MarginContainer/VBoxContainer/WalletLabel
@onready var status_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatusLabel

var has_active_endless: bool = false

func _ready() -> void:
	UiIcons.label($PanelContainer/MarginContainer/VBoxContainer/TitleLabel, "sword")
	UiIcons.label(wallet_label, "coins")
	UiIcons.button(timed_button, "hourglass")
	UiIcons.button(endless_button, "infinity")
	UiIcons.button(continue_button, "play")
	timed_button.pressed.connect(_on_timed_pressed)
	endless_button.pressed.connect(_on_endless_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "UI_MAIN_MENU"
	back_button.custom_minimum_size.y = 36
	back_button.pressed.connect(func(): back_requested.emit())
	timed_button.get_parent().add_child(back_button)

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()

func setup(wallet_gold: int, active_endless: bool = false) -> void:
	has_active_endless = active_endless
	wallet_label.text = tr("Profile wallet: %d gold") % wallet_gold
	timed_button.text = tr("UI_MODE_TIMED")
	endless_button.text = tr("UI_MODE_ENDLESS")
	continue_button.text = tr("UI_CONTINUE_ENDLESS")
	
	if has_active_endless:
		continue_button.visible = true
		continue_button.disabled = false
		timed_button.disabled = true
		endless_button.disabled = true
		status_label.text = tr("You have an unfinished endless expedition! Continue it or retire at a campfire.")
		continue_button.grab_focus()
	else:
		continue_button.visible = false
		timed_button.disabled = false
		endless_button.disabled = false
		status_label.text = tr("Choose an adventure mode:")
		timed_button.grab_focus()

func _on_timed_pressed() -> void:
	if has_active_endless:
		return
	SoundManager.play_click()
	emit_signal("mode_selected", RunMode.Mode.TIMED_100, "crypts")

func _on_endless_pressed() -> void:
	if has_active_endless:
		return
	SoundManager.play_click()
	emit_signal("mode_selected", RunMode.Mode.ENDLESS, "crypts")

func _on_continue_pressed() -> void:
	SoundManager.play_click()
	emit_signal("continue_endless_requested")
