# tests/cases/test_audio.gd
class_name TestAudio
extends RefCounted

static func register_tests(registry: Dictionary) -> void:
	registry["T-C06"] = {
		"fn": Callable(TestAudio, "test_c06_audio_buffer_overflow"),
		"expected_failure": false,
		"desc": "C06: Audio buffer overflows and drops frames during long sound synthesis"
	}

static func test_c06_audio_buffer_overflow(fix: GameFixture) -> void:
	var sm = fix.root.get_node("/root/SoundManager")
	if sm == null or sm.playback == null:
		fix.assert_true(false, "SoundManager or playback not initialized")
		return
	
	# Door creak sound attempts to push 0.35s of 22050Hz audio = 7717 frames
	var duration = 0.35
	var sample_rate = sm.sample_rate
	var total_frames = int(duration * sample_rate) # 7717 frames
	
	# In baseline, buffer capacity is 0.1s (around 2205 to 4095 frames in Godot)
	# Pushing 7717 frames all at once in a single call causes push_frame to return false
	# and drop thousands of frames!
	var available = sm.playback.get_frames_available()
	var dropped_count = 0
	
	for i in range(total_frames):
		var pushed = sm.playback.push_frame(Vector2.ZERO)
		if not pushed:
			dropped_count += 1
	
	# TARGET ASSERTION (Target requirement for M17):
	# Audio playback or audio clips should not drop frames during synthesis
	fix.assert_eq(dropped_count, 0, "TARGET: Sound synthesis should not drop audio frames (dropped: %d / %d)" % [dropped_count, total_frames])
