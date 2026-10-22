class_name PlayersScreen
extends Control
## "Who plays?" screen. Every input device is an icon in the middle. Move an icon to the left
## (Player 1) or to the right (Player 2). A keyboard moved left uses Player 1's keyboard keys,
## moved right uses Player 2's.
##
## Keyboard 1 moves with A / D, Keyboard 2 with the arrow keys, gamepads with their own D-pad /
## stick. Enter or A continues, Esc or B goes back.

signal finished
signal back

const COL_X := {-1: 260.0, 0: 640.0, 1: 1020.0}

var devices: Array = []   # {id, kind, dev, pos, x, y, shake}
var _font: Font = ThemeDB.fallback_font
var _t := 0.0
var _msg := ""
var _msg_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	InputManager.pad_connection_changed.connect(_refresh_devices)


func open() -> void:
	visible = true
	InputManager.freeze_held()
	_refresh_devices()
	_msg = ""


func _refresh_devices() -> void:
	var keep := {}
	for d in devices:
		keep[d["id"]] = d
	var list: Array = []
	for k in 2:
		list.append({"id": "kb:%d" % k, "kind": "kb", "dev": -1, "kb": k})
	for dev in InputManager.usable_pads():
		list.append({"id": "pad:%d" % dev, "kind": "pad", "dev": dev, "kb": -1})
	var out: Array = []
	for item in list:
		var d: Dictionary = keep.get(item["id"], item)
		if not keep.has(item["id"]):
			d["pos"] = 0
			d["x"] = COL_X[0]
			d["y"] = 0.0
			d["shake"] = 0.0
		out.append(d)
	devices = out


func _slot_device(side: int) -> Dictionary:
	for d in devices:
		if d["pos"] == side:
			return d
	return {}


func _move(d: Dictionary, dir: int) -> void:
	var np := clampi(d["pos"] + dir, -1, 1)
	if np == d["pos"]:
		return
	if np != 0 and not _slot_device(np).is_empty():
		d["shake"] = 1.0
		AudioManager.play("blip", -6.0)
		_flash("That player already has a controller")
		return
	d["pos"] = np
	AudioManager.play("select", -8.0)


func _flash(s: String) -> void:
	_msg = s
	_msg_t = 2.0


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if InputManager.is_duplicate(event):
		return   # the same press from a mirrored (virtual) gamepad
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		for d in devices:
			if d["kind"] != "kb":
				continue
			var lk := KEY_A if d["kb"] == 0 else KEY_LEFT
			var rk := KEY_D if d["kb"] == 0 else KEY_RIGHT
			if k == lk:
				_move(d, -1)
				get_viewport().set_input_as_handled()
				return
			if k == rk:
				_move(d, 1)
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back.emit()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_continue()


func _continue() -> void:
	if _slot_device(-1).is_empty() and _slot_device(1).is_empty():
		_flash("Move a keyboard or gamepad to Player 1 or Player 2 first")
		AudioManager.play("blip", -6.0)
		return
	for slot in 2:
		var d := _slot_device(-1 if slot == 0 else 1)
		var p: PlayerSlot = Game.players[slot]
		p.ready = false
		if d.is_empty():
			p.active = false
			p.device = -1
			p.kb = false
			InputManager.rebuild(slot)
			continue
		p.active = true
		p.color = SaveManager.prefs[slot]["color"]
		p.easy = SaveManager.prefs[slot]["easy"]
		if d["kind"] == "kb":
			InputManager.assign_keyboard(slot)
		else:
			InputManager.assign_pad(slot, d["dev"])
	AudioManager.play("join", -4.0)
	finished.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_msg_t = maxf(0.0, _msg_t - delta)
	for d in devices:
		if d["kind"] == "pad":
			if InputManager.pad_just(d["dev"], "left"):
				_move(d, -1)
			elif InputManager.pad_just(d["dev"], "right"):
				_move(d, 1)
		d["shake"] = maxf(0.0, d["shake"] - delta * 3.0)
		# Centre icons stack vertically (a smaller 2-column grid when there are more than 3);
		# side icons sit in their panel at full size.
		var idx := 0
		var n_mid := 0
		for e in devices:
			if e == d:
				idx = n_mid
			if e["pos"] == 0:
				n_mid += 1
		var tx: float = COL_X[d["pos"]]
		var ty := 360.0
		var tk := 1.0
		if d["pos"] == 0:
			if n_mid <= 3:
				ty = 280.0 + idx * 128.0
			else:
				var rows := ceili(n_mid / 2.0)
				var row_h := minf(150.0, 330.0 / rows)
				tk = minf(0.8, row_h / 165.0)
				tx += -82.0 if idx % 2 == 0 else 82.0
				ty = 250.0 + row_h * (idx / 2 + 0.5)
		var w := 1.0 - exp(-16.0 * delta)
		d["x"] = lerpf(d["x"], tx, w)
		d["y"] = ty if d["y"] == 0.0 else lerpf(d["y"], ty, w)
		d["k"] = tk if not d.has("k") else lerpf(d["k"], tk, w)
	queue_redraw()


