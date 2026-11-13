extends Control

signal door_requested(door_index: int)
signal door_selected(door_index: int)
signal door_transition_completed(door_index: int, token: int)

const DUNGEON_ART: Dictionary = {
	"crypts": "res://assets/sprites/dungeon/",
	"ash_forges": "res://assets/sprites/dungeon/ash_forges/",
	"drowned_temple": "res://assets/sprites/dungeon/drowned_temple/",
	"crystal_mines": "res://assets/sprites/dungeon/crystal_mines/",
	"abyss_rift": "res://assets/sprites/dungeon/abyss_rift/",
}

@onready var corridor_rect: TextureRect = $CorridorBackground
@onready var doors_container: HBoxContainer = $DoorsContainer
@onready var door_left = $DoorsContainer/DoorLeft
@onready var door_center = $DoorsContainer/DoorCenter
@onready var door_right = $DoorsContainer/DoorRight
@onready var hero_hands: TextureRect = $HeroHands
@onready var room_announce_panel: PanelContainer = $RoomAnnouncePanel
@onready var announce_label: Label = $RoomAnnouncePanel/AnnounceLabel
@onready var transition_fade: ColorRect = $TransitionFade

var idle_time: float = 0.0
var hands_base_pos_y: float = 0.0
var hands_base_pos_x: float = 0.0
var is_transitioning: bool = false
var has_selected_door: bool = false
var accepted_token: int = -1
var accepted_generation: int = -1
var animation_epoch: int = 0
var visual_tweens: Array[Tween] = []
var visual_dungeon_id: String = ""

func _ready() -> void:
	hands_base_pos_y = hero_hands.position.y
	hands_base_pos_x = hero_hands.position.x
	door_left.door_requested.connect(_on_door_requested)
	door_center.door_requested.connect(_on_door_requested)
	door_right.door_requested.connect(_on_door_requested)
	door_left.door_opened.connect(_on_door_opened)
	door_center.door_opened.connect(_on_door_opened)
	door_right.door_opened.connect(_on_door_opened)
	reset_view()

