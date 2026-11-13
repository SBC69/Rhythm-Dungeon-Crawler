# scripts/village/village_map.gd
extends Control

const VillageBuildingNodeScript = preload("res://scripts/village/village_building_node.gd")

signal enter_dungeon_requested
signal main_menu_requested
signal story_view_requested(story_id: String)
signal chronicle_view_requested
signal cosmetics_view_requested
signal building_selected(object_id: String)

@onready var background_rect: TextureRect = $Background
@onready var wallet_label: Label = $TopBar/Margin/HBox/WalletLabel
@onready var enter_dungeon_button: Button = $TopBar/Margin/HBox/EnterDungeonButton
@onready var menu_button: Button = $TopBar/Margin/HBox/MainMenuButton
@onready var map_canvas: Control = $MapCanvas
@onready var buildings_container: Control = $MapCanvas/Buildings

# Detail Modal
@onready var detail_modal: Control = $DetailModal
@onready var detail_title: Label = $DetailModal/Card/Margin/VBox/Header/TitleLabel
@onready var detail_stage: Label = $DetailModal/Card/Margin/VBox/Header/StageBadge
@onready var detail_cur_desc: Label = $DetailModal/Card/Margin/VBox/Scroll/Content/CurDesc
@onready var detail_next_desc: Label = $DetailModal/Card/Margin/VBox/Scroll/Content/NextDesc
@onready var detail_cost: Label = $DetailModal/Card/Margin/VBox/Scroll/Content/CostLabel
@onready var detail_prereq: Label = $DetailModal/Card/Margin/VBox/Scroll/Content/PrereqLabel
@onready var detail_actions_box: HBoxContainer = $DetailModal/Card/Margin/VBox/ActionsBox
@onready var detail_restore_button: Button = $DetailModal/Card/Margin/VBox/Buttons/RestoreButton
@onready var detail_close_button: Button = $DetailModal/Card/Margin/VBox/Buttons/CloseButton

# Confirm Modal
@onready var confirm_modal: Control = $ConfirmModal
@onready var confirm_message: Label = $ConfirmModal/Card/Margin/VBox/MessageLabel
@onready var confirm_ok_button: Button = $ConfirmModal/Card/Margin/VBox/Buttons/ConfirmButton
@onready var confirm_cancel_button: Button = $ConfirmModal/Card/Margin/VBox/Buttons/CancelButton

var village_state: VillageState
var player_profile: Dictionary = {}
var building_nodes: Dictionary = {}
var selected_object_id: String = ""
var is_restoring_in_progress: bool = false
var layout_data: Dictionary = {}
var restore_quote: Dictionary = {}
var quote_sequence: int = 0
var last_restore_error: String = ""
var text_scale: float = 1.0
var scale_control: SpinBox
var base_font_sizes: Dictionary = {}
var error_label: Label

func _ready() -> void:
	menu_button.pressed.connect(func(): main_menu_requested.emit())
	_load_layout()
	_ensure_nodes()
	UiIcons.label($TopBar/Margin/HBox/TitleLabel, "castle", 20)
	UiIcons.label(wallet_label, "coins")
	UiIcons.button(enter_dungeon_button, "sword")
	UiIcons.button(detail_restore_button, "hammer")
	_connect_modal_signals()
	_configure_adaptive_layout()
	resized.connect(_adapt_layout)
	detail_modal.visibility_changed.connect(_sync_modal_input)
	confirm_modal.visibility_changed.connect(_sync_modal_input)

func _ensure_nodes() -> void:
	if background_rect == null and has_node("Background"):
		background_rect = $Background
	if background_rect != null and background_rect.texture == null:
		background_rect.texture = VillageBuildingNodeScript.load_texture_safe("res://assets/sprites/village/village_ground.png")
	if wallet_label == null and has_node("TopBar/Margin/HBox/WalletLabel"):
		wallet_label = $TopBar/Margin/HBox/WalletLabel
	if enter_dungeon_button == null and has_node("TopBar/Margin/HBox/EnterDungeonButton"):
		enter_dungeon_button = $TopBar/Margin/HBox/EnterDungeonButton
	if map_canvas == null and has_node("MapCanvas"):
		map_canvas = $MapCanvas
	if buildings_container == null and has_node("MapCanvas/Buildings"):
		buildings_container = $MapCanvas/Buildings
	if detail_modal == null and has_node("DetailModal"):
		detail_modal = $DetailModal
	if confirm_modal == null and has_node("ConfirmModal"):
		confirm_modal = $ConfirmModal

