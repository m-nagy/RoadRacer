extends Node
## Synthesizes retro (NES-style) sound effects at startup so no extra audio files are needed.

const RATE := 22050

var sounds: Dictionary = {}


func _ready() -> void:
	sounds["beep"] = _tone([[660.0, 0.12]], "square", 0.35)
	sounds["go"] = _tone([[990.0, 0.35]], "square", 0.4)
	sounds["fuel"] = _tone([[523.0, 0.07], [659.0, 0.07], [784.0, 0.07], [1047.0, 0.14]], "square", 0.35)
	sounds["checkpoint"] = _tone([[523.0, 0.1], [523.0, 0.05], [784.0, 0.1], [1047.0, 0.1], [1319.0, 0.25]], "square", 0.35)
	sounds["goal"] = _tone([[523.0, 0.15], [659.0, 0.15], [784.0, 0.15], [1047.0, 0.3], [784.0, 0.12], [1047.0, 0.5]], "square", 0.4)
	sounds["fail"] = _tone([[392.0, 0.2], [330.0, 0.2], [262.0, 0.2], [196.0, 0.5]], "triangle", 0.5)
	sounds["blip"] = _tone([[880.0, 0.05]], "square", 0.3)
	sounds["select"] = _tone([[660.0, 0.05], [880.0, 0.08]], "square", 0.3)
	sounds["join"] = _tone([[440.0, 0.06], [660.0, 0.06], [880.0, 0.12]], "square", 0.3)
	sounds["overtake"] = _tone([[1200.0, 0.04], [1600.0, 0.06]], "square", 0.2)
	sounds["skid"] = _noise(0.5, 0.3, 0.9, true)
	sounds["whoosh"] = _noise(0.7, 0.3, 1.0, true)
	sounds["boom"] = _noise(0.6, 0.55, 0.0, false)
	sounds["siren"] = _siren()
	sounds["engine"] = _engine()


func get_stream(n: String) -> AudioStream:
	return sounds[n]


## notes: [[freq, seconds], ...]
func _tone(notes: Array, wave: String, vol: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var phase := 0.0
	for n in notes:
		var freq: float = n[0]
		var count := int(RATE * float(n[1]))
		for i in count:
			phase += freq / RATE
			var t := phase - floorf(phase)
			var s := 0.0
			match wave:
				"square": s = 1.0 if t < 0.5 else -1.0
				"triangle": s = 4.0 * abs(t - 0.5) - 1.0
				_: s = sin(t * TAU)
			var env := 1.0 - float(i) / count * 0.35
			var v := int(clampf(s * vol * env, -1.0, 1.0) * 32000.0)
			data.append(v & 0xFF)
			data.append((v >> 8) & 0xFF)
	return _wav(data, false)


## Noise burst. `fade_in` ramps volume up (whoosh); sweep = true low-passes progressively.
func _noise(seconds: float, vol: float, _unused: float, sweep: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(RATE * seconds)
	var last := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in count:
		var k := float(i) / count
		var white := rng.randf_range(-1.0, 1.0)
		var a := 0.9 - 0.7 * k if sweep else 0.25 + 0.7 * (1.0 - k)
		last = lerpf(last, white, clampf(a, 0.05, 1.0))
		var env := (1.0 - k) * (1.0 - k) if not sweep else sin(k * PI)
		var v := int(clampf(last * vol * env * 1.6, -1.0, 1.0) * 32000.0)
		data.append(v & 0xFF)
		data.append((v >> 8) & 0xFF)
	return _wav(data, false)


func _siren() -> AudioStreamWAV:
	var data := PackedByteArray()
	var phase := 0.0
	var count := int(RATE * 0.8)
	for i in count:
		var freq := 700.0 if (i * 2 / count) % 2 == 0 else 950.0
		phase += freq / RATE
		var t := phase - floorf(phase)
		var v := int((1.0 if t < 0.5 else -1.0) * 0.18 * 32000.0)
		data.append(v & 0xFF)
		data.append((v >> 8) & 0xFF)
	return _wav(data, false)


## Short looping engine hum; pitch is changed with AudioStreamPlayer.pitch_scale.
func _engine() -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := 2205  # exactly 10 cycles of 100 Hz so the loop is seamless
	for i in count:
		var t := float(i) / RATE
		var s := 0.0
		s += sin(TAU * 100.0 * t) * 0.5
		s += sin(TAU * 200.0 * t) * 0.3
		s += sin(TAU * 300.0 * t) * 0.15
		s += (1.0 if fmod(t * 100.0, 1.0) < 0.5 else -1.0) * 0.12
		var v := int(clampf(s * 0.5, -1.0, 1.0) * 30000.0)
		data.append(v & 0xFF)
		data.append((v >> 8) & 0xFF)
	var w := _wav(data, true)
	return w


func _wav(data: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size() / 2
	return w