func _load_art(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	# Keep the existing raw-PNG fallback when the import cache is rebuilding.
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	return null

func _update_dungeon_art() -> void:
	var dungeon_id := GameManager.current_dungeon_id
	if not DUNGEON_ART.has(dungeon_id):
		dungeon_id = "crypts"
	if visual_dungeon_id == dungeon_id:
		return
	var folder: String = DUNGEON_ART[dungeon_id]
	var corridor := _load_art(folder + "corridor.png")
	var door := _load_art(folder + "door.png")
	if corridor == null or door == null:
		return
	corridor_rect.texture = corridor
	for entry in [door_left, door_center, door_right]:
		entry.set_door_art(door)
	visual_dungeon_id = dungeon_id

func lock_all_doors() -> void:
	if door_left != null:
		door_left.set_active(false)
	if door_center != null:
		door_center.set_active(false)
	if door_right != null:
		door_right.set_active(false)

func _on_door_requested(idx: int) -> void:
	if is_transitioning or has_selected_door:
		return
	door_requested.emit(idx)

func begin_accepted_transition(idx: int, token: int, generation: int) -> void:
	has_selected_door = true
	accepted_token = token
	accepted_generation = generation
	lock_all_doors()
	[door_left, door_center, door_right][idx - 1].animate_accepted_open()

func _transition_valid(epoch: int, token: int, generation: int) -> bool:
	return is_inside_tree() and visible and animation_epoch == epoch and accepted_token == token and GameManager.run_generation == generation

func _process(delta: float) -> void:
	if is_transitioning:
		return

	# Subtle breathing / idle bobbing for hero hands
	idle_time += delta
	var bob = sin(idle_time * 2.5) * 4.0
	hero_hands.position.y = hands_base_pos_y + bob

	# Subtle magical hand pulse
	var pulse = 0.95 + 0.12 * sin(idle_time * 4.0)
	hero_hands.modulate = Color(pulse, pulse, 1.05)

func reset_view() -> void:
	_update_dungeon_art()
	for tween in visual_tweens:
		if tween.is_valid():
			tween.kill()
	visual_tweens.clear()
	animation_epoch += 1
	accepted_token = -1
	accepted_generation = -1
	is_transitioning = false
	has_selected_door = false
	corridor_rect.scale = Vector2.ONE
	corridor_rect.position = Vector2.ZERO
	hero_hands.position = Vector2(hands_base_pos_x, hands_base_pos_y)
	doors_container.scale = Vector2.ONE
	doors_container.position = Vector2(260, 220)
	doors_container.modulate = Color(1, 1, 1, 1)
	transition_fade.modulate.a = 0.0

	var is_boss_room = (GameManager.current_room == GameManager.MAX_ROOMS_PER_FLOOR)

	if is_boss_room:
		door_left.visible = false
		door_right.visible = false
		door_center.visible = true
		door_center.set_door_title(tr("DOOR_BOSS"))
		door_center.set_active(true)
		door_center.reset_door()
		door_center.modulate = Color(1.2, 0.45, 0.45)
		door_center.grab_focus()
	else:
		door_left.visible = true
		door_center.visible = true
		door_right.visible = true
		door_left.set_door_title(tr("DOOR_LEFT"))
		door_center.set_door_title(tr("DOOR_CENTER"))
		door_right.set_door_title(tr("DOOR_RIGHT"))
		door_left.set_active(true)
		door_center.set_active(true)
		door_right.set_active(true)
		door_left.reset_door()
		door_center.reset_door()
		door_right.reset_door()
		door_left.modulate = Color(1, 1, 1)
		door_center.modulate = Color(1, 1, 1)
		door_right.modulate = Color(1, 1, 1)
		door_center.grab_focus()

func show_combat_failure(damage: int) -> void:
	announce_label.text = tr("UI_RHYTHM_DEFEAT") % damage
	announce_label.modulate = Color(1.0, 0.55, 0.45)
	room_announce_panel.modulate.a = 1.0
	var notice := create_tween()
	visual_tweens.append(notice)
	notice.tween_interval(2.0)
	notice.tween_property(room_announce_panel, "modulate:a", 0.0, 0.25)

func _on_door_opened(idx: int) -> void:
	lock_all_doors()
	play_walk_into_door(idx, accepted_token)

func play_walk_into_door(door_idx: int, token: int = 0) -> void:
	var epoch = animation_epoch
	var generation = accepted_generation
	if not _transition_valid(epoch, token, generation):
		return
	is_transitioning = true
	lock_all_doors()

	# Fade out non-selected doors
	var fade_tween = create_tween()
	visual_tweens.append(fade_tween)
	for d in [door_left, door_center, door_right]:
		if d.door_index != door_idx:
			fade_tween.parallel().tween_property(d, "modulate:a", 0.0, 0.2)

	# Target focus offset depending on left/center/right
	var target_shift_x = 0.0
	if door_idx == 1:
		target_shift_x = 120.0 # Shift view right so left door centers
	elif door_idx == 3:
		target_shift_x = -120.0 # Shift view left so right door centers

	# STEP 1: Left footstep, camera plunges forward
	SoundManager.play_footstep()
	var step1 = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	visual_tweens.append(step1)
	step1.tween_property(corridor_rect, "scale", Vector2(1.18, 1.18), 0.22)
	step1.parallel().tween_property(corridor_rect, "position:x", target_shift_x * 0.4, 0.22)
	step1.parallel().tween_property(doors_container, "scale", Vector2(1.18, 1.18), 0.22)
	step1.parallel().tween_property(hero_hands, "position:y", hands_base_pos_y + 16.0, 0.12)
	step1.parallel().tween_property(hero_hands, "position:x", hands_base_pos_x - 14.0, 0.12)
	await get_tree().create_timer(0.22).timeout
	if not _transition_valid(epoch, token, generation):
		return

	# STEP 2: Right footstep, deeper into the room threshold
	SoundManager.play_footstep()
	var step2 = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	visual_tweens.append(step2)
	step2.tween_property(corridor_rect, "scale", Vector2(1.36, 1.36), 0.24)
	step2.parallel().tween_property(corridor_rect, "position:x", target_shift_x, 0.24)
	step2.parallel().tween_property(doors_container, "scale", Vector2(1.36, 1.36), 0.24)
	step2.parallel().tween_property(hero_hands, "position:y", hands_base_pos_y - 12.0, 0.14)
	step2.parallel().tween_property(hero_hands, "position:x", hands_base_pos_x + 20.0, 0.14)
	# Fade into dark chamber
	step2.parallel().tween_property(transition_fade, "modulate:a", 1.0, 0.22)
	await get_tree().create_timer(0.24).timeout
	if not _transition_valid(epoch, token, generation):
		return

	# Small pause for dramatic threshold entry
	await get_tree().create_timer(0.08).timeout
	if not _transition_valid(epoch, token, generation):
		return

	emit_signal("door_transition_completed", door_idx, token)


func play_enter_next_room() -> void:
	reset_view()
	var entry_epoch = animation_epoch
	is_transitioning = true
	transition_fade.modulate.a = 1.0

	# Doors initially hidden while walking
	doors_container.modulate.a = 0.0
	corridor_rect.scale = Vector2(1.15, 1.15)

	# Fade in from transition with footstep
	SoundManager.play_footstep()
	var tween_walk = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	visual_tweens.append(tween_walk)
	tween_walk.tween_property(transition_fade, "modulate:a", 0.0, 0.28)
	tween_walk.parallel().tween_property(corridor_rect, "scale", Vector2(1.0, 1.0), 0.35)
	tween_walk.parallel().tween_property(hero_hands, "position:y", hands_base_pos_y, 0.3)

	await get_tree().create_timer(0.18).timeout
	if entry_epoch != animation_epoch or not visible:
		return
	# Second step into position
	SoundManager.play_footstep()

	# Doors materialize in the new hallway
	var doors_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	visual_tweens.append(doors_tween)
	doors_tween.tween_property(doors_container, "modulate:a", 1.0, 0.28)
	doors_tween.parallel().tween_property(doors_container, "scale", Vector2(1.0, 1.0), 0.28)

	# Room Announce Banner
	var is_boss = (GameManager.current_room == GameManager.MAX_ROOMS_PER_FLOOR)
	if is_boss:
		announce_label.text = tr("UI_BOSS_ANNOUNCE") % GameManager.current_floor
		announce_label.modulate = Color(1.0, 0.35, 0.35)
	else:
		announce_label.text = tr("UI_ROOM_ANNOUNCE") % [GameManager.current_room, GameManager.MAX_ROOMS_PER_FLOOR]
		announce_label.modulate = Color(1.0, 0.88, 0.4)

	room_announce_panel.modulate.a = 0.0
	room_announce_panel.position.y = 160.0
	var banner_tween = create_tween()
	visual_tweens.append(banner_tween)
	banner_tween.tween_property(room_announce_panel, "modulate:a", 1.0, 0.2)
	banner_tween.parallel().tween_property(room_announce_panel, "position:y", 135.0, 0.35)
	banner_tween.tween_interval(0.6)
	banner_tween.tween_property(room_announce_panel, "modulate:a", 0.0, 0.3)

	await get_tree().create_timer(0.28).timeout
	if entry_epoch != animation_epoch or not visible:
		return
	is_transitioning = false
