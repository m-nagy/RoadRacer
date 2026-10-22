extends Control
## Race scene: builds the (split-)screen viewports, runs the countdown, pause and end-of-race menus.

const ZOOM := 0.75
const CAM_LEAD := 240.0
const HUD_SCENE := preload("res://scenes/race/hud.tscn")

var world: World
## One player's window onto the shared world.
class View:
	var slot := 0
	var player: PlayerCar
	var viewport: SubViewport
	var camera: Camera2D
	var hud: Hud
	var shake := 0.0


var views: Array[View] = []
var _label: Label
var _menu: Control = null
var _menu_kind := ""
var _ended := false
var _clock := 0.0
var _first_finish := -1.0
var _all_out := -1.0
var _stage_no := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100   # after World has ticked, so the cameras follow this tick's positions
	theme = UiTheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage_no = Game.stage_index + 1

	var slots: Array = Game.active_slots()
	if slots.is_empty():
		Game.players[0].active = true
		InputManager.assign_keyboard(0)
		slots = [0]

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	for i in slots.size():
		var slot: int = slots[i]
		var wrap := Control.new()
		wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		wrap.clip_contents = true
		row.add_child(wrap)
		var cont := SubViewportContainer.new()
		cont.stretch = true
		cont.set_anchors_preset(Control.PRESET_FULL_RECT)
		wrap.add_child(cont)
		var vp := SubViewport.new()
		vp.handle_input_locally = false
		cont.add_child(vp)
		if i == 0:
			world = World.new()
			world.process_mode = Node.PROCESS_MODE_PAUSABLE
			vp.add_child(world)
			world.setup(Game.stage_index)
		else:
			vp.world_2d = views[0].viewport.world_2d
		var cam := Camera2D.new()
		cam.zoom = Vector2(ZOOM, ZOOM)
		cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS   # follows the physics-tick positions
		vp.add_child(cam)
		var wx := Weather.new()
		wx.process_mode = Node.PROCESS_MODE_PAUSABLE   # rain and HUD freeze with the game behind the pause menu
		vp.add_child(wx)
		wx.setup(world.stage.weather)
		var hud: Hud = HUD_SCENE.instantiate()
		hud.process_mode = Node.PROCESS_MODE_PAUSABLE
		hud.world = world
		hud.stage_no = _stage_no
		hud.stage_name = world.stage.name
		wrap.add_child(hud)
		var view := View.new()
		view.slot = slot
		view.viewport = vp
		view.camera = cam
		view.hud = hud
		views.append(view)

	for i in views.size():
		var v := views[i]
		var cfg: PlayerSlot = Game.players[v.slot]
		var lane := 1 if views.size() == 1 else 1 + i
		v.player = world.add_player(v.slot, cfg.color, cfg.easy, lane)
	var all_players: Array = views.map(func(v): return v.player)
	for v in views:
		v.hud.player = v.player
		v.hud.all_players = all_players

	world.popup.connect(_on_popup)
	world.shake.connect(_on_shake)
	world.shortcut_taken.connect(func(slot): _hud_for(slot).fade())
	world.begin()
	AudioManager.prepare_music()

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 120)
	_label.add_theme_constant_override("outline_size", 16)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	_update_cameras(0.0)
	for v in views:
		v.camera.reset_physics_interpolation()
	_run_countdown()


func _hud_for(slot: int) -> Hud:
	for v in views:
		if v.slot == slot:
			return v.hud
	return null


func _on_popup(slot: int, text: String, kind: String) -> void:
	var h := _hud_for(slot)
	if h:
		h.add_popup(text, kind)


func _on_shake(slot: int, strength: float) -> void:
	for v in views:
		if v.slot == slot:
			v.shake = strength


func _run_countdown() -> void:
	_label.add_theme_font_size_override("font_size", 56)
	_label.text = "STAGE %d\n%s" % [_stage_no, world.stage.name.to_upper()]
	await get_tree().create_timer(2.0).timeout
	_label.add_theme_font_size_override("font_size", 150)
	for s in ["3", "2", "1"]:
		_label.text = s
		AudioManager.play("beep")
		await get_tree().create_timer(0.8).timeout
	_label.text = "GO!"
	AudioManager.play("go")
	world.running = true
	AudioManager.play_music()
	await get_tree().create_timer(0.8).timeout
	_label.text = ""


func _physics_process(delta: float) -> void:
	_update_cameras(delta)
	if _ended or _menu != null:
		return
	if not world.running:
		return
	_clock += delta
	var finished := 0
	var out := 0
	var active := 0
	for v in views:
		match v.player.state:
			PlayerCar.State.FINISHED:
				finished += 1
			PlayerCar.State.OUT:
				out += 1
			_:
				active += 1
	if finished > 0:
		if _first_finish < 0.0:
			_first_finish = _clock
		if active == 0 or _clock - _first_finish > 7.0:
			_end_clear()
	elif out == views.size():
		if _all_out < 0.0:
			_all_out = _clock
		if _clock - _all_out > 2.0:
			_end_fail()


