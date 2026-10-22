extends Node
## Player input. Each player slot has a saved control profile (keyboard keys + gamepad bindings,
## see SaveManager.controls). A player plays with either the keyboard (using their slot's keyboard
## keys) or one gamepad (using their slot's gamepad bindings).
##
## Button state is evaluated here every frame (before anything else) instead of through InputMap,
## so buttons that were already held when a pad connected or a screen opened can be ignored until
## they are released ("stuck input" filter).

const ACTIONS := ["left", "right", "up", "down", "slow", "fast", "pause"]
const ACTION_NAMES := {"left": "Left", "right": "Right", "up": "Up", "down": "Down / Brake",
	"slow": "Slow speed", "fast": "Fast speed", "pause": "Pause"}
const AXIS_THRESHOLD := 0.5
const TWIN_MS := 100           # two pads pressing the same input this close together = one controller seen twice

signal pad_connection_changed

var _cur: Array = [{}, {}]     # per slot: action -> bool (this frame)
var _just: Array = [{}, {}]    # per slot: action -> bool (became pressed this frame)
var _blocked: Dictionary = {}  # device -> {"b3": true, "a1-": true} inputs to ignore until released
var _pad_prev: Dictionary = {} # device -> {dir: bool}, for pad_just()
var _pad_just: Dictionary = {}

# Mirror filter: drivers like DS4Windows add a virtual Xbox pad that copies a real PS pad, so every
# press arrives twice. The second copy of a press is dropped, and a pad that copies another one
# twice (press AND release together) is hidden for good.
var _mirror: Dictionary = {}   # device -> true: a copy of another pad, ignored everywhere
var _held: Dictionary = {}     # device -> {input key: was a copy}, for inputs held right now
var _twins: Dictionary = {}    # input key -> {a, b, a_up, b_up, t}: the same input pressed on two pads
var _hits: Dictionary = {}     # "a:b" -> times pad b copied pad a
var _verdict: Dictionary = {}  # event instance id -> bool, so every screen asking about one event agrees


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100   # update button state before any game logic reads it
	for slot in Game.MAX_PLAYERS:
		rebuild(slot)
	Input.joy_connection_changed.connect(_on_joy_changed)
	_setup_menu_keys()
	freeze_held()


## Enter / Space / pad A (Cross) or Start (Options) = OK, Esc / pad B (Circle) = back,
## arrows + WASD / D-pad / left stick = move. (In a race, Start is caught first and pauses.)
func _setup_menu_keys() -> void:
	_ensure_key("ui_accept", KEY_ENTER)
	_ensure_key("ui_accept", KEY_KP_ENTER)
	_ensure_key("ui_accept", KEY_SPACE)
	_ensure_key("ui_cancel", KEY_ESCAPE)
	_ensure_pad_button("ui_accept", JOY_BUTTON_A)
	_ensure_pad_button("ui_accept", JOY_BUTTON_START)
	_ensure_pad_button("ui_cancel", JOY_BUTTON_B)
	var dirs := {"ui_left": [KEY_A, JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0],
		"ui_right": [KEY_D, JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0],
		"ui_up": [KEY_W, JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0],
		"ui_down": [KEY_S, JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0]}
	for act in dirs:
		var d: Array = dirs[act]
		_ensure_key(act, d[0])
		_ensure_pad_button(act, d[1])
		var has_axis := false
		for e in InputMap.action_get_events(act):
			if e is InputEventJoypadMotion and e.axis == d[2] and signf(e.axis_value) == signf(d[3]):
				has_axis = true
		if not has_axis:
			var m := InputEventJoypadMotion.new()
			m.device = -1
			m.axis = d[2]
			m.axis_value = d[3]
			InputMap.action_add_event(act, m)
		InputMap.action_set_deadzone(act, 0.5)


func _ensure_key(action: String, key: Key) -> void:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and (e.physical_keycode == key or e.keycode == key):
			return
	var k := InputEventKey.new()
	k.physical_keycode = key
	InputMap.action_add_event(action, k)


func _ensure_pad_button(action: String, button: JoyButton) -> void:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and e.button_index == button:
			return
	var b := InputEventJoypadButton.new()
	b.device = -1
	b.button_index = button
	InputMap.action_add_event(action, b)


