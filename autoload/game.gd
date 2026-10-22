extends Node
## Session state shared between the title screen and the race.
## Autoload order: uses SaveManager (loaded before it) and nothing else.

const MAX_PLAYERS := GameConst.MAX_PLAYERS

const COLORS := GameConst.COLORS


## One entry per slot (see PlayerSlot).
var players: Array[PlayerSlot] = []
var stage_id := "city_1"   # the stage being raced (see Stages)
var shader: Shader = preload("res://shaders/car_color.gdshader")
var prefs_applied := false
var pending_stage_id := "" # stage chosen on the home screen, started after players + cars are picked
var debug_boxes := false   # F3: show collision boxes


func _ready() -> void:
	reset_players()
	# Start in the saved window mode (the test bot keeps the window it was given).
	if not OS.get_cmdline_user_args().has("--autotest"):
		set_fullscreen(SaveManager.fullscreen, false)


func reset_players() -> void:
	players.clear()
	for i in MAX_PLAYERS:
		var slot := PlayerSlot.new()
		slot.color = i * 4
		players.append(slot)


func active_slots() -> Array:
	var out := []
	for i in players.size():
		if players[i].active:
			out.append(i)
	return out


func make_car_material(color_idx: int) -> ShaderMaterial:
	var c: Dictionary = COLORS[color_idx % COLORS.size()]
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("hue_shift", c["hue"])
	m.set_shader_parameter("sat_mul", c["sat"])
	m.set_shader_parameter("val_mul", c["val"])
	return m


func go_to_race(id: String) -> void:
	stage_id = Stages.by_id(id).id
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/race/race.tscn")


func go_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title/title.tscn")


## Display colour for a colour swatch (matches the recoloured car).
func swatch(color_idx: int) -> Color:
	var c: Dictionary = COLORS[color_idx % COLORS.size()]
	return Color.from_hsv(fposmod(c["hue"], 1.0), clampf(c["sat"], 0.0, 1.0) * 0.9, 1.0)


## Low graphics: fewer weather particles, no night headlights (for slow graphics cards).
func is_low_graphics() -> bool:
	return SaveManager.graphics == "low"


## Share of the weather particles to create: all of them normally, fewer on Low, and fewer still in
## split screen, where every player's view has its own.
func weather_density(player_count: int) -> float:
	if not is_low_graphics():
		return 1.0
	return 0.5 if player_count < 2 else 0.35


func is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func set_fullscreen(on: bool, remember := true) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	if remember:
		SaveManager.fullscreen = on
		SaveManager.save()
