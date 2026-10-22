extends Node
## Persists progress to user://save.json.
## Autoload order: loaded first; uses no other autoload.

const PATH := "user://save.json"

## Where saves are written. The test bot points this elsewhere so it never touches a real save.
var save_path := PATH

var unlocked := 1                 # highest unlocked stage, 1-based
var best: Dictionary = {}         # "1" -> {"score": int, "time": float}
var prefs: Array = [{"color": 0, "easy": false}, {"color": 4, "easy": false}]
var fullscreen := true
var difficulty := "normal"        # "easy" | "normal" | "hard"
var music_volume := 0.8           # 0..1
var sfx_volume := 1.0
var controls: Array = [ControlDefaults.profile(0), ControlDefaults.profile(1)]


func _ready() -> void:
	load_save()


func load_save() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	unlocked = clampi(int(data.get("unlocked", 1)), 1, GameConst.STAGE_COUNT)
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
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return
	f.store_string(JSON.stringify({"unlocked": unlocked, "best": best, "prefs": prefs, "fullscreen": fullscreen,
		"difficulty": difficulty, "music_volume": music_volume, "sfx_volume": sfx_volume, "controls": controls}))


func store_prefs(players: Array[PlayerSlot]) -> void:
	for i in GameConst.MAX_PLAYERS:
		prefs[i] = {"color": players[i].color, "easy": players[i].easy}
	save()


func best_score(stage_1based: int) -> int:
	return int(best.get(str(stage_1based), {}).get("score", 0))


## Returns true when the score is a new personal best.
func record_clear(stage_1based: int, score: int, time_left: float) -> bool:
	var key := str(stage_1based)
	var is_best := score > best_score(stage_1based)
	if is_best:
		best[key] = {"score": score, "time": time_left}
	if stage_1based + 1 > unlocked and stage_1based < GameConst.STAGE_COUNT:
		unlocked = stage_1based + 1
	save()
	return is_best
