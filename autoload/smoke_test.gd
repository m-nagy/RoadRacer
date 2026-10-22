extends Node
## Start-up check for the build pipeline (works in release builds):
##   RoadRacer.exe --headless -- --smoke-test
## plays a short race on a night + storm stage with two players, then prints "SMOKE OK" and quits
## (or "SMOKE FAIL ..." and exits with code 1). It saves nothing. Without the argument this node
## removes itself immediately. Adding --expect-release makes it fail when the exe is a debug build.
## Autoload order: last; uses Game, SaveManager and InputManager.

const STAGE := "storm_desert"
const SECONDS := 14.0       # real time: the countdown takes 4 s, the rest is racing
const MIN_DISTANCE := 400.0

var _t := 0.0


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--smoke-test"):
		queue_free()
		return
	if OS.get_cmdline_user_args().has("--expect-release") and OS.is_debug_build():
		print("SMOKE FAIL: this is a debug build")
		get_tree().quit(1)
		return
	SaveManager.save_path = "user://smoke/save.json"
	Game.prefs_applied = true
	for i in GameConst.MAX_PLAYERS:
		Game.players[i].active = true
		Game.players[i].easy = true
		Game.players[i].ready = true
		InputManager.assign_keyboard(i)
	print("[smoke] racing %s with 2 players for %.0f s" % [STAGE, SECONDS])
	await get_tree().create_timer(0.5).timeout   # let the title screen come up first
	Game.go_to_race(STAGE)


func _process(delta: float) -> void:
	_t += delta
	for i in GameConst.MAX_PLAYERS:
		Input.action_press("p%d_fast" % i)
	if _t < SECONDS:
		return
	var scene := get_tree().current_scene
	var world: World = scene.get("world") if scene != null else null
	if world == null or world.players.size() != 2:
		_finish("no race was started")
		return
	for p in world.players:
		if p.d() < MIN_DISTANCE:
			_finish("player %d only reached d=%.0f" % [p.slot + 1, p.d()])
			return
	_finish("")


func _finish(problem: String) -> void:
	set_process(false)
	if problem == "":
		print("SMOKE OK")
		get_tree().quit(0)
	else:
		print("SMOKE FAIL: ", problem)
		get_tree().quit(1)