func _connect_modal_signals() -> void:
	if enter_dungeon_button != null and not enter_dungeon_button.pressed.is_connected(_on_enter_dungeon_pressed):
		enter_dungeon_button.pressed.connect(_on_enter_dungeon_pressed)
	if detail_close_button != null and not detail_close_button.pressed.is_connected(close_detail_modal):
		detail_close_button.pressed.connect(close_detail_modal)
	if detail_restore_button != null and not detail_restore_button.pressed.is_connected(_on_restore_pressed):
		detail_restore_button.pressed.connect(_on_restore_pressed)
	if confirm_ok_button != null and not confirm_ok_button.pressed.is_connected(_on_confirm_ok_pressed):
		confirm_ok_button.pressed.connect(_on_confirm_ok_pressed)
	if confirm_cancel_button != null and not confirm_cancel_button.pressed.is_connected(_on_confirm_cancel_pressed):
		confirm_cancel_button.pressed.connect(_on_confirm_cancel_pressed)

func _load_layout() -> void:
	var path = "res://assets/data/village_map_layout.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var text = file.get_as_text()
		var json = JSON.new()
		if json.parse(text) == OK and json.data is Dictionary:
			layout_data = json.data

func setup(state: VillageState, profile: Dictionary) -> void:
	_ensure_nodes()
	village_state = state
	player_profile = profile
	_build_or_update_map()
	set_text_scale(float(profile.get("settings", {}).get("ui_scale", 1.0)))
	refresh_view()
	_adapt_layout.call_deferred()

func _build_or_update_map() -> void:
	if buildings_container == null:
		return

	if layout_data.is_empty():
		_load_layout()

	var nodes_dict = layout_data.get("nodes", {})
	if nodes_dict.is_empty():
		return

	var anchor_offset = Vector2(128, 224)
	if layout_data.has("anchor_offset") and layout_data["anchor_offset"] is Array:
		var ao = layout_data["anchor_offset"]
		if ao.size() >= 2:
			anchor_offset = Vector2(float(ao[0]), float(ao[1]))

	# If buildings aren't instantiated yet, create and sort by base Y
	if building_nodes.is_empty():
		for child in buildings_container.get_children():
			child.queue_free()

		# Collect nodes and sort by Y coordinate ascending (isometric Y-sorting)
		var node_keys = nodes_dict.keys()
		node_keys.sort_custom(func(a, b):
			var ya = float(nodes_dict[a].get("y", 0))
			var yb = float(nodes_dict[b].get("y", 0))
			return ya < yb
		)

		for obj_id in node_keys:
			var cfg = nodes_dict[obj_id]
			var b_node = VillageBuildingNodeScript.new()
			b_node.name = obj_id
			b_node.setup_node(obj_id, cfg, anchor_offset)
			b_node.building_clicked.connect(_on_node_clicked)
			buildings_container.add_child(b_node)
			building_nodes[obj_id] = b_node

		_setup_focus_neighbors(nodes_dict)

func _setup_focus_neighbors(nodes_dict: Dictionary) -> void:
	for obj_id in building_nodes.keys():
		var b_node = building_nodes[obj_id]
		var cfg = nodes_dict.get(obj_id, {})
		var neighbors = cfg.get("neighbors", {})

		var left_id = neighbors.get("left", "")
		var right_id = neighbors.get("right", "")
		var top_id = neighbors.get("top", "")
		var bottom_id = neighbors.get("bottom", "")

		if building_nodes.has(left_id):
			b_node.focus_neighbor_left = b_node.get_path_to(building_nodes[left_id])
		if building_nodes.has(right_id):
			b_node.focus_neighbor_right = b_node.get_path_to(building_nodes[right_id])
		if building_nodes.has(top_id):
			b_node.focus_neighbor_top = b_node.get_path_to(building_nodes[top_id])
		if building_nodes.has(bottom_id):
			b_node.focus_neighbor_bottom = b_node.get_path_to(building_nodes[bottom_id])

func refresh_view() -> void:
	_ensure_nodes()
	var gold = int(player_profile.get("wallet_gold", 0))
	if wallet_label != null:
		wallet_label.clip_text = false
		wallet_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		wallet_label.text = tr("UI_WALLET_AMOUNT") % gold

	if village_state == null:
		return

	for obj_id in building_nodes.keys():
		var b_node = building_nodes[obj_id]
		var stage = village_state.get_stage(obj_id)
		b_node.update_stage(stage)

	if detail_modal != null and detail_modal.visible and selected_object_id != "":
		_populate_detail_modal(selected_object_id)