func _input(event: InputEvent) -> void:
	# Screens see input before this autoload, so they call is_duplicate() themselves; this stops the
	# copy before it reaches the GUI (focus moves, button presses).
	if is_duplicate(event):
		get_viewport().set_input_as_handled()
		return
	# Fullscreen toggle works everywhere: F11 or Alt+Enter. F3 shows collision boxes.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F3:
			Game.debug_boxes = not Game.debug_boxes
		if event.physical_keycode == KEY_F11 or (event.physical_keycode == KEY_ENTER and event.alt_pressed):
			Game.set_fullscreen(not Game.is_fullscreen())
			get_viewport().set_input_as_handled()
	# A button that is still held from before must not trigger menus either.
	if event is InputEventJoypadButton and event.pressed and is_blocked(event.device, "b%d" % event.button_index):
		get_viewport().set_input_as_handled()


func _on_joy_changed(device: int, connected: bool) -> void:
	_mirror.erase(device)
	_held.erase(device)
	for k in _hits.keys():
		if k.begins_with("%d:" % device) or k.ends_with(":%d" % device):
			_hits.erase(k)
	if connected:
		_freeze_device(device)
	else:
		_blocked.erase(device)
		for slot in Game.MAX_PLAYERS:
			if Game.players[slot]["device"] == device:
				Game.players[slot]["device"] = -1
				rebuild(slot)
	pad_connection_changed.emit()


# ------------------------------------------------------------ stuck-input filter

## Ignore every pad button / stick direction that is held right now until it is released once.
## Called at start-up, when a pad connects, and when a screen opens.
func freeze_held() -> void:
	for dev in Input.get_connected_joypads():
		_freeze_device(dev)


func _freeze_device(dev: int) -> void:
	var b := {}
	for i in JOY_BUTTON_SDL_MAX:
		if Input.is_joy_button_pressed(dev, i):
			b["b%d" % i] = true
	for ax in JOY_AXIS_SDL_MAX:
		var v := Input.get_joy_axis(dev, ax)
		if absf(v) > AXIS_THRESHOLD:
			b["a%d%s" % [ax, "+" if v > 0.0 else "-"]] = true
	_blocked[dev] = b


func is_blocked(dev: int, key: String) -> bool:
	return _blocked.has(dev) and _blocked[dev].has(key)


func _update_blocked() -> void:
	for dev in _blocked.keys():
		var b: Dictionary = _blocked[dev]
		for k in b.keys():
			var released := false
			if k.begins_with("b"):
				released = not Input.is_joy_button_pressed(dev, int(k.substr(1)))
			else:
				var ax := int(k.substr(1, k.length() - 2))
				var v := Input.get_joy_axis(dev, ax)
				released = (v < AXIS_THRESHOLD) if k.ends_with("+") else (v > -AXIS_THRESHOLD)
			if released:
				b.erase(k)


# ------------------------------------------------------------ per-frame state

func _process(_delta: float) -> void:
	_update_blocked()
	for slot in Game.MAX_PLAYERS:
		for a in ACTIONS:
			var now := _raw_pressed(slot, a)
			_just[slot][a] = now and not _cur[slot].get(a, false)
			_cur[slot][a] = now
	# Generic per-pad directions / buttons (used by the players screen).
	for dev in Input.get_connected_joypads():
		var prev: Dictionary = _pad_prev.get(dev, {})
		var cur := {}
		var j := {}
		for dir in ["left", "right", "up", "down", "a", "b", "start"]:
			cur[dir] = _pad_dir(dev, dir)
			j[dir] = cur[dir] and not prev.get(dir, false)
		_pad_prev[dev] = cur
		_pad_just[dev] = j


func _pad_dir(dev: int, what: String) -> bool:
	match what:
		"left": return _btn(dev, JOY_BUTTON_DPAD_LEFT) or _axis(dev, JOY_AXIS_LEFT_X, -1.0) > AXIS_THRESHOLD
		"right": return _btn(dev, JOY_BUTTON_DPAD_RIGHT) or _axis(dev, JOY_AXIS_LEFT_X, 1.0) > AXIS_THRESHOLD
		"up": return _btn(dev, JOY_BUTTON_DPAD_UP) or _axis(dev, JOY_AXIS_LEFT_Y, -1.0) > AXIS_THRESHOLD
		"down": return _btn(dev, JOY_BUTTON_DPAD_DOWN) or _axis(dev, JOY_AXIS_LEFT_Y, 1.0) > AXIS_THRESHOLD
		"a": return _btn(dev, JOY_BUTTON_A)
		"b": return _btn(dev, JOY_BUTTON_B)
		"start": return _btn(dev, JOY_BUTTON_START)
	return false


## A pad direction / face button that went down this frame ("left", "right", "a", "b", ...).
func pad_just(dev: int, what: String) -> bool:
	return _pad_just.get(dev, {}).get(what, false)


