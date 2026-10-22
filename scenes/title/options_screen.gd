class_name OptionsScreen
extends Control
## Options: "Game Settings" tab (difficulty, volumes, full screen) and "Controls" tab
## (remap keyboard keys / gamepad buttons for each of the two player profiles).
## Everything is saved immediately. Esc / B goes back (or cancels a pending key capture).

signal back

const DIFF_TEXT := {
	"easy": "EASY: lots of fuel, few obstacles, hardly any blocking cars. Up to 10 crashes still lets you finish.",
	"normal": "NORMAL: a fair amount of fuel and traffic. Up to 5 crashes still lets you finish.",
	"hard": "HARD: little fuel, many obstacles, cars that block your way. A clean race - no crashes - is needed to finish.",
}

var _diff_buttons: Dictionary = {}

@onready var _tab_game: Button = %TabGame
@onready var _tab_controls: Button = %TabControls
@onready var _game_box: Control = %GameBox
@onready var _controls_box: Control = %ControlsBox
@onready var _diff_label: Label = %DifficultyText
@onready var _fs_button: Button = %FullscreenButton
@onready var _gfx_button: Button = %GraphicsButton
@onready var _capture_label: Label = %CaptureLabel
@onready var _test_label: Label = %MonitorText
@onready var _grid: GridContainer = %ControlsGrid
var _profile := 0
var _profile_buttons: Array = []
var _cells: Dictionary = {}   # "kb:left" -> Button
var _capturing := {}
var _capture_t := 0.0
var _test_t := 0.0
var _first_focus: Control


func _ready() -> void:
	_tab_game.pressed.connect(select_tab.bind(0))
	_tab_controls.pressed.connect(select_tab.bind(1))
	_diff_buttons = {"easy": %EasyButton, "normal": %NormalButton, "hard": %HardButton}
	for key in _diff_buttons:
		_diff_buttons[key].pressed.connect(_set_difficulty.bind(key))
	_setup_slider(%MusicSlider, %MusicPercent, SaveManager.music_volume, func(v):
		SaveManager.music_volume = v
		AudioManager.apply_volumes()
		SaveManager.save())
	_setup_slider(%SfxSlider, %SfxPercent, SaveManager.sfx_volume, func(v):
		SaveManager.sfx_volume = v
		AudioManager.apply_volumes()
		SaveManager.save()
		AudioManager.play("select"))
	_fs_button.pressed.connect(func():
		Game.set_fullscreen(not Game.is_fullscreen())
		_update_labels())
	_gfx_button.pressed.connect(func():
		SaveManager.graphics = "normal" if SaveManager.graphics == "low" else "low"
		SaveManager.save()
		AudioManager.play("select")
		_update_labels())
	_game_box.get_node("BackGame").pressed.connect(func(): back.emit())
	_build_controls()
	select_tab(0, false)
	_play_blip_on_focus(self)


## Every button makes a small sound when it gets the focus.
func _play_blip_on_focus(node: Node) -> void:
	for c in node.get_children():
		if c is Button:
			c.focus_entered.connect(func(): AudioManager.play("blip", -8.0))
		_play_blip_on_focus(c)


func _setup_slider(slider: HSlider, percent: Label, value: float, cb: Callable) -> void:
	slider.value = value
	percent.text = "%d%%" % int(value * 100)
	slider.value_changed.connect(cb)
	slider.value_changed.connect(func(v): percent.text = "%d%%" % int(v * 100))


func _set_difficulty(d: String) -> void:
	SaveManager.difficulty = d
	SaveManager.save()
	AudioManager.play("select")
	_update_labels()


func _update_labels() -> void:
	for d in _diff_buttons:
		var b: Button = _diff_buttons[d]
		var mark := "● " if SaveManager.difficulty == d else "○ "
		b.text = mark + String(d).capitalize()
	_diff_label.text = DIFF_TEXT[SaveManager.difficulty]
	_fs_button.text = "Full screen:  %s   (F11)" % ("ON" if Game.is_fullscreen() else "OFF")
	_gfx_button.text = "Graphics:  %s" % ("Low (faster)" if Game.is_low_graphics() else "Normal")


# ------------------------------------------------------------ controls tab

func _build_controls() -> void:
	var prow: HBoxContainer = _controls_box.get_node("Left/ProfileRow")
	for i in 2:
		var b: Button = prow.get_node("Player%d" % (i + 1))
		UiTheme.compact(b, 40)
		b.pressed.connect(_select_profile.bind(i))
		_profile_buttons.append(b)
	var rb: Button = prow.get_node("ResetButton")
	UiTheme.compact(rb, 40)
	rb.pressed.connect(func():
		SaveManager.reset_controls(_profile)
		refresh_cells())
	var bb: Button = prow.get_node("BackControls")
	UiTheme.compact(bb, 40)
	bb.pressed.connect(func(): back.emit())
	# One row per action: its name, the keyboard key and the gamepad button.
	for a in InputManager.ACTIONS:
		var act: String = a
		var name_label := Label.new()
		name_label.text = InputManager.ACTION_NAMES[act]
		name_label.add_theme_font_size_override("font_size", 22)
		_grid.add_child(name_label)
		for kind in ["kb", "pad"]:
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(190 if kind == "kb" else 250, 36)
			cell.add_theme_font_size_override("font_size", 22)
			UiTheme.compact(cell)
			cell.pressed.connect(start_capture.bind(kind, act))
			_grid.add_child(cell)
			_cells["%s:%s" % [kind, act]] = cell