func _update_cameras(delta: float) -> void:
	var ranges := []
	for v in views:
		var p: PlayerCar = v.player
		var cam: Camera2D = v.camera
		var d := p.d()
		# Keep the car's place on screen tied to its offset from the road centre, so road bends
		# never make the car appear to slide sideways by itself.
		var cx0 := world.road.center_x(d)
		var tx := cx0 + (p.position.x - cx0) * 0.6
		var shake := Vector2.ZERO
		if v.shake > 0.1:
			shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * v.shake
			v.shake = move_toward(v.shake, 0.0, 40.0 * delta)
		cam.position = Vector2(tx, p.position.y - CAM_LEAD) + shake
		var half_h := 360.0 / ZOOM
		ranges.append(Vector2(-(cam.position.y + half_h) , -(cam.position.y - half_h)))
	world.road.set_view_ranges(ranges)


func _input(event: InputEvent) -> void:
	if _ended:
		return
	if InputManager.is_duplicate(event):
		return   # the same press from a mirrored (virtual) gamepad
	var toggle := false
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		toggle = true
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k == KEY_ESCAPE or k == KEY_P:
			toggle = true
		else:
			for v in views:
				if Game.players[v.slot].kb and InputManager.profile(v.slot)["kb"]["pause"] == k:
					toggle = true
	elif _menu != null and _menu_kind == "pause" and event.is_action_pressed("ui_cancel"):
		toggle = true   # B on a gamepad closes the pause menu too
	if not toggle:
		return
	if _menu == null:
		if world.running:
			open_pause()
	elif _menu_kind == "pause":
		_close_menu()
	get_viewport().set_input_as_handled()


func open_pause() -> void:
	AudioManager.play("blip")
	AudioManager.duck_music(true)
	AudioManager.engines_stop_all()
	_show_menu("pause", "PAUSED", [], [
		["Resume", _close_menu],
		["Restart Stage", func(): Game.go_to_race(Game.stage_index)],
		["Full Screen On / Off", func(): Game.set_fullscreen(not Game.is_fullscreen())],
		["Quit to Title", Game.go_to_title],
	])


func _close_menu() -> void:
	if _menu:
		_menu.queue_free()
		_menu = null
	_menu_kind = ""
	get_tree().paused = false
	AudioManager.duck_music(false)
	for v in views:
		if v.player.state == PlayerCar.State.RACING:
			AudioManager.engine_start(v.slot)


func _show_menu(kind: String, title: String, lines: Array, buttons: Array) -> void:
	_menu_kind = kind
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 56)
	box.add_child(t)
	for line in lines:
		var l := Label.new()
		l.text = line
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 30)
		box.add_child(l)
	var first: Button = null
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(380, 70)
		btn.pressed.connect(b[1])
		box.add_child(btn)
		if first == null:
			first = btn
	add_child(dim)
	_menu = dim
	get_tree().paused = true
	if first:
		first.call_deferred("grab_focus")


func _end_clear() -> void:
	_ended = true
	AudioManager.engines_stop_all()
	AudioManager.stop_music()
	var lines := []
	var best_score := 0
	var is_best := false
	var time_left := 0.0
	for v in views:
		var p: PlayerCar = v.player
		var tag := "P%d" % (v.slot + 1) if views.size() > 1 else "Score"
		if p.state == PlayerCar.State.FINISHED:
			lines.append("%s: %d pts   (%d overtakes, %d crashes)" % [tag, int(p.score), p.overtakes, p.crashes])
			if int(p.score) > best_score:
				best_score = int(p.score)
				time_left = p.time_left
		else:
			lines.append("%s: did not finish  (%d pts)" % [tag, int(p.score)])
	is_best = SaveManager.record_clear(_stage_no, best_score, time_left)
	SaveManager.store_prefs(Game.players)
	if is_best:
		lines.append("NEW BEST!")
	AudioManager.play("goal")
	var buttons := []
	if _stage_no < Game.STAGE_COUNT:
		buttons.append(["Next Stage", func(): Game.go_to_race(Game.stage_index + 1)])
	buttons.append(["Replay Stage", func(): Game.go_to_race(Game.stage_index)])
	buttons.append(["Title", Game.go_to_title])
	var title := "STAGE CLEAR!" if _stage_no < Game.STAGE_COUNT else "ALL STAGES CLEAR!"
	_show_menu("clear", title, lines, buttons)


func _end_fail() -> void:
	_ended = true
	AudioManager.engines_stop_all()
	AudioManager.stop_music()
	AudioManager.play("fail")
	SaveManager.store_prefs(Game.players)
	var lines := []
	for v in views:
		var p: PlayerCar = v.player
		var tag := "P%d" % (v.slot + 1) if views.size() > 1 else "Score"
		lines.append("%s: %d pts" % [tag, int(p.score)])
	_show_menu("fail", "OUT OF FUEL", lines, [
		["Retry Stage", func(): Game.go_to_race(Game.stage_index)],
		["New Game", func(): Game.go_to_race(0)],
		["Title", Game.go_to_title],
	])