func _btn(dev: int, i: int) -> bool:
	return Input.is_joy_button_pressed(dev, i) and not is_blocked(dev, "b%d" % i)


## How far an axis is pushed in direction `sign` (0..1), ignoring a stuck axis.
func _axis(dev: int, ax: int, sign: float) -> float:
	if is_blocked(dev, "a%d%s" % [ax, "+" if sign > 0.0 else "-"]):
		return 0.0
	return maxf(Input.get_joy_axis(dev, ax) * sign, 0.0)


func _raw_pressed(slot: int, action: String) -> bool:
	var act := action_name(slot, action)
	if Input.is_action_pressed(act):   # e.g. Input.action_press() from the test bot
		return true
	return _strength(slot, action) > AXIS_THRESHOLD


## 0..1 strength of an action from the player's keyboard keys or gamepad.
func _strength(slot: int, action: String) -> float:
	var p: Dictionary = Game.players[slot]
	var prof: Dictionary = profile(slot)
	var best := 0.0
	if p.get("kb", false):
		var key: int = prof["kb"].get(action, 0)
		if key != 0 and Input.is_physical_key_pressed(key):
			best = 1.0
	var dev: int = p["device"]
	if dev >= 0:
		for ev in prof["pad"].get(action, []):
			if ev["t"] == "b":
				if _btn(dev, int(ev["i"])):
					best = 1.0
			else:
				best = maxf(best, _axis(dev, int(ev["i"]), float(ev["v"])))
	return best


func action_name(slot: int, action: String) -> String:
	return "p%d_%s" % [slot, action]


## Read live (not from the per-frame cache) so the physics tick, which can run several times per
## rendered frame, always sees the current state.
func pressed(slot: int, action: String) -> bool:
	return _raw_pressed(slot, action)


func just_pressed(slot: int, action: String) -> bool:
	return _just[slot].get(action, false)


## Steering in -1..1 (analog on a stick, digital otherwise).
func steer(slot: int) -> float:
	var l := maxf(_strength(slot, "left"), Input.get_action_strength(action_name(slot, "left")))
	var r := maxf(_strength(slot, "right"), Input.get_action_strength(action_name(slot, "right")))
	if l < 0.25:
		l = 0.0
	if r < 0.25:
		r = 0.0
	return clampf(r - l, -1.0, 1.0)


# ------------------------------------------------------------ assignment & profiles

func assign_pad(slot: int, device: int) -> void:
	Game.players[slot]["device"] = device
	Game.players[slot]["kb"] = false
	rebuild(slot)


func assign_keyboard(slot: int) -> void:
	Game.players[slot]["device"] = -1
	Game.players[slot]["kb"] = true
	rebuild(slot)


func profile(slot: int) -> Dictionary:
	return SaveManager.controls[slot]


static func default_profile(slot: int) -> Dictionary:
	return ControlDefaults.profile(slot)


## Kept for the test bot and older callers: the pN_* actions exist (without events) so that
## Input.action_press("p0_fast") can drive a car.
func rebuild(slot: int) -> void:
	for a in ACTIONS:
		var act := action_name(slot, a)
		if not InputMap.has_action(act):
			InputMap.add_action(act, 0.4)


# ------------------------------------------------------------ labels

## Short on-screen label for an action of a player: a key name ("G", "Left"...) or pad button.
## Arrow keys return "left"/"right"/"up"/"down" so they can be drawn as arrows.
func label(slot: int, action: String) -> String:
	var p: Dictionary = Game.players[slot]
	if p.get("kb", false):
		return key_label(profile(slot)["kb"].get(action, 0))
	var evs: Array = profile(slot)["pad"].get(action, [])
	return pad_label(evs[0] if not evs.is_empty() else {})


static func key_label(key: int) -> String:
	match key:
		KEY_LEFT: return "left"
		KEY_RIGHT: return "right"
		KEY_UP: return "up"
		KEY_DOWN: return "down"
		KEY_ESCAPE: return "Esc"
		KEY_ENTER: return "Enter"
		KEY_SPACE: return "Space"
		0: return "-"
	return OS.get_keycode_string(key)


static func pad_label(ev: Dictionary) -> String:
	if ev.is_empty():
		return "-"
	if ev["t"] == "a":
		var names := {JOY_AXIS_LEFT_X: "L-Stick X", JOY_AXIS_LEFT_Y: "L-Stick Y", JOY_AXIS_RIGHT_X: "R-Stick X",
			JOY_AXIS_RIGHT_Y: "R-Stick Y", JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"}
		return "%s%s" % [names.get(int(ev["i"]), "Axis %d" % ev["i"]), "+" if ev.get("v", 1.0) > 0.0 else "-"]
	var b := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Back", JOY_BUTTON_LEFT_SHOULDER: "LB",
		JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_DPAD_LEFT: "left", JOY_BUTTON_DPAD_RIGHT: "right", JOY_BUTTON_DPAD_UP: "up", JOY_BUTTON_DPAD_DOWN: "down"}
	return b.get(int(ev["i"]), "Btn %d" % ev["i"])


## Gamepads that should be offered to players: every connected pad except detected copies.
## (A real Xbox pad next to a real PS pad is two controllers; only a pad that copies another one's
## presses is dropped.)
func usable_pads() -> Array:
	return Input.get_connected_joypads().filter(func(d): return not _mirror.has(d))


# ------------------------------------------------------------ mirror filter

## True when this gamepad event is a copy of another pad's input and must be ignored.
## Keyboard events are never copies.
func is_duplicate(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return false
	var id := event.get_instance_id()
	if not _verdict.has(id):
		if _verdict.size() > 64:
			_verdict.clear()
		_verdict[id] = _judge(event)
	return _verdict[id]


func _judge(event: InputEvent) -> bool:
	var dev: int = event.device
	if _mirror.has(dev):
		return true
	if not _held.has(dev):
		_held[dev] = {}
	var held: Dictionary = _held[dev]
	var now := Time.get_ticks_msec()
	if event is InputEventJoypadButton:
		var key := "b%d" % event.button_index
		return _press(dev, key, now) if event.pressed else _release(dev, key, now)
	var ax: int = event.axis
	if ax == JOY_AXIS_TRIGGER_LEFT or ax == JOY_AXIS_TRIGGER_RIGHT:
		return false
	var plus := "a%d+" % ax
	var minus := "a%d-" % ax
	if absf(event.axis_value) <= AXIS_THRESHOLD:
		var copy := false
		for k in [plus, minus]:
			if held.has(k):
				copy = _release(dev, k, now) or copy
		return copy
	var key := plus if event.axis_value > 0.0 else minus
	if held.has(key):
		return held[key]   # stick still pushed: same verdict as when it was first pushed
	return _press(dev, key, now)


func _press(dev: int, key: String, now: int) -> bool:
	var t: Dictionary = _twins.get(key, {})
	var copy: bool = not t.is_empty() and t["b"] == -1 and t["a"] != dev and now - t["t"] <= TWIN_MS
	if copy:
		t["b"] = dev
	else:
		_twins[key] = {"a": dev, "b": -1, "a_up": -1, "b_up": -1, "t": now}
	_held[dev][key] = copy
	return copy


func _release(dev: int, key: String, now: int) -> bool:
	var copy: bool = _held.get(dev, {}).get(key, false)
	_held.get(dev, {}).erase(key)
	var t: Dictionary = _twins.get(key, {})
	if t.is_empty():
		return copy
	if t["b"] == -1:
		if dev == t["a"]:
			# Pressed on its own: no other pad copied it, so start counting from zero again.
			_twins.erase(key)
			for k in _hits.keys():
				if k.begins_with("%d:" % dev) or k.ends_with(":%d" % dev):
					_hits.erase(k)
		return copy
	if dev == t["a"]:
		t["a_up"] = now
	elif dev == t["b"]:
		t["b_up"] = now
	if t["a_up"] >= 0 and t["b_up"] >= 0:
		_twins.erase(key)
		if absi(t["a_up"] - t["b_up"]) <= TWIN_MS:
			_twin_hit(t["a"], t["b"])
	return copy


## Pad b pressed and released an input together with pad a. Twice in a row = b (or a) is a copy.
func _twin_hit(a: int, b: int) -> void:
	var k := "%d:%d" % [a, b]
	_hits[k] = _hits.get(k, 0) + 1
	if _hits[k] < 2:
		return
	# Hide the virtual pad: when a PS pad is copied by an Xbox-style pad, the Xbox one is the copy.
	var hide := b
	if pad_style(b) == "ps" and pad_style(a) != "ps":
		hide = a
	_mirror[hide] = true
	_held.erase(hide)
	print("[input] gamepad #%d (%s) copies another pad; ignoring it" % [hide, Input.get_joy_name(hide)])
	pad_connection_changed.emit()


## "ps" for PlayStation pads, otherwise "xbox".
func pad_style(dev: int) -> String:
	var n := Input.get_joy_name(dev).to_lower()
	for k in ["ps4", "ps5", "playstation", "dualshock", "dualsense", "wireless controller", "sony"]:
		if n.contains(k):
			return "ps"
	return "xbox"