func _on_node_clicked(obj_id: String) -> void:
	if obj_id == "dungeon_entrance":
		_on_enter_dungeon_pressed()
		return

	selected_object_id = obj_id
	building_selected.emit(obj_id)
	open_detail_modal(obj_id)

func _on_enter_dungeon_pressed() -> void:
	enter_dungeon_requested.emit()

func open_detail_modal(obj_id: String) -> void:
	restore_quote.clear()
	if confirm_modal != null:
		confirm_modal.visible = false
	_ensure_nodes()
	selected_object_id = obj_id
	_populate_detail_modal(obj_id)
	if detail_modal != null:
		detail_modal.visible = true
		if detail_restore_button != null and not detail_restore_button.disabled:
			detail_restore_button.grab_focus()
		elif detail_close_button != null:
			detail_close_button.grab_focus()

func _populate_detail_modal(obj_id: String) -> void:
	if village_state == null:
		return

	var stage = village_state.get_stage(obj_id)
	var cost = village_state.get_next_cost(obj_id)
	var gold = int(player_profile.get("wallet_gold", 0))
	var prereq_met = village_state.is_prerequisite_met(obj_id)
	var can_buy = village_state.can_restore(obj_id, gold)

	if detail_title != null:
		detail_title.text = _get_obj_name(obj_id)
	if detail_stage != null:
		detail_stage.text = tr("UI_STAGE_LEVEL") % stage
	if detail_cur_desc != null:
		detail_cur_desc.text = tr("UI_CURRENT_STATE") + "\n" + _get_stage_desc(obj_id, stage)
	if detail_next_desc != null:
		if stage < 3:
			UiIcons.label(detail_next_desc, "")
			detail_next_desc.text = tr("UI_NEXT_STAGE") + "\n" + _get_stage_desc(obj_id, stage + 1)
			detail_next_desc.visible = true
		else:
			UiIcons.label(detail_next_desc, "check")
			detail_next_desc.text = tr("UI_RESTORED_MAX")
			detail_next_desc.visible = true

	if detail_cost != null:
		if stage >= 3:
			UiIcons.label(detail_cost, "check")
			detail_cost.text = tr("UI_RESTORED_MAX")
			detail_cost.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		else:
			UiIcons.label(detail_cost, "")
			detail_cost.text = tr("UI_STAGE_COST") % cost
			if gold >= cost:
				detail_cost.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
			else:
				detail_cost.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	if detail_prereq != null:
		if stage >= 3 or prereq_met:
			detail_prereq.visible = false
		else:
			detail_prereq.visible = true
			detail_prereq.text = _get_prereq_desc(obj_id)
			detail_prereq.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

	# Action buttons for unlocked features
	if detail_actions_box != null:
		for ch in detail_actions_box.get_children():
			ch.queue_free()

		if obj_id == "houses" and stage > 0:
			var story_btn = Button.new()
			story_btn.text = tr("UI_STORIES")
			story_btn.pressed.connect(func():
				close_detail_modal()
				story_view_requested.emit("story_houses_0%d" % stage)
			)
			detail_actions_box.add_child(story_btn)
		elif obj_id == "chronicler" and stage > 0:
			var chron_btn = Button.new()
			chron_btn.text = tr("UI_CHRONICLE")
			chron_btn.pressed.connect(func():
				close_detail_modal()
				chronicle_view_requested.emit()
			)
			detail_actions_box.add_child(chron_btn)
		elif obj_id == "marketplace" and stage > 0:
			var cosm_btn = Button.new()
			cosm_btn.text = tr("UI_COSMETICS")
			cosm_btn.pressed.connect(func():
				close_detail_modal()
				cosmetics_view_requested.emit()
			)
			detail_actions_box.add_child(cosm_btn)

	for button in detail_actions_box.get_children():
		button.add_theme_font_size_override("font_size", int(14 * text_scale))

	# Restore button state
	if detail_restore_button != null:
		if stage >= 3:
			UiIcons.button(detail_restore_button, "check")
			detail_restore_button.text = tr("UI_RESTORED_MAX")
			detail_restore_button.disabled = true
		elif not prereq_met:
			UiIcons.button(detail_restore_button, "")
			detail_restore_button.text = tr("UI_UNAVAILABLE")
			detail_restore_button.disabled = true
		elif gold < cost:
			UiIcons.button(detail_restore_button, "")
			detail_restore_button.text = tr("UI_NOT_ENOUGH_GOLD") % cost
			detail_restore_button.disabled = true
		else:
			UiIcons.button(detail_restore_button, "hammer")
			detail_restore_button.text = tr("UI_RESTORE_BUTTON") % cost
			detail_restore_button.disabled = false

