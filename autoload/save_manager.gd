extends Node
## Persists progress and settings.
## Autoload order: loaded first; uses no other autoload.
##
## Where: an exported game keeps save.json in the folder of the exe (or in user:// when that folder cannot
## be written, e.g. under Program Files); running from the editor uses user://. A save left in user://
## by an older version is read when there is no save in the new place, and left where it is.
##
## Auto-save (on by default): every change is written at once. With it off, changes are only remembered
## (`dirty`) until write() is called, from the Save Now buttons or when the game is quit (see Game).
##
## Save format version 3: stages are identified by their id (see Stages), `cleared` lists the stages
## that were finished and `best` holds the best score per stage id; `last_players` remembers who played
## on what, `autosave` is the option above. Older files are converted when they are loaded: version 1
## (best scores keyed "1".."6" and a single `unlocked` number) to version 2, and version 2 (one stage per
## track) to version 3, where a cleared track counts as clearing all three stages of its world.
## Writes are crash-safe: the new file is written next to the old one and renamed into place, and the
## previous save is kept as save.json.bak (used if the main file is missing or unreadable).

signal dirty_changed

const FILE_NAME := "save.json"
const LEGACY_PATH := "user://save.json"
const VERSION := 3
const OLD_STAGE_IDS := ["city", "country", "bridge", "desert", "snow", "night_city"]   # the stages of versions 1 and 2

## Where saves are written. The test bot points this elsewhere so it never touches a real save.
var save_path := default_path()
var autosave := true
var dirty := false                # changes not written yet (only possible while Auto-save is off)
var last_players: Array = [null, null]   # per slot: {"kind": "kb", "kb": 0|1} or {"kind": "pad", "guid", "name"}

var cleared: Array[String] = []   # ids of the stages that were finished
var best: Dictionary = {}         # stage id -> {"score": int, "time": float}
var prefs: Array = [{"color": 0, "easy": false}, {"color": 4, "easy": false}]
var fullscreen := true
var difficulty := "normal"        # "easy" | "normal" | "hard"
var music_volume := 0.8           # 0..1
var sfx_volume := 1.0
var graphics := "normal"          # "normal" | "low" (fewer particles, no night headlights: for slow graphics cards)
var controls: Array = [ControlDefaults.profile(0), ControlDefaults.profile(1)]


func _ready() -> void:
	load_save()


## save.json next to the exe for an exported game, user://save.json otherwise.
static func default_path() -> String:
	if not OS.has_feature("editor"):
		var dir := OS.get_executable_path().get_base_dir()
		if _can_write(dir):
			return dir.path_join(FILE_NAME)
	return LEGACY_PATH


static func _can_write(dir: String) -> bool:
	var probe := dir.path_join(".write_test")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true


## Where the save is, for showing to the player.
func save_location() -> String:
	return ProjectSettings.globalize_path(save_path)


