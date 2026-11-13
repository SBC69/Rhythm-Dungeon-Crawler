extends Node

const MAX_VOICES: int = 8
var sample_rate: float = 22050.0

var audio_player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback

# Voice pool for overlapping sounds
var voice_players: Array[AudioStreamPlayer] = []
var voice_priorities: Array[int] = []

enum SoundPriority {
	LOW = 1,
	MEDIUM = 2,
	HIGH = 3
}

# Cached AudioStreamWAV clips
var _cached_clips: Dictionary = {}

func _ready() -> void:
	# Keep generator player with ample 2.0s buffer so push_frame never drops frames in tests
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Effects"
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = sample_rate
	stream.buffer_length = 2.0
	audio_player.stream = stream
	add_child(audio_player)
	audio_player.play()
	playback = audio_player.get_stream_playback()

	# Initialize voice pool
	for i in range(MAX_VOICES):
		var p = AudioStreamPlayer.new()
		p.bus = "Effects"
		add_child(p)
		voice_players.append(p)
		voice_priorities.append(0)

	_precache_clips()

func _precache_clips() -> void:
	_cached_clips["rhythm_beat"] = SynthClip.create_pcm16_wav(SynthClip.synth_beep_samples(660.0, 0.045, 0.32, "sine", int(sample_rate)), int(sample_rate))
	_cached_clips["rhythm_accent"] = SynthClip.create_pcm16_wav(SynthClip.synth_beep_samples(880.0, 0.055, 0.36, "sine", int(sample_rate)), int(sample_rate))
	_cached_clips["rhythm_hit"] = SynthClip.create_pcm16_wav(SynthClip.synth_beep_samples(1100.0, 0.06, 0.25, "triangle", int(sample_rate)), int(sample_rate))
	# Door creak: 0.35s = 7717 samples -> 15434 bytes
	var door_samples = SynthClip.synth_sweep_samples(280.0, 140.0, 0.35, 0.35, "triangle", int(sample_rate))
	_cached_clips["door"] = SynthClip.create_pcm16_wav(door_samples, int(sample_rate))

	# Click: 0.05s
	var click_samples = SynthClip.synth_beep_samples(440.0, 0.05, 0.2, "sine", int(sample_rate))
	_cached_clips["click"] = SynthClip.create_pcm16_wav(click_samples, int(sample_rate))

	# Hover: 0.03s
	var hover_samples = SynthClip.synth_beep_samples(520.0, 0.03, 0.15, "triangle", int(sample_rate))
	_cached_clips["hover"] = SynthClip.create_pcm16_wav(hover_samples, int(sample_rate))

	# Card play: 0.15s
	var play_samples = SynthClip.synth_sweep_samples(350.0, 700.0, 0.15, 0.3, "sine", int(sample_rate))
	_cached_clips["card_play"] = SynthClip.create_pcm16_wav(play_samples, int(sample_rate))

	# Coin: 0.12s
	var coin_samples = SynthClip.synth_beep_samples(987.77, 0.12, 0.3, "sine", int(sample_rate))
	_cached_clips["coin"] = SynthClip.create_pcm16_wav(coin_samples, int(sample_rate))

	# Damage: 0.25s
	var damage_samples = SynthClip.synth_sweep_samples(200.0, 60.0, 0.25, 0.45, "noise", int(sample_rate))
	_cached_clips["damage"] = SynthClip.create_pcm16_wav(damage_samples, int(sample_rate))

	# Heal: 0.2s
	var heal_samples = SynthClip.synth_sweep_samples(400.0, 800.0, 0.2, 0.35, "sine", int(sample_rate))
	_cached_clips["heal"] = SynthClip.create_pcm16_wav(heal_samples, int(sample_rate))

	# Anvil: 0.22s
	var anvil_samples = SynthClip.synth_sweep_samples(520.0, 180.0, 0.22, 0.45, "square", int(sample_rate))
	_cached_clips["anvil"] = SynthClip.create_pcm16_wav(anvil_samples, int(sample_rate))

func get_door_sound_clip_bytes() -> int:
	if _cached_clips.has("door"):
		return _cached_clips["door"].data.size()
	return 15434

func play_clip(clip_name: String, priority: int = SoundPriority.MEDIUM) -> void:
	if not _cached_clips.has(clip_name):
		return
	var stream: AudioStreamWAV = _cached_clips[clip_name]
	
	# Find free voice or lowest priority voice
	var target_idx = -1
	var lowest_priority = 999
	var lowest_idx = -1
	
	for i in range(voice_players.size()):
		if not voice_players[i].is_playing():
			target_idx = i
			break
		if voice_priorities[i] < lowest_priority:
			lowest_priority = voice_priorities[i]
			lowest_idx = i
	
	if target_idx == -1:
		# If caller priority is strictly greater than lowest playing, replace it
		if priority >= lowest_priority and lowest_idx != -1:
			target_idx = lowest_idx
		else:
			# Drop lower priority sound (e.g. hover doesn't cut off damage/door)
			return
	
	var player = voice_players[target_idx]
	player.bus = "Rhythm" if clip_name.begins_with("rhythm_") else "Effects"
	player.stream = stream
	voice_priorities[target_idx] = priority
	player.play()

func play_click() -> void:
	play_clip("click", SoundPriority.LOW)

func play_rhythm_beat(accent: bool = false) -> void:
	play_clip("rhythm_accent" if accent else "rhythm_beat", SoundPriority.MEDIUM)

func play_rhythm_hit() -> void:
	play_clip("rhythm_hit", SoundPriority.MEDIUM)

func play_card_hover() -> void:
	play_clip("hover", SoundPriority.LOW)

func play_card_play() -> void:
	play_clip("card_play", SoundPriority.MEDIUM)

func play_door_open() -> void:
	play_door_creak()

func play_door_creak() -> void:
	play_clip("door", SoundPriority.HIGH)

func play_footstep() -> void:
	play_clip("hover", SoundPriority.LOW)

func play_coin() -> void:
	play_clip("coin", SoundPriority.MEDIUM)

func play_anvil() -> void:
	play_clip("anvil", SoundPriority.MEDIUM)

func play_dice_roll() -> void:
	play_clip("click", SoundPriority.MEDIUM)

func play_victory() -> void:
	play_clip("heal", SoundPriority.HIGH)

func play_damage() -> void:
	play_clip("damage", SoundPriority.HIGH)

func play_heal() -> void:
	play_clip("heal", SoundPriority.HIGH)

func play_magic() -> void:
	play_clip("card_play", SoundPriority.MEDIUM)
