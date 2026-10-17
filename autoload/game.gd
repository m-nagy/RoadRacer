extends Node
## Session state shared between the title screen and the race.

const MAX_PLAYERS := 2

# Hue shifts are relative to the red base sprite (Audi.png).
const COLORS := [
	{"name": "Red", "hue": 0.0, "sat": 1.0, "val": 1.0},
	{"name": "Orange", "hue": 0.07, "sat": 1.0, "val": 1.05},
	{"name": "Yellow", "hue": 0.14, "sat": 1.0, "val": 1.1},
	{"name": "Green", "hue": 0.33, "sat": 1.0, "val": 0.95},
	{"name": "Blue", "hue": 0.60, "sat": 1.0, "val": 1.0},
	{"name": "Purple", "hue": 0.76, "sat": 0.9, "val": 0.95},
	{"name": "Pink", "hue": 0.90, "sat": 0.55, "val": 1.15},
	{"name": "White", "hue": 0.0, "sat": 0.0, "val": 1.5},
]

const STAGE_COUNT := 6

## One entry per slot: active, device (joypad id or -1), kb (plays on the keyboard), color,
## easy (= auto-steer mode), ready.
var players: Array = []
var stage_index := 0  # 0-based
var shader: Shader = preload("res://shaders/car_color.gdshader")
var prefs_applied := false
var pending_stage := 0     # stage chosen on the home screen, started after players + cars are picked
var debug_boxes := false   # F3: show collision boxes


func _ready() -> void:
	reset_players()


func reset_players() -> void:
	players.clear()
	for i in MAX_PLAYERS:
		players.append({"active": false, "device": -1, "kb": false, "color": i * 4, "easy": false, "ready": false})


func active_slots() -> Array:
	var out := []
	for i in players.size():
		if players[i]["active"]:
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


func go_to_race(stage: int) -> void:
	stage_index = clampi(stage, 0, STAGE_COUNT - 1)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/race/race.tscn")


func go_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title/title.tscn")


## Display colour for a colour swatch (matches the recoloured car).
func swatch(color_idx: int) -> Color:
	var c: Dictionary = COLORS[color_idx % COLORS.size()]
	return Color.from_hsv(fposmod(c["hue"], 1.0), clampf(c["sat"], 0.0, 1.0) * 0.9, 1.0)


func is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func set_fullscreen(on: bool, remember := true) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	if remember:
		SaveManager.fullscreen = on
		SaveManager.save()
