# scripts/audio/synth_clip.gd
class_name SynthClip
extends RefCounted

static func create_pcm16_wav(samples: PackedFloat32Array, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	
	var byte_count = samples.size() * 2
	var byte_array = PackedByteArray()
	byte_array.resize(byte_count)
	
	for i in range(samples.size()):
		var clamped = clampf(samples[i], -1.0, 1.0)
		var s16 = int(round(clamped * 32767.0))
		if s16 < -32768:
			s16 = -32768
		elif s16 > 32767:
			s16 = 32767
		if s16 < 0:
			s16 += 65536
		byte_array[i * 2] = s16 & 0xFF
		byte_array[i * 2 + 1] = (s16 >> 8) & 0xFF
	
	wav.data = byte_array
	return wav

static func synth_beep_samples(freq: float, duration: float, volume: float = 0.3, wave_type: String = "sine", sample_rate: int = 22050) -> PackedFloat32Array:
	var count = int(duration * sample_rate)
	var samples = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t = float(i) / float(sample_rate)
		var env = 1.0 - (float(i) / float(count))
		var s: float = 0.0
		if wave_type == "sine":
			s = sin(2.0 * PI * freq * t)
		elif wave_type == "triangle":
			s = 2.0 * abs(2.0 * (t * freq - floor(t * freq + 0.5))) - 1.0
		elif wave_type == "square":
			s = 1.0 if sin(2.0 * PI * freq * t) > 0.0 else -1.0
		elif wave_type == "noise":
			s = randf_range(-1.0, 1.0)
		samples[i] = s * volume * env
	return samples

static func synth_sweep_samples(start_freq: float, end_freq: float, duration: float, volume: float = 0.3, wave_type: String = "sine", sample_rate: int = 22050) -> PackedFloat32Array:
	var count = int(duration * sample_rate)
	var samples = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var progress = float(i) / float(count)
		var freq = lerp(start_freq, end_freq, progress)
		var t = float(i) / float(sample_rate)
		var env = 1.0 - progress
		var s: float = 0.0
		if wave_type == "noise":
			s = randf_range(-1.0, 1.0) * 0.5 + sin(2.0 * PI * freq * t) * 0.5
		elif wave_type == "triangle":
			s = 2.0 * abs(2.0 * (t * freq - floor(t * freq + 0.5))) - 1.0
		elif wave_type == "square":
			s = 1.0 if sin(2.0 * PI * freq * t) > 0.0 else -1.0
		else:
			s = sin(2.0 * PI * freq * t)
		samples[i] = s * volume * env
	return samples
