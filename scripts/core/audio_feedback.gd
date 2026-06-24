class_name AudioFeedback
extends Node

var player: AudioStreamPlayer
var cache := {}

func _ready() -> void:
	player = AudioStreamPlayer.new()
	add_child(player)

func play(kind: String) -> void:
	if not cache.has(kind):
		cache[kind] = _build_sound(kind)
	player.stream = cache[kind]
	player.play()

func set_master_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(value, 0.001, 1.0)))

func _build_sound(kind: String) -> AudioStreamWAV:
	var frequency := 360.0
	var duration := 0.13
	var second := 0.0
	match kind:
		"select": frequency = 520.0; duration = 0.07
		"confirm": frequency = 420.0; second = 630.0; duration = 0.18
		"win": frequency = 523.25; second = 783.99; duration = 0.35
		"lose": frequency = 220.0; second = 164.81; duration = 0.38
		"reveal": frequency = 310.0; second = 466.0; duration = 0.24
		"reading": frequency = 740.0; second = 930.0; duration = 0.25
		"amnesia": frequency = 180.0; second = 91.0; duration = 0.55
	var rate := 44100
	var sample_count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / rate
		var envelope := pow(1.0 - float(i) / sample_count, 2.2)
		var sample := sin(TAU * frequency * t)
		if second > 0.0:
			sample = sample * 0.62 + sin(TAU * second * t) * 0.38
		var value := int(clampf(sample * envelope, -1.0, 1.0) * 15000.0)
		bytes[i * 2] = value & 0xFF
		bytes[i * 2 + 1] = (value >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream

