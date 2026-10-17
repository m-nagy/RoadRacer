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

var _tab_game: Button
var _tab_controls: Button
var _game_box: Control
var _controls_box: Control
var _diff_buttons: Dictionary = {}
var _diff_label: Label
var _fs_button: Button
var _profile := 0
var _profile_buttons: Array = []
var _cells: Dictionary = {}   # "kb:left" -> Button
var _capture_label: Label
var _capturing := {}
var _capture_t := 0.0
var _test_label: Label
var _test_t := 0.0
var _first_focus: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.offset_top = 150
	cc.offset_bottom = -52
	add_child(cc)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	cc.add_child(root)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 16)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(tabs)
	_tab_game = _button(tabs, "Game Settings", func(): _select_tab(0), Vector2(300, 56))
	_tab_controls = _button(tabs, "Controls", func(): _select_tab(1), Vector2(300, 56))

	_game_box = _build_game()
	root.add_child(_game_box)
	_controls_box = _build_controls()
	root.add_child(_controls_box)

	_capture_label = Label.new()
	_capture_label.add_theme_font_size_override("font_size", 34)
	_capture_label.add_theme_color_override("font_color", Color("ffe36e"))
	_capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_capture_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_capture_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capture_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capture_label.visible = false
	add_child(_capture_label)
	_select_tab(0, false)


func _button(parent: Control, text: String, cb: Callable, min_size := Vector2(0, 52)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(cb)
	b.focus_entered.connect(func(): AudioManager.play("blip", -8.0))
	parent.add_child(b)
	return b


func _label(parent: Control, text: String, size := 24, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


# ------------------------------------------------------------ game settings tab

func _build_game() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(860, 0)
	box.add_theme_constant_override("separation", 12)
	_label(box, "Difficulty", 30, Color("ffd7a0"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for d in ["easy", "normal", "hard"]:
		var key: String = d
		var b := _button(row, "", func(): _set_difficulty(key), Vector2(270, 62))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_diff_buttons[key] = b
	_diff_label = _label(box, "", 22, Color("c8e6ff"))
	_diff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diff_label.custom_minimum_size = Vector2(860, 64)

	_slider_row(box, "Music volume", SaveManager.music_volume, func(v):
		SaveManager.music_volume = v
		AudioManager.apply_volumes()
		SaveManager.save())
	_slider_row(box, "Sound effects", SaveManager.sfx_volume, func(v):
		SaveManager.sfx_volume = v
		AudioManager.apply_volumes()
		SaveManager.save()
		AudioManager.play("select"))
	_fs_button = _button(box, "", func():
		Game.set_fullscreen(not Game.is_fullscreen())
		_update_labels(), Vector2(0, 56))
	var back_btn := _button(box, "Back", func(): back.emit(), Vector2(0, 56))
	back_btn.name = "BackGame"
	return box


func _slider_row(parent: Control, text: String, value: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var l := _label(row, text, 26)
	l.custom_minimum_size = Vector2(260, 0)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(420, 40)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(cb)
	row.add_child(s)
	var pct := _label(row, "%d%%" % int(value * 100), 24)
	s.value_changed.connect(func(v): pct.text = "%d%%" % int(v * 100))


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


# ------------------------------------------------------------ controls tab

func _build_controls() -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	box.add_child(left)

	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 12)
	left.add_child(prow)
	for i in 2:
		var idx := i
		var b := _button(prow, "Player %d" % (i + 1), func(): _select_profile(idx), Vector2(190, 44))
		b.add_theme_font_size_override("font_size", 22)
		UiTheme.compact(b, 40)
		_profile_buttons.append(b)
	var rb := _button(prow, "Reset defaults", func():
		SaveManager.reset_controls(_profile)
		_refresh_cells(), Vector2(210, 44))
	rb.add_theme_font_size_override("font_size", 22)
	UiTheme.compact(rb, 40)
	var bb := _button(prow, "Back", func(): back.emit(), Vector2(130, 44))
	bb.add_theme_font_size_override("font_size", 22)
	UiTheme.compact(bb, 40)
	bb.name = "BackControls"

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 3)
	left.add_child(grid)
	_label(grid, "Action", 22, Color("ffd7a0")).custom_minimum_size = Vector2(190, 0)
	_label(grid, "Keyboard", 22, Color("ffd7a0")).custom_minimum_size = Vector2(190, 0)
	_label(grid, "Gamepad", 22, Color("ffd7a0")).custom_minimum_size = Vector2(250, 0)
	for a in InputManager.ACTIONS:
		var act: String = a
		_label(grid, InputManager.ACTION_NAMES[act], 22)
		_cells["kb:" + act] = _button(grid, "", func(): _start_capture("kb", act), Vector2(190, 36))
		_cells["pad:" + act] = _button(grid, "", func(): _start_capture("pad", act), Vector2(250, 36))
		_cells["kb:" + act].add_theme_font_size_override("font_size", 22)
		_cells["pad:" + act].add_theme_font_size_override("font_size", 22)
		UiTheme.compact(_cells["kb:" + act])
		UiTheme.compact(_cells["pad:" + act])

	# Live controller monitor: shows exactly what each connected pad reports.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	box.add_child(right)
	_label(right, "Controller monitor", 22, Color("ffd7a0"))
	_test_label = _label(right, "", 16, Color("d8e4f0"))
	_test_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_test_label.custom_minimum_size = Vector2(380, 340)
	return box


func _select_profile(i: int) -> void:
	_profile = i
	_refresh_cells()


func _refresh_cells() -> void:
	for i in _profile_buttons.size():
		_profile_buttons[i].text = ("● " if i == _profile else "○ ") + "Player %d" % (i + 1)
	var prof: Dictionary = SaveManager.controls[_profile]
	for a in InputManager.ACTIONS:
		var kl := InputManager.key_label(prof["kb"].get(a, 0))
		_cells["kb:" + a].text = {"left": "← Left", "right": "→ Right", "up": "↑ Up", "down": "↓ Down"}.get(kl, kl)
		var evs: Array = prof["pad"].get(a, [])
		var names: Array = evs.map(func(e): return InputManager.pad_label(e))
		_cells["pad:" + a].text = " / ".join(names) if not names.is_empty() else "-"


func _start_capture(kind: String, action: String) -> void:
	_capturing = {"kind": kind, "action": action}
	_capture_t = 0.0
	_capture_label.visible = true
	_capture_label.text = "Player %d - %s\n\nPress a %s…\n(Esc = cancel)" % [_profile + 1, InputManager.ACTION_NAMES[action], "key" if kind == "kb" else "gamepad button or stick direction"]
	AudioManager.play("blip", -6.0)


func _end_capture(msg := "") -> void:
	_capturing = {}
	_capture_label.visible = false
	_refresh_cells()
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


func _select_tab(i: int, focus := true) -> void:
	_game_box.visible = i == 0
	_controls_box.visible = i == 1
	_tab_game.text = ("● " if i == 0 else "○ ") + "Game Settings"
	_tab_controls.text = ("● " if i == 1 else "○ ") + "Controls"
	_update_labels()
	_refresh_cells()
	if focus:
		(_tab_game if i == 0 else _tab_controls).call_deferred("grab_focus")


func open() -> void:
	visible = true
	InputManager.freeze_held()
	_select_tab(0, false)
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
