extends RefCounted
class_name SoundManager

const SAMPLE_RATE := 22050.0

var _playback: AudioStreamGeneratorPlayback = null
var _queue: Array = []

func setup() -> bool:
	var player := AudioStreamPlayer.new()
	player.name = "SoundPlayer"
	player.bus = "Master"

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 0.1
	player.stream = stream

	var root := Engine.get_main_loop() as SceneTree
	if root:
		root.root.add_child(player)
		player.play()
		_playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
		return true
	return false

func play_sound(frequency: float, duration: float, wave_type: int = 0) -> void:
	_queue.append({ "freq": frequency, "dur": duration, "wave": wave_type })

func play_beep() -> void:
	play_sound(440.0, 0.05)

func play_door_open() -> void:
	play_sound(200.0, 0.15)
	_queue.append({ "freq": 400.0, "dur": 0.1, "wave": 0 })

func play_door_close() -> void:
	play_sound(150.0, 0.15)

func play_pistol() -> void:
	play_sound(80.0, 0.08)

func play_machine_gun() -> void:
	play_sound(60.0, 0.05)

func play_player_hurt() -> void:
	play_sound(100.0, 0.2)
	_queue.append({ "freq": 80.0, "dur": 0.2, "wave": 0 })

func play_enemy_hurt() -> void:
	play_sound(300.0, 0.1)

func play_enemy_death() -> void:
	play_sound(200.0, 0.15)
	_queue.append({ "freq": 150.0, "dur": 0.15, "wave": 0 })
	_queue.append({ "freq": 100.0, "dur": 0.2, "wave": 0 })

func play_pickup() -> void:
	play_sound(600.0, 0.06)
	_queue.append({ "freq": 800.0, "dur": 0.06, "wave": 0 })

func play_secret() -> void:
	play_sound(300.0, 0.1)
	_queue.append({ "freq": 500.0, "dur": 0.15, "wave": 0 })
	_queue.append({ "freq": 700.0, "dur": 0.1, "wave": 0 })

var _current_sound: Dictionary = {}
var _current_phase: float = 0.0
var _phase: float = 0.0

func process_audio() -> void:
	if _playback == null:
		return

	var to_fill := _playback.get_frames_available()
	if to_fill <= 0:
		return

	var buffer := PackedVector2Array()
	buffer.resize(to_fill)

	for i in to_fill:
		var sample := 0.0

		if _current_sound.is_empty() and not _queue.is_empty():
			_current_sound = _queue.pop_front()
			_current_phase = 0.0

		if not _current_sound.is_empty():
			var freq: float = _current_sound.get("freq", 440.0)
			var dur: float = _current_sound.get("dur", 0.1)
			var wave: int = _current_sound.get("wave", 0)

			_current_phase += 1.0 / SAMPLE_RATE
			var t := _current_phase / dur

			var envelope := 1.0
			if t < 0.05:
				envelope = t / 0.05
			elif t > 0.7:
				envelope = (1.0 - t) / 0.3

			match wave:
				0:  # square wave
					sample = (1.0 if fmod(_phase * freq, 1.0) < 0.5 else -1.0)
				1:  # triangle
					sample = abs(fmod(_phase * freq * 2.0, 2.0) - 1.0) * 2.0 - 1.0
				_:  # sine
					sample = sin(_phase * freq * TAU)

			sample *= envelope * 0.3

			if _current_phase >= dur:
				_current_sound = {}

			_phase += 1.0 / SAMPLE_RATE

		buffer[i] = Vector2(sample, sample)

	_playback.push_buffer(buffer)

func clear_queue() -> void:
	_queue.clear()
	_current_sound = {}
	_current_phase = 0.0