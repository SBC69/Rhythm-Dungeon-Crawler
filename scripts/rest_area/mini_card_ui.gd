extends Control

signal card_clicked(card_data: Dictionary)

@onready var panel: PanelContainer = $PanelContainer
@onready var icon_rect: TextureRect = $PanelContainer/Margin/VBox/IconRect
@onready var name_label: Label = $PanelContainer/Margin/VBox/NameLabel
@onready var price_label: Label = $PanelContainer/Margin/VBox/PriceLabel
@onready var stack_badge: PanelContainer = $StackBadge
@onready var stack_label: Label = $StackBadge/StackLabel

var card_data: Dictionary = {}
var is_hovered: bool = false
var is_dragging: bool = false
var mouse_press_pos: Vector2 = Vector2.ZERO
var is_mouse_down: bool = false

func _ready() -> void:
	UiIcons.label(price_label, "coins", 12)
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	gui_input.connect(_on_gui_input)

func _on_focus_entered() -> void:
	_on_mouse_entered()

func _on_focus_exited() -> void:
	_on_mouse_exited()

func setup(data: Dictionary) -> void:
	card_data = data
	_update_visuals()

func _update_visuals() -> void:
	if card_data.is_empty():
		name_label.text = ""
		price_label.text = ""
		icon_rect.texture = null
		stack_badge.visible = false
		tooltip_text = ""
		return

	name_label.text = CardPresenter.get_display_name(card_data)
	price_label.text = CardPresenter.get_sell_price_text(card_data)
	tooltip_text = CardPresenter.get_tooltip_text(card_data)

	var icon_path = str(card_data.get("icon", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path)
	else:
		icon_rect.texture = null

	var count = int(card_data.get("count", 1))
	if count > 1:
		stack_badge.visible = true
		stack_label.text = CardPresenter.get_count_text(card_data)
	else:
		stack_badge.visible = false

	var border_color = CardPresenter.get_rarity_color(card_data)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.09, 0.16, 0.95)
	sb.border_color = border_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)

func _get_drag_data(_at_position: Vector2) -> Variant:
	is_dragging = true
	is_mouse_down = false

	var preview_root = Control.new()
	var preview_panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.11, 0.2, 0.95)
	sb.border_color = Color(1.0, 0.85, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	preview_panel.add_theme_stylebox_override("panel", sb)
	preview_panel.custom_minimum_size = Vector2(110, 42)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon = TextureRect.new()
	icon.texture = icon_rect.texture
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hbox.add_child(icon)

	var lbl = Label.new()
	lbl.text = CardPresenter.get_display_name(card_data)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	hbox.add_child(lbl)

	preview_panel.add_child(hbox)
	preview_panel.position = Vector2(-55, -21)
	preview_root.add_child(preview_panel)
	set_drag_preview(preview_root)

	SoundManager.play_click()
	return {
		"type": "card",
		"card_data": card_data
	}

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_visuals()
	if what == NOTIFICATION_DRAG_END:
		is_dragging = false
		is_mouse_down = false

func _on_mouse_entered() -> void:
	if is_dragging:
		return
	is_hovered = true
	SoundManager.play_card_hover()
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.06, 1.06), 0.1)

func _on_mouse_exited() -> void:
	is_hovered = false
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_press_pos = event.global_position
			is_mouse_down = true
			is_dragging = false
		else:
			if is_mouse_down and not is_dragging:
				is_mouse_down = false
				var dist = event.global_position.distance_to(mouse_press_pos)
				if dist < 8.0:
					emit_signal("card_clicked", card_data)
			is_mouse_down = false
	elif event.is_action_pressed("ui_accept"):
		accept_event()
		emit_signal("card_clicked", card_data)