func load_save() -> void:
	var data = _read_json(save_path)
	if typeof(data) != TYPE_DICTIONARY:
		data = _read_json(save_path + ".bak")   # the main file is missing or damaged
	if typeof(data) != TYPE_DICTIONARY and save_path != LEGACY_PATH:
		data = _read_json(LEGACY_PATH)          # the save of an older version of the game
	if typeof(data) != TYPE_DICTIONARY:
		return
	if int(data.get("version", 1)) < 2:
		data = _migrate_v1(data)
	if int(data.get("version", 2)) < 3:
		data = _migrate_v2(data)
	cleared.clear()
	for id in data.get("cleared", []):
		if typeof(id) == TYPE_STRING and not cleared.has(id) and Stages.has(id):
			cleared.append(id)
	best = data.get("best", {}) if typeof(data.get("best", null)) == TYPE_DICTIONARY else {}
	autosave = bool(data.get("autosave", true))
	_load_last_players(data.get("last_players", null))
	fullscreen = bool(data.get("fullscreen", true))
	difficulty = str(data.get("difficulty", "normal"))
	if not ["easy", "normal", "hard"].has(difficulty):
		difficulty = "normal"
	music_volume = clampf(float(data.get("music_volume", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", 1.0)), 0.0, 1.0)
	graphics = str(data.get("graphics", "normal"))
	if not ["normal", "low"].has(graphics):
		graphics = "normal"
	_load_controls(data.get("controls", null))
	# JSON turns the colour index into a float (6 -> 6.0); "%" on a float is a runtime error, so
	# convert back to int here or the car screen can't change colour.
	var p = data.get("prefs", null)
	if typeof(p) == TYPE_ARRAY and p.size() >= 2:
		for i in 2:
			if typeof(p[i]) == TYPE_DICTIONARY:
				prefs[i] = {"color": posmod(int(p[i].get("color", prefs[i]["color"])), GameConst.COLORS.size()),
					"easy": bool(p[i].get("easy", false))}


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


## Version 1 -> 2: best scores move from "1".."6" to stage ids; stages before the highest unlocked
## one, and every stage with a best score, count as cleared.
func _migrate_v1(data: Dictionary) -> Dictionary:
	var out := data.duplicate()
	var old_best: Dictionary = data.get("best", {}) if typeof(data.get("best", null)) == TYPE_DICTIONARY else {}
	var new_best := {}
	var done: Array[String] = []
	var unlocked := clampi(int(data.get("unlocked", 1)), 1, OLD_STAGE_IDS.size())
	for i in OLD_STAGE_IDS.size():
		var id: String = OLD_STAGE_IDS[i]
		if old_best.has(str(i + 1)):
			new_best[id] = old_best[str(i + 1)]
			done.append(id)
		elif i + 1 < unlocked:
			done.append(id)
	out["best"] = new_best
	out["cleared"] = done
	out["version"] = 2
	out.erase("unlocked")
	return out


## Version 2 -> 3: the six stages became six worlds of three stages. A cleared old stage counts as its
## whole world cleared, so no progress is lost. Best scores are dropped: the new stages are shorter and
## different, so the old numbers would not mean anything.
func _migrate_v2(data: Dictionary) -> Dictionary:
	var out := data.duplicate()
	var done: Array[String] = []
	var old_cleared = data.get("cleared", [])
	if typeof(old_cleared) == TYPE_ARRAY:
		for id in old_cleared:
			if OLD_STAGE_IDS.has(id):
				for n in 3:
					done.append("%s_%d" % [id, n + 1])
	out["cleared"] = done
	out["best"] = {}
	out["version"] = VERSION
	return out


func _load_last_players(saved) -> void:
	last_players = [null, null]
	if typeof(saved) != TYPE_ARRAY:
		return
	for slot in mini(2, saved.size()):
		var e = saved[slot]
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if e.get("kind", "") == "kb":
			last_players[slot] = {"kind": "kb", "kb": clampi(int(e.get("kb", slot)), 0, 1)}
		elif e.get("kind", "") == "pad" and typeof(e.get("guid", null)) == TYPE_STRING:
			last_players[slot] = {"kind": "pad", "guid": e["guid"], "name": str(e.get("name", ""))}


## Remember who played on what (see PlayersScreen).
func remember_players(list: Array) -> void:
	last_players = list
	save()


## Merge saved control profiles over the defaults (JSON turns ints into floats).
func _load_controls(saved) -> void:
	controls = [ControlDefaults.profile(0), ControlDefaults.profile(1)]
	if typeof(saved) != TYPE_ARRAY:
		return
	for slot in mini(2, saved.size()):
		var sp = saved[slot]
		if typeof(sp) != TYPE_DICTIONARY:
			continue
		for a in ControlDefaults.ACTIONS:
			if typeof(sp.get("kb", null)) == TYPE_DICTIONARY and sp["kb"].has(a):
				controls[slot]["kb"][a] = int(sp["kb"][a])
			if typeof(sp.get("pad", null)) == TYPE_DICTIONARY and typeof(sp["pad"].get(a, null)) == TYPE_ARRAY:
				var evs := []
				for ev in sp["pad"][a]:
					if typeof(ev) == TYPE_DICTIONARY and ev.has("t") and ev.has("i"):
						var e := {"t": str(ev["t"]), "i": int(ev["i"])}
						if ev.has("v"):
							e["v"] = float(ev["v"])
						evs.append(e)
				if not evs.is_empty():
					controls[slot]["pad"][a] = evs


func reset_controls(slot: int) -> void:
	controls[slot] = ControlDefaults.profile(slot)
	save()


## Called after every change. Writes at once with Auto-save on; otherwise only notes that there is
## something to save.
func save() -> void:
	if autosave:
		write()
	elif not dirty:
		dirty = true
		dirty_changed.emit()


func set_autosave(on: bool) -> void:
	autosave = on
	write()   # turning it on saves what is pending; turning it off must stick too


## Writes the save file now, whatever the Auto-save setting is.
func write() -> void:
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return
	f.store_string(JSON.stringify({"version": VERSION, "cleared": cleared, "best": best, "prefs": prefs, "fullscreen": fullscreen,
		"difficulty": difficulty, "music_volume": music_volume, "sfx_volume": sfx_volume, "graphics": graphics, "controls": controls,
		"autosave": autosave, "last_players": last_players}))
	f.close()
	# Keep the previous save as .bak, then move the finished file into place.
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(save_path + ".bak"):
			DirAccess.remove_absolute(save_path + ".bak")
		DirAccess.rename_absolute(save_path, save_path + ".bak")
	DirAccess.rename_absolute(tmp, save_path)
	if dirty:
		dirty = false
		dirty_changed.emit()


func store_prefs(players: Array[PlayerSlot]) -> void:
	for i in GameConst.MAX_PLAYERS:
		prefs[i] = {"color": players[i].color, "easy": players[i].easy}
	save()


func best_score(id: String) -> int:
	return int(best.get(id, {}).get("score", 0))


func is_cleared(id: String) -> bool:
	return cleared.has(id)


## Stages open up one after the other.
func is_unlocked(id: String) -> bool:
	var need := Stages.requirement(id)
	return need == "" or cleared.has(need)


## The stage the "Continue" button offers: the first stage not cleared yet (the last one when all are).
func continue_id() -> String:
	var list := Stages.all()
	for s in list:
		if not cleared.has(s.id):
			return s.id
	return list[list.size() - 1].id


## Returns true when the score is a new personal best.
func record_clear(id: String, score: int, time_left: float) -> bool:
	var is_best := score > best_score(id)
	if is_best:
		best[id] = {"score": score, "time": time_left}
	if not cleared.has(id):
		cleared.append(id)
	save()
	return is_best