func _select_profile(i: int) -> void:
	_profile = i
	refresh_cells()


func refresh_cells() -> void:
	for i in _profile_buttons.size():
		_profile_buttons[i].text = ("● " if i == _profile else "○ ") + "Player %d" % (i + 1)
	var prof: Dictionary = SaveManager.controls[_profile]
	for a in InputManager.ACTIONS:
		var kl := InputManager.key_label(prof["kb"].get(a, 0))
		_cells["kb:" + a].text = {"left": "← Left", "right": "→ Right", "up": "↑ Up", "down": "↓ Down"}.get(kl, kl)
		var evs: Array = prof["pad"].get(a, [])
		var names: Array = evs.map(func(e): return InputManager.pad_label(e))
		_cells["pad:" + a].text = " / ".join(names) if not names.is_empty() else "-"


func start_capture(kind: String, action: String) -> void:
	_capturing = {"kind": kind, "action": action}
	_capture_t = 0.0
	_capture_label.visible = true
	_capture_label.text = "Player %d - %s\n\nPress a %s…\n(Esc = cancel)" % [_profile + 1, InputManager.ACTION_NAMES[action], "key" if kind == "kb" else "gamepad button or stick direction"]
	AudioManager.play("blip", -6.0)


func _end_capture(msg := "") -> void:
	_capturing = {}
	_capture_label.visible = false
	refresh_cells()
	if msg != "":
		AudioManager.play("select", -6.0)


func _assign_key(action: String, key: int) -> void:
	var prof: Dictionary = SaveManager.controls[_profile]
	var kb: Dictionary = prof["kb"]
	var old: int = kb[action]
	# Swap if another action of this player already uses the key.
	for a in InputManager.ACTIONS:
		if a != action and kb[a] == key:
			kb[a] = old
	# The other player's profile loses the key (two players share one keyboard).
	var other: Dictionary = SaveManager.controls[1 - _profile]["kb"]
	for a in InputManager.ACTIONS:
		if other[a] == key and a != "pause":
			other[a] = 0
	kb[action] = key
	SaveManager.save()


func _assign_pad(action: String, ev: Dictionary) -> void:
	var prof: Dictionary = SaveManager.controls[_profile]
	# Free the button if it is used by another action of this player.
	for a in InputManager.ACTIONS:
		if a == action:
			continue
		var kept := []
		for e in prof["pad"][a]:
			if not (e["t"] == ev["t"] and int(e["i"]) == int(ev["i"]) and (ev["t"] == "b" or float(e.get("v", 1.0)) == float(ev.get("v", 1.0)))):
				kept.append(e)
		prof["pad"][a] = kept
	prof["pad"][action] = [ev]
	SaveManager.save()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if InputManager.is_duplicate(event):
		return   # the same press from a mirrored (virtual) gamepad
	if not _capturing.is_empty():
		get_viewport().set_input_as_handled()
		if _capture_t < 0.25:
			return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE:
				_end_capture()
			elif _capturing["kind"] == "kb":
				_assign_key(_capturing["action"], event.physical_keycode)
				_end_capture("ok")
		elif _capturing["kind"] == "pad":
			if event is InputEventJoypadButton and event.pressed:
				_assign_pad(_capturing["action"], {"t": "b", "i": int(event.button_index)})
				_end_capture("ok")
			elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.7 and event.axis not in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
				_assign_pad(_capturing["action"], {"t": "a", "i": int(event.axis), "v": signf(event.axis_value)})
				_end_capture("ok")
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back.emit()


func select_tab(i: int, focus := true) -> void:
	_game_box.visible = i == 0
	_controls_box.visible = i == 1
	_tab_game.text = ("● " if i == 0 else "○ ") + "Game Settings"
	_tab_controls.text = ("● " if i == 1 else "○ ") + "Controls"
	_update_labels()
	refresh_cells()
	if focus:
		(_tab_game if i == 0 else _tab_controls).call_deferred("grab_focus")


func open() -> void:
	visible = true
	InputManager.freeze_held()
	select_tab(0, false)
	_capturing = {}
	_capture_label.visible = false
	_tab_game.call_deferred("grab_focus")


func _process(delta: float) -> void:
	if not visible:
		return
	_capture_t += delta
	if not _capturing.is_empty() and _capture_t > 8.0:
		_end_capture()
	_test_t -= delta
	if _test_t <= 0.0 and _controls_box.visible:
		_test_t = 0.1
		_update_monitor()


func _update_monitor() -> void:
	var s := ""
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		s = "No gamepad connected.\n(Connect one and press its buttons here to see what it sends.)"
	for dev in pads:
		s += "#%d  %s\n" % [dev, Input.get_joy_name(dev)]
		var btns := []
		for i in JOY_BUTTON_SDL_MAX:
			if Input.is_joy_button_pressed(dev, i):
				btns.append(InputManager.pad_label({"t": "b", "i": i}) + ("*" if InputManager.is_blocked(dev, "b%d" % i) else ""))
		var axes := []
		for ax in JOY_AXIS_SDL_MAX:
			var v := Input.get_joy_axis(dev, ax)
			if absf(v) > 0.3:
				axes.append("%s %.1f" % [InputManager.pad_label({"t": "a", "i": ax, "v": 1.0}).trim_suffix("+"), v])
		s += "  buttons: %s\n  axes: %s\n" % [", ".join(btns) if not btns.is_empty() else "none", ", ".join(axes) if not axes.is_empty() else "none"]
	s += "\n* = held from before, ignored until released"
	_test_label.text = s
