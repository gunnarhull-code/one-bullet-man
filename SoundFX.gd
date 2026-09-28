class_name SoundFX
extends Node

# All sounds are generated procedurally at startup (short noise/tone bursts
# with an amplitude envelope) so the project needs no audio assets.

const SAMPLE_RATE := 22050
const POOL_SIZE := 16

var _clips: Dictionary = {}
var _pool: Array = []
var _pool_index: int = 0


func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_build_clips()


func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _clips.has(sound_name):
		return
	var player: AudioStreamPlayer = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	player.stream = _clips[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(0.96, 1.04)
	player.play()


func _build_clips() -> void:
	_clips["gunshot"] = _to_wav(_env_noise(0.11, 20.0))
	_clips["melee_swing"] = _to_wav(_env_sweep_noise(0.09, 1000.0, 300.0, 16.0))
	_clips["throw"] = _to_wav(_env_sweep_noise(0.15, 650.0, 220.0, 9.0))
	_clips["impact"] = _to_wav(_env_thud(0.09, 150.0, 22.0))
	_clips["stagger"] = _to_wav(_env_thud(0.14, 190.0, 13.0))
	_clips["knockdown"] = _to_wav(_env_thud(0.34, 65.0, 6.0))
	_clips["dash"] = _to_wav(_env_sweep_noise(0.13, 1500.0, 2600.0, 17.0))
	_clips["pickup"] = _to_wav(_env_blip(0.16, 500.0, 760.0))
	_clips["enemy_death"] = _to_wav(_env_sweep_noise(0.2, 480.0, 80.0, 8.0))
	_clips["player_death"] = _to_wav(_env_tone_sweep(1.0, 240.0, 50.0))
	_clips["cripple"] = _to_wav(_env_thud(0.22, 210.0, 8.0))
	_clips["stun"] = _to_wav(_env_tone_sweep(0.28, 620.0, 340.0))
	_clips["grapple_grab"] = _to_wav(_env_thud(0.16, 120.0, 12.0))
	_clips["chokehold_start"] = _to_wav(_env_tone_sweep(0.3, 180.0, 90.0))
	_clips["chokehold_kill"] = _to_wav(_env_tone_sweep(0.6, 160.0, 30.0))
	_clips["grapple_break"] = _to_wav(_env_sweep_noise(0.12, 800.0, 300.0, 15.0))
	_clips["grapple_interrupted"] = _to_wav(_env_thud(0.18, 140.0, 10.0))
	_clips["dodge_punish"] = _to_wav(_env_sweep_noise(0.16, 300.0, 900.0, 10.0))
	_clips["player_hit"] = _to_wav(_env_thud(0.1, 110.0, 16.0))


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var s: float = clamp(samples[i], -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav


# A decaying burst of white noise — gunshots, generic "crack" impacts.
func _env_noise(duration: float, decay: float) -> PackedFloat32Array:
	var n := int(SAMPLE_RATE * duration)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-decay * t)
		out[i] = (randf() * 2.0 - 1.0) * env
	return out


# Noise blended with a pitch-sweeping tone — whooshes (swings, throws, dashes).
func _env_sweep_noise(duration: float, freq_start: float, freq_end: float, decay: float) -> PackedFloat32Array:
	var n := int(SAMPLE_RATE * duration)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in range(n):
		var t: float = float(i) / SAMPLE_RATE
		var f: float = lerp(freq_start, freq_end, t / duration)
		phase += f / SAMPLE_RATE
		var env: float = exp(-decay * t)
		var tone: float = sin(phase * TAU)
		var noise: float = randf() * 2.0 - 1.0
		out[i] = lerp(noise, tone, 0.35) * env
	return out


# A low tone plus a little noise — thuds, hits, knockback/knockdown.
func _env_thud(duration: float, freq: float, decay: float) -> PackedFloat32Array:
	var n := int(SAMPLE_RATE * duration)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-decay * t)
		var tone: float = sin(t * freq * TAU)
		var noise: float = (randf() * 2.0 - 1.0) * 0.5
		out[i] = (tone * 0.75 + noise * 0.25) * env
	return out


# Two-note upward chirp — pickups.
func _env_blip(duration: float, freq_start: float, freq_end: float) -> PackedFloat32Array:
	var n := int(SAMPLE_RATE * duration)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in range(n):
		var t: float = float(i) / SAMPLE_RATE
		var f: float = freq_start if t < duration * 0.5 else freq_end
		phase += f / SAMPLE_RATE
		var env: float = 1.0 - (t / duration)
		out[i] = sin(phase * TAU) * env * env
	return out


# A clean tone sweep with a linear fade — deaths, chokehold cues.
func _env_tone_sweep(duration: float, freq_start: float, freq_end: float) -> PackedFloat32Array:
	var n := int(SAMPLE_RATE * duration)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in range(n):
		var t: float = float(i) / SAMPLE_RATE
		var f: float = lerp(freq_start, freq_end, t / duration)
		phase += f / SAMPLE_RATE
		var env: float = 1.0 - (t / duration)
		out[i] = sin(phase * TAU) * env
	return out