func close_detail_modal() -> void:
	restore_quote.clear()
	if confirm_modal != null:
		confirm_modal.visible = false
	if detail_modal != null:
		detail_modal.visible = false

	# Restore focus to selected building node
	if building_nodes.has(selected_object_id):
		var b_node = building_nodes[selected_object_id] as Control
		if b_node != null and b_node.is_inside_tree():
			b_node.grab_focus()

func _on_restore_pressed() -> void:
	# Opens confirmation modal without spending gold
	if village_state == null or selected_object_id == "":
		return

	var stage = village_state.get_stage(selected_object_id)
	var cost = village_state.get_next_cost(selected_object_id)
	var gold = int(player_profile.get("wallet_gold", 0))

	if stage >= 3 or not village_state.can_restore(selected_object_id, gold):
		return

	quote_sequence += 1
	restore_quote = {"token": quote_sequence, "object_id": selected_object_id, "stage": stage, "revision": int(village_state.revisions.get(selected_object_id, 0)), "price": cost}
	_set_restore_error("")
	var name_str = _get_obj_name(selected_object_id)
	if confirm_message != null:
		confirm_message.text = tr("UI_RESTORE_CONFIRM_MSG") % [name_str, stage + 1, cost]

	if confirm_modal != null:
		confirm_modal.visible = true
		# Hidden wrapped labels recalculate their minimum height when first shown.
		# Resize again after the container has processed the current message.
		_adapt_layout.call_deferred()
		if confirm_ok_button != null:
			confirm_ok_button.grab_focus()

func _on_confirm_cancel_pressed() -> void:
	restore_quote.clear()
	if confirm_modal != null:
		confirm_modal.visible = false
	if detail_restore_button != null and not detail_restore_button.disabled:
		detail_restore_button.grab_focus()

func _on_confirm_ok_pressed() -> void:
	if confirm_modal == null or not confirm_modal.visible or restore_quote.is_empty():
		return
	if is_restoring_in_progress:
		return

	if village_state == null or selected_object_id == "":
		return

	var quote = restore_quote.duplicate(true)
	restore_quote.clear()
	confirm_modal.visible = false
	if str(quote.object_id) != selected_object_id:
		return
	is_restoring_in_progress = true

	var obj_id = str(quote.object_id)
	var cur_stage = int(quote.stage)
	var gold = int(player_profile.get("wallet_gold", 0))

	if cur_stage >= 3 or not village_state.can_restore(obj_id, gold):
		is_restoring_in_progress = false
		if confirm_modal != null:
			confirm_modal.visible = false
		return

	# Candidate execution
	var candidate_state = VillageState.new(village_state.balance)
	candidate_state.deserialize(village_state.serialize())
	var candidate_profile = player_profile.duplicate(true)

	var res = VillageCommands.execute_restore(candidate_state, candidate_profile, obj_id, cur_stage, int(quote.revision), int(quote.price))
	if not res.get("success", false):
		is_restoring_in_progress = false
		_set_restore_error("UI_RESTORE_STALE")
		return

	# Atomic disk save verification
	var save_success = false
	var main_loop = Engine.get_main_loop()
	if main_loop != null and "root" in main_loop and main_loop.root != null:
		var gm = main_loop.root.get_node_or_null("GameManager")
		if gm != null and gm.save_store != null:
			var env = SaveCodec.encode_envelope(candidate_profile, {})
			save_success = gm.save_store.save_envelope(env)

	if not save_success:
		_set_restore_error("UI_SAVE_FAILED")
		# Save failed on disk: leave live state untouched
		is_restoring_in_progress = false
		if confirm_modal != null:
			confirm_modal.visible = false
		return

	# ONLY ON SUCCESSFUL SAVE: publish candidate to live state
	village_state.deserialize(candidate_state.serialize())
	player_profile["wallet_gold"] = candidate_profile["wallet_gold"]
	player_profile["village_object_stages"] = candidate_profile["village_object_stages"].duplicate(true)
	player_profile["village_object_revisions"] = candidate_profile["village_object_revisions"].duplicate(true)

	if main_loop != null and "root" in main_loop and main_loop.root != null:
		var gm = main_loop.root.get_node_or_null("GameManager")
		if gm != null and gm.player_profile != null:
			gm.player_profile["wallet_gold"] = player_profile["wallet_gold"]
			gm.player_profile["village_object_stages"] = player_profile["village_object_stages"]
			gm.player_profile["village_object_revisions"] = player_profile["village_object_revisions"]

	SoundManager.play_anvil()

	if confirm_modal != null:
		confirm_modal.visible = false

	refresh_view()
	is_restoring_in_progress = false

	if detail_restore_button != null and not detail_restore_button.disabled:
		detail_restore_button.grab_focus()
	elif detail_close_button != null:
		detail_close_button.grab_focus()

