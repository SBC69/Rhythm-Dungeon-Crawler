extends PanelContainer

signal card_sold(card_data: Dictionary)

@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var icon_label: Label = $Margin/VBox/IconLabel

var default_border_color: Color = Color(0.85, 0.65, 0.25, 1.0)
var hover_border_color: Color = Color(1.0, 0.95, 0.4, 1.0)
var stylebox: StyleBoxFlat

func _ready() -> void:
	UiIcons.icon_only(icon_label, "cart", 28)
	var current_sb = get_theme_stylebox("panel")
	if current_sb is StyleBoxFlat:
		stylebox = current_sb.duplicate()
		add_theme_stylebox_override("panel", stylebox)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.get("type", "") == "card":
		var card = data.get("card_data", {})
		var price = int(card.get("sell_value", 15))
		if stylebox:
			stylebox.border_color = hover_border_color
			stylebox.bg_color = Color(0.25, 0.2, 0.08, 0.95)
		status_label.text = tr("Drop to sell for %d gold!") % price
		status_label.modulate = Color(1.0, 1.0, 0.4)
		return true

	if stylebox:
		stylebox.border_color = Color(0.8, 0.3, 0.3)
	status_label.text = tr("This item is not for sale.")
	status_label.modulate = Color(1.0, 0.5, 0.5)
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_reset_visuals()
	if data is Dictionary and data.get("type", "") == "card":
		var card = data.get("card_data", {})
		emit_signal("card_sold", card)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_reset_visuals()

func _reset_visuals() -> void:
	if stylebox:
		stylebox.border_color = default_border_color
		stylebox.bg_color = Color(0.12, 0.09, 0.16, 0.9)
	if is_instance_valid(status_label):
		status_label.text = tr("Drag and drop a card here")
		status_label.modulate = Color(0.85, 0.85, 0.9)
