extends Node
## Music (random track per stage), one-shot sound effects, and per-player engine hum.
## Autoload order: uses SaveManager (volumes) and Sfx.

const MUSIC_DIR := "res://assets/music/"
const IMPACT_DIR := "res://assets/sfx/"

var _music: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _engines: Dictionary = {}
var _track_names: Array = []
var _impacts: Dictionary = {}
const MUSIC_BASE_DB := -8.0
const SIREN_RANGE := 1400.0

var music_volume_db := MUSIC_BASE_DB
var sfx_db := 0.0
var _ducked := false
var _sirens: Dictionary = {}   # "police" / "ambulance" -> AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.volume_db = music_volume_db
	add_child(_music)
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for k in ["police", "ambulance"]:
		var sp := AudioStreamPlayer.new()
		var st: AudioStream = load("res://assets/sfx/%s.mp3" % k)
		if st is AudioStreamMP3:
			st.loop = true
		sp.stream = st
		sp.volume_db = -80.0
		add_child(sp)
		_sirens[k] = sp
	apply_volumes()
	_track_names = _list(MUSIC_DIR, ".ogg")
	for f in _list(IMPACT_DIR, ".ogg"):
		var key: String = f.get_basename().get_slice("_", 0)
		if not _impacts.has(key):
			_impacts[key] = []
		_impacts[key].append(f)


## Applies the saved music / effects volume sliders.
func apply_volumes() -> void:
	music_volume_db = MUSIC_BASE_DB + (linear_to_db(SaveManager.music_volume) if SaveManager.music_volume > 0.001 else -80.0)
	sfx_db = linear_to_db(SaveManager.sfx_volume) if SaveManager.sfx_volume > 0.001 else -80.0
	if _music:
		_music.volume_db = music_volume_db - (12.0 if _ducked else 0.0)
	for k in _engines:
		_engines[k].volume_db = -22.0 + sfx_db


func _list(dir: String, ext: String) -> Array:
	var out := []
	# Exported builds list .ogg files as ".ogg.import"; strip that suffix.
	for f in DirAccess.get_files_at(dir):
		var n := f.trim_suffix(".import")
		if n.ends_with(ext) and not out.has(n):
			out.append(n)
	out.sort()
	return out


func play_music(track: int = -1) -> void:
	if _track_names.is_empty():
		return
	var pick: String = _track_names[randi() % _track_names.size()] if track < 0 else _track_names[track % _track_names.size()]
	var stream: AudioStream = load(MUSIC_DIR + pick)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_music.stream = stream
	_music.volume_db = music_volume_db
	_music.play()


func stop_music() -> void:
	_music.stop()


func duck_music(ducked: bool) -> void:
	_ducked = ducked
	_music.volume_db = music_volume_db - (12.0 if ducked else 0.0)


## Police / ambulance sirens, louder the closer the nearest such car is to any player.
## Pass INF when there is none.
func update_sirens(police_dist: float, ambulance_dist: float) -> void:
	for k in _sirens:
		var dist: float = police_dist if k == "police" else ambulance_dist
		var p: AudioStreamPlayer = _sirens[k]
		var near := clampf(1.0 - dist / SIREN_RANGE, 0.0, 1.0)
		if near <= 0.0:
			if p.playing:
				p.stop()
			continue
		p.volume_db = lerpf(-34.0, -4.0, near * near) + sfx_db
		if not p.playing:
			p.play()


## Numbers for the test bot's logs.
func track_count() -> int:
	return _track_names.size()


func impact_families() -> Array:
	return _impacts.keys()


func siren_playing(kind: String) -> bool:
	return _sirens[kind].playing


func siren_volume_db(kind: String) -> float:
	return _sirens[kind].volume_db


func stop_sirens() -> void:
	for k in _sirens:
		_sirens[k].stop()


## Plays a synthesized effect by name (see Sfx).
func play(sfx_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	_play_stream(Sfx.get_stream(sfx_name), volume_db + sfx_db, pitch)


## Plays a random impact sample of a family such as "impactMetal" or "impactGeneric".
func play_impact(family: String, volume_db := 0.0) -> void:
	if not _impacts.has(family):
		return
	var f: String = _impacts[family].pick_random()
	_play_stream(load(IMPACT_DIR + f), volume_db + sfx_db, randf_range(0.92, 1.08))


func _play_stream(stream: AudioStream, volume_db: float, pitch: float) -> void:
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


func engine_start(slot: int) -> void:
	if not _engines.has(slot):
		var p := AudioStreamPlayer.new()
		p.stream = Sfx.get_stream("engine")
		p.volume_db = -22.0 + sfx_db
		add_child(p)
		_engines[slot] = p
	_engines[slot].play()


func engine_set(slot: int, speed_ratio: float) -> void:
	if _engines.has(slot):
		_engines[slot].pitch_scale = 0.7 + speed_ratio * 1.8


func engine_stop(slot: int) -> void:
	if _engines.has(slot):
		_engines[slot].stop()


func engines_stop_all() -> void:
	for s in _engines:
		_engines[s].stop()
	stop_sirens()
