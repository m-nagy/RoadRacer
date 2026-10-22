extends Node
## Persists progress and settings to user://save.json.
## Autoload order: loaded first; uses no other autoload.
##
## Save format version 2: stages are identified by their id (see Stages), `cleared` lists the stages
## that were finished and `best` holds the best score per stage id. Version 1 files (best scores keyed
## "1".."6" and a single `unlocked` number) are converted when they are loaded.
## Writes are crash-safe: the new file is written next to the old one and renamed into place, and the
## previous save is kept as save.json.bak (used if the main file is missing or unreadable).

const PATH := "user://save.json"
const VERSION := 2
const V1_STAGE_IDS := ["city", "country", "bridge", "desert", "snow", "night_city"]

## Where saves are written. The test bot points this elsewhere so it never touches a real save.
var save_path := PATH

var cleared: Array[String] = []   # ids of the stages that were finished
var best: Dictionary = {}         # stage id -> {"score": int, "time": float}
var prefs: Array = [{"color": 0, "easy": false}, {"color": 4, "easy": false}]
var fullscreen := true
var difficulty := "normal"        # "easy" | "normal" | "hard"
var music_volume := 0.8           # 0..1
var sfx_volume := 1.0
var controls: Array = [ControlDefaults.profile(0), ControlDefaults.profile(1)]


func _ready() -> void:
	load_save()


func load_save() -> void:
	var data = _read_json(save_path)
	if typeof(data) != TYPE_DICTIONARY:
		data = _read_json(save_path + ".bak")   # the main file is missing or damaged
	if typeof(data) != TYPE_DICTIONARY:
		return
	if int(data.get("version", 1)) < 2:
		data = _migrate_v1(data)
	cleared.clear()
	for id in data.get("cleared", []):
		if typeof(id) == TYPE_STRING and not cleared.has(id):
			cleared.append(id)
	best = data.get("best", {})
	fullscreen = bool(data.get("fullscreen", true))
	difficulty = str(data.get("difficulty", "normal"))
	if not ["easy", "normal", "hard"].has(difficulty):
		difficulty = "normal"
	music_volume = clampf(float(data.get("music_volume", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", 1.0)), 0.0, 1.0)
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
	var unlocked := clampi(int(data.get("unlocked", 1)), 1, V1_STAGE_IDS.size())
	for i in V1_STAGE_IDS.size():
		var id: String = V1_STAGE_IDS[i]
		if old_best.has(str(i + 1)):
			new_best[id] = old_best[str(i + 1)]
			done.append(id)
		elif i + 1 < unlocked:
			done.append(id)
	out["best"] = new_best
	out["cleared"] = done
	out["version"] = VERSION
	out.erase("unlocked")
	return out


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


func save() -> void:
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return
	f.store_string(JSON.stringify({"version": VERSION, "cleared": cleared, "best": best, "prefs": prefs, "fullscreen": fullscreen,
		"difficulty": difficulty, "music_volume": music_volume, "sfx_volume": sfx_volume, "controls": controls}))
	f.close()
	# Keep the previous save as .bak, then move the finished file into place.
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(save_path + ".bak"):
			DirAccess.remove_absolute(save_path + ".bak")
		DirAccess.rename_absolute(save_path, save_path + ".bak")
	DirAccess.rename_absolute(tmp, save_path)


func store_prefs(players: Array[PlayerSlot]) -> void:
	for i in GameConst.MAX_PLAYERS:
		prefs[i] = {"color": players[i].color, "easy": players[i].easy}
	save()


func best_score(id: String) -> int:
	return int(best.get(id, {}).get("score", 0))


func is_cleared(id: String) -> bool:
	return cleared.has(id)


## Campaign stages open up one after the other; a challenge opens when the stage it is based on is cleared.
func is_unlocked(id: String) -> bool:
	var need := Stages.requirement(id)
	return need == "" or cleared.has(need)


## The stage the "Continue" button offers: the first campaign stage not cleared yet (the last one when all are).
func continue_id() -> String:
	for s in Stages.CAMPAIGN:
		if not cleared.has(s.id):
			return s.id
	return Stages.CAMPAIGN[Stages.CAMPAIGN.size() - 1].id


## Returns true when the score is a new personal best.
func record_clear(id: String, score: int, time_left: float) -> bool:
	var is_best := score > best_score(id)
	if is_best:
		best[id] = {"score": score, "time": time_left}
	if not cleared.has(id):
		cleared.append(id)
	save()
	return is_best