func _set_restore_error(key: String) -> void:
	last_restore_error = key
	if error_label == null:
		error_label = Label.new()
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		error_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
		detail_cur_desc.get_parent().add_child(error_label)
	error_label.add_theme_font_size_override("font_size", int(14 * text_scale))
	error_label.get_parent().move_child(error_label, 0)
	if not key.is_empty():
		(error_label.get_parent().get_parent() as ScrollContainer).scroll_vertical = 0
	error_label.text = tr(key) if not key.is_empty() else ""
	UiIcons.label(error_label, "check" if key == "UI_RESTORE_SUCCESS" else ("close" if key == "UI_RESTORE_FAIL" else ""))
	error_label.visible = not key.is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		if confirm_modal != null and confirm_modal.visible:
			_on_confirm_cancel_pressed()
			get_viewport().set_input_as_handled()
		elif detail_modal != null and detail_modal.visible:
			close_detail_modal()
			get_viewport().set_input_as_handled()
		else:
			get_viewport().set_input_as_handled()
			main_menu_requested.emit()

func _get_obj_name(obj_id: String) -> String:
	return tr("UI_DUNGEON_ENTRANCE" if obj_id == "dungeon_entrance" else "VILLAGE_" + obj_id.to_upper())

func _get_prereq_desc(obj_id: String) -> String:
	var lines: Array[String] = []
	for required in village_state.balance.get_village_object_prerequisites(obj_id):
		lines.append(tr("UI_PREREQ_REQUIRED") % [_get_obj_name(str(required.id)), int(required.stage)])
	return "\n".join(lines)

func _get_stage_desc(obj_id: String, stage: int) -> String:
	return tr("VILLAGE_%s_STAGE_%d" % [obj_id.to_upper(), stage])

func _configure_adaptive_layout() -> void:
	# Keep the ground and buildings in the same scaled coordinate system.
	background_rect.reparent(map_canvas, false)
	background_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_canvas.move_child(background_rect, 0)
	var title = get_node("TopBar/Margin/HBox/TitleLabel")
	title.text = "UI_VILLAGE_TITLE"
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for path in ["DetailModal/Card/Margin/VBox/Header", "DetailModal/Card/Margin/VBox/Buttons", "ConfirmModal/Card/Margin/VBox/Buttons"]:
		var row = get_node(path)
		var column = VBoxContainer.new()
		column.name = row.name + "Adaptive"
		row.get_parent().add_child(column)
		row.get_parent().move_child(column, row.get_index())
		for child in row.get_children():
			child.reparent(column)
		row.queue_free()
	for label in [detail_title, detail_stage, detail_cost, confirm_message, get_node("ConfirmModal/Card/Margin/VBox/TitleLabel")]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A hidden wrapped label can cache its minimum height at a tiny width.
	# Keep that minimum out of the card's constraints, including on first open.
	var confirmation_scroll = ScrollContainer.new()
	confirmation_scroll.name = "MessageScroll"
	confirmation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	confirmation_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var message_parent = confirm_message.get_parent()
	message_parent.add_child(confirmation_scroll)
	message_parent.move_child(confirmation_scroll, confirm_message.get_index())
	confirm_message.reparent(confirmation_scroll)
	confirm_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_control = SpinBox.new()
	scale_control.min_value = 100
	scale_control.max_value = 300
	scale_control.step = 10
	scale_control.suffix = "%"
	scale_control.tooltip_text = tr("UI_TEXT_SCALE")
	get_node("TopBar/Margin/HBox").add_child(scale_control)
	scale_control.value_changed.connect(func(value):
		set_text_scale(value / 100.0)
		if player_profile.has("settings"):
			player_profile.settings.ui_scale = text_scale
			GameManager.player_profile.settings.ui_scale = text_scale
			var active = GameManager.build_active_run() if GameManager.terminal_outcome == RunMode.Outcome.NONE else {}
			if not GameManager.save_store.save_envelope(SaveCodec.encode_envelope(GameManager.player_profile, active)):
				_set_restore_error("UI_SAVE_FAILED")
	)