func _text(pos: Vector2, s: String, px: int, col: Color, centered := true) -> void:
	var tw := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var p := pos - Vector2(tw * 0.5 if centered else 0.0, 0.0)
	draw_string_outline(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 7, KeyIcons.OUTLINE)
	draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _device_name(d: Dictionary) -> String:
	if d["kind"] == "kb":
		return "Keyboard %d" % (d["kb"] + 1)
	return "Gamepad %d (%s)" % [d["dev"] + 1, "PS" if InputManager.pad_style(d["dev"]) == "ps" else "Xbox"]


func _draw() -> void:
	var panel_a := UiTheme.box("panel_brown_dark.png", 28)
	var panel_b := UiTheme.box("panel_brown_dark.png", 28)
	panel_b.modulate_color = Color(0.55, 0.6, 0.78, 1.0)   # empty slot: a cooler, dimmer panel
	var left := _slot_device(-1)
	var right := _slot_device(1)
	for side in [-1, 1]:
		var filled: bool = not (left if side < 0 else right).is_empty()
		var r := Rect2(COL_X[side] - 190.0, 172.0, 380.0, 410.0)
		draw_style_box(panel_a if filled else panel_b, r)
		var col := Color("ff6a5a") if side < 0 else Color("5ab0ff")
		_text(Vector2(COL_X[side], 222.0), "PLAYER %d" % (1 if side < 0 else 2), 40, col)
		if not filled:
			_text(Vector2(COL_X[side], 372.0), "empty", 28, Color(1, 1, 1, 0.45))
			_text(Vector2(COL_X[side], 410.0), "move a controller here", 20, Color(1, 1, 1, 0.45))
	# Middle column
	_text(Vector2(640, 222.0), "WHO PLAYS?", 30, Color("ffe9b0"))
	for d in devices:
		var c := Vector2(d["x"] + sin(_t * 60.0) * d["shake"] * 10.0, d["y"])
		var k: float = d.get("k", 1.0)
		if d["pos"] == 0:
			_text(Vector2(c.x, c.y + 56.0 * k), _device_name(d), int(19 * maxf(k, 0.85)), Color.WHITE)
		if d["kind"] == "kb":
			KeyIcons.keyboard_icon(self, c, 128.0 * k)
		else:
			KeyIcons.pad_icon(self, c, 130.0 * k, InputManager.pad_style(d["dev"]))
		if d["pos"] != 0:
			_text(Vector2(c.x, c.y + 78.0), _device_name(d), 20, Color.WHITE)
			var slot := 0 if d["pos"] < 0 else 1
			_text(Vector2(c.x, c.y + 108.0), _binding_summary(slot, d), 18, Color("c8e6ff"))
		else:
			# which keys move it
			var hint := "A / D" if d["kind"] == "kb" and d["kb"] == 0 else ("← / →" if d["kind"] == "kb" else "D-pad / stick")
			_text(Vector2(c.x, c.y + 56.0 * k + 20.0), "move: " + hint, 16, Color(1, 1, 1, 0.7))
			var pulse := 0.5 + 0.5 * sin(_t * 5.0)
			var ao := 100.0 if k > 0.95 else 82.0 * k   # grid: keep arrows clear of the next column
			_text(Vector2(c.x - ao, c.y + 8.0 * k), "◀", int(30 * k), Color(1, 1, 1, pulse))
			_text(Vector2(c.x + ao, c.y + 8.0 * k), "▶", int(30 * k), Color(1, 1, 1, pulse))
	if _msg_t > 0.0:
		_text(Vector2(640, 612.0), _msg, 24, Color("ff8a6a"))
	else:
		var ok := not (left.is_empty() and right.is_empty())
		_text(Vector2(640, 612.0), "Enter / A / Cross = continue" if ok else "Move a controller to a player", 24, Color("6dff7a") if ok else Color(1, 1, 1, 0.6))


func _kt(key: int) -> String:
	match key:
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
	return InputManager.key_label(key)


func _binding_summary(slot: int, d: Dictionary) -> String:
	if d["kind"] == "kb":
		var k: Dictionary = InputManager.profile(slot)["kb"]
		return "%s %s %s  slow %s  fast %s" % [_kt(k["left"]), _kt(k["down"]), _kt(k["right"]), _kt(k["slow"]), _kt(k["fast"])]
	var st := InputManager.pad_style(d["dev"])
	var prof: Dictionary = InputManager.profile(slot)["pad"]
	var nm := func(a: String) -> String:
		var evs: Array = prof.get(a, [])
		return KeyIcons.face_name(InputManager.pad_label(evs[0] if not evs.is_empty() else {}), st)
	return "D-pad / stick   slow %s   fast %s" % [nm.call("slow"), nm.call("fast")]