func set_text_scale(value: float) -> void:
	text_scale = clampf(value, 1.0, 3.0)
	if scale_control != null:
		scale_control.set_value_no_signal(text_scale * 100.0)
	for control in find_children("*", "Control", true, false):
		if control is Label or control is Button:
			if not base_font_sizes.has(control):
				base_font_sizes[control] = maxi(14, control.get_theme_font_size("font_size"))
			control.add_theme_font_size_override("font_size", int(base_font_sizes[control] * text_scale))
	_adapt_layout.call_deferred()

func _adapt_layout() -> void:
	if not is_node_ready():
		return
	var font_size = wallet_label.get_theme_font_size("font_size")
	wallet_label.custom_minimum_size.x = wallet_label.get_theme_font("font").get_string_size(wallet_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + wallet_label.get_theme_stylebox("normal").get_minimum_size().x + 12
	var top_bar = get_node("TopBar")
	top_bar.size = Vector2(size.x, top_bar.get_combined_minimum_size().y)
	var top = top_bar.size.y + 12.0
	var fit = minf(size.x / 1280.0, maxf(1, size.y - top) / 800.0)
	map_canvas.set_anchors_preset(Control.PRESET_TOP_LEFT)
	map_canvas.size = Vector2(1280, 800)
	map_canvas.scale = Vector2.ONE * fit
	map_canvas.position = Vector2((size.x - 1280 * fit) / 2, top + (size.y - top - 800 * fit) / 2)
	for modal in [detail_modal, confirm_modal]:
		var card = modal.get_node("Card")
		card.custom_minimum_size = Vector2.ZERO
		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var width = minf(860.0 if text_scale > 1.0 else 560.0, size.x - 32.0)
		card.size = Vector2(width, minf(620.0 * text_scale, size.y - 32.0))
		card.position = (size - card.size) / 2.0
		for button in modal.find_children("*", "Button", true, false):
			button.custom_minimum_size = Vector2(0, 44 * text_scale)

func _sync_modal_input() -> void:
	var blocked = detail_modal.visible or confirm_modal.visible
	for button in building_nodes.values():
		button.disabled = blocked
	enter_dungeon_button.disabled = blocked
	menu_button.disabled = blocked
	if scale_control != null:
		scale_control.editable = not blocked

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var modal = confirm_modal if confirm_modal.visible else (detail_modal if detail_modal.visible else null)
	if modal == null:
		return
	var scroll_delta = 0
	if event.is_action_pressed("ui_page_down"):
		scroll_delta = 120
	elif event.is_action_pressed("ui_page_up"):
		scroll_delta = -120
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y and absf(event.axis_value) > 0.3:
		scroll_delta = int(event.axis_value * 80)
	if scroll_delta != 0:
		var scroll = confirm_message.get_parent() as ScrollContainer if confirm_modal.visible else detail_cur_desc.get_parent().get_parent() as ScrollContainer
		scroll.scroll_vertical += scroll_delta
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if confirm_modal.visible:
			_on_confirm_cancel_pressed()
		else:
			close_detail_modal()
		get_viewport().set_input_as_handled()
		return
	var direction = 0
	if event.is_action_pressed("ui_focus_next", true, true) or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		direction = 1
	elif event.is_action_pressed("ui_focus_prev", true, true) or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		direction = -1
	if direction == 0:
		return
	var buttons = []
	for button in modal.find_children("*", "BaseButton", true, false):
		if button.is_visible_in_tree() and not button.disabled and not button.is_queued_for_deletion():
			buttons.append(button)
	if not buttons.is_empty():
		var index = buttons.find(get_viewport().gui_get_focus_owner())
		buttons[posmod(index + direction, buttons.size())].grab_focus()
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh_view()
