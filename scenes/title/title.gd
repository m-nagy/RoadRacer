extends Control
## Home screen and menu flow:
##   Home -> (Stage Select) -> Players -> Cars -> race;  Home -> Options.
## Keyboard: arrows / W A S D move, Enter confirms, Esc goes back.
## Gamepad: D-pad or left stick moves, A confirms, B goes back.

enum Screen { HOME, STAGES, PLAYERS, CARS, OPTIONS }

var screen := Screen.HOME
var _menu_box: VBoxContainer
var _stage_box: Control
var _hint: Label
var _bg_cars: Array = []
var _bg_layer: Node2D
var _scroll := 0.0
var players_screen: PlayersScreen
var _cars: CarScreen
var options_screen: OptionsScreen


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if not Game.prefs_applied:
		Game.prefs_applied = true
		for i in Game.MAX_PLAYERS:
			Game.players[i].color = SaveManager.prefs[i]["color"]
			Game.players[i].easy = SaveManager.prefs[i]["easy"]
	_build_background()
	_build_header()
	_build_menu()
	_build_stages()
	players_screen = PlayersScreen.new()
	players_screen.finished.connect(func(): show_screen(Screen.CARS))
	players_screen.back.connect(func(): show_screen(Screen.HOME))
	add_child(players_screen)
	_cars = CarScreen.new()
	_cars.finished.connect(_start_race)
	_cars.back.connect(func(): show_screen(Screen.PLAYERS))
	add_child(_cars)
	options_screen = OptionsScreen.new()
	options_screen.back.connect(func(): show_screen(Screen.HOME))
	add_child(options_screen)
	show_screen(Screen.HOME)
	AudioManager.engines_stop_all()
	AudioManager.play_music(0)
	AudioManager.apply_volumes()


# ------------------------------------------------------------ building

func _build_background() -> void:
	_bg_layer = Node2D.new()
	add_child(_bg_layer)
	var kinds := ["taxi", "van", "pickup", "viper", "police", "truck", "fuelcar"]
	for i in 9:
		var s := Sprite2D.new()
		var k: String = kinds[i % kinds.size()]
		s.texture = CarDefs.KINDS[k].texture
		s.scale = Vector2.ONE * CarDefs.KINDS[k].scale * 1.5
		s.modulate = Color(1, 1, 1, 0.9)
		var lane := i % 5
		s.position = Vector2(190.0 + lane * 225.0, randf_range(0.0, 900.0))
		s.set_meta("speed", randf_range(120.0, 320.0))
		_bg_layer.add_child(s)
		_bg_cars.append(s)


func _draw() -> void:
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), Color("2a3b5c"))
	# Asphalt with scrolling lane dashes
	var road_x := sz.x * 0.5 - 600.0
	draw_rect(Rect2(road_x - 20, 0, 1240, sz.y), Color("d9d9d9"))
	draw_rect(Rect2(road_x, 0, 1200, sz.y), Color("3d3f45"))
	for lane in range(1, 5):
		var x := road_x + lane * 225.0 - 112.0
		var y := fposmod(_scroll, 120.0) - 120.0
		while y < sz.y:
			draw_rect(Rect2(x - 4, y, 8, 60), Color(1, 1, 1, 0.55))
			y += 120.0


func _build_header() -> void:
	var banner := TextureRect.new()
	banner.texture = load("res://assets/ui/banner_hanging.png")
	banner.stretch_mode = TextureRect.STRETCH_SCALE
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -300.0
	banner.offset_right = 300.0
	banner.offset_top = 6.0
	banner.offset_bottom = 156.0
	add_child(banner)
	var title := Label.new()
	title.text = "ROAD RACER"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_constant_override("outline_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -300.0
	title.offset_right = 300.0
	title.offset_top = 14.0
	title.offset_bottom = 124.0
	add_child(title)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -44
	_hint.offset_bottom = -8
	add_child(_hint)


func _centered_box(name_: String) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.name = name_
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.offset_top = 165
	cc.offset_bottom = -52
	add_child(cc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	cc.add_child(box)
	return box


func _menu_button(box: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(620, 64)
	b.pressed.connect(cb)
	b.focus_entered.connect(func(): AudioManager.play("blip", -6.0))
	box.add_child(b)
	return b


func _build_menu() -> void:
	_menu_box = _centered_box("MenuBox")
	var cont: int = SaveManager.unlocked
	_menu_button(_menu_box, "Continue  -  Stage %d: %s" % [cont, Stages.get_stage(cont - 1).name], func(): _pick_stage(cont - 1)).name = "Continue"
	_menu_button(_menu_box, "New Game  -  from Stage 1", func(): _pick_stage(0))
	_menu_button(_menu_box, "Stage Select", func(): show_screen(Screen.STAGES))
	_menu_button(_menu_box, "Options", func(): show_screen(Screen.OPTIONS))
	var fs := _menu_button(_menu_box, "", func(): pass)
	fs.name = "Fullscreen"
	fs.pressed.connect(func():
		Game.set_fullscreen(not Game.is_fullscreen())
		_update_fullscreen_label())
	_menu_button(_menu_box, "Quit", func(): get_tree().quit())
	_update_fullscreen_label()
	_menu_box.get_parent().visible = false


func _build_stages() -> void:
	var cc := CenterContainer.new()
	cc.name = "StageBox"
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.offset_top = 170
	cc.offset_bottom = -52
	add_child(cc)
	_stage_box = cc
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	cc.add_child(v)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	v.add_child(grid)
	for i in Game.STAGE_COUNT:
		var st := Stages.get_stage(i)
		var unlocked: bool = i < SaveManager.unlocked
		var best := SaveManager.best_score(i + 1)
		var b := Button.new()
		b.text = "%d. %s\n%s" % [i + 1, st.name, ("Best: %d" % best) if unlocked and best > 0 else ("" if unlocked else "Locked")]
		b.custom_minimum_size = Vector2(360, 120)
		b.disabled = not unlocked
		b.add_theme_font_size_override("font_size", 26)
		var idx := i
		b.pressed.connect(func(): _pick_stage(idx))
		grid.add_child(b)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(300, 64)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): show_screen(Screen.HOME))
	v.add_child(back)
	_stage_box.visible = false


func _update_fullscreen_label() -> void:
	var b: Button = _menu_box.get_node("Fullscreen")
	b.text = "Full Screen:  %s   (F11)" % ("ON" if Game.is_fullscreen() else "OFF")


# ------------------------------------------------------------ flow

func show_screen(s: Screen) -> void:
	screen = s
	InputManager.freeze_held()
	_menu_box.get_parent().visible = s == Screen.HOME
	_stage_box.visible = s == Screen.STAGES
	players_screen.visible = s == Screen.PLAYERS
	_cars.visible = s == Screen.CARS
	options_screen.visible = s == Screen.OPTIONS
	match s:
		Screen.HOME:
			_hint.text = "Move: arrows / D-pad / stick      Enter / A / Cross = choose"
			_update_fullscreen_label()
			_menu_box.get_node("Continue").call_deferred("grab_focus")
		Screen.STAGES:
			_hint.text = "Pick a stage      Enter / A / Cross = choose      Esc / B / Circle = back"
			var grid := _stage_box.get_child(0).get_child(0)
			for b in grid.get_children():
				if not b.disabled:
					b.call_deferred("grab_focus")
					break
		Screen.PLAYERS:
			_hint.text = "Move a controller to Player 1 or 2      Enter / A / Cross = go on      Esc / B / Circle = back"
			players_screen.open()
		Screen.CARS:
			_hint.text = "Pick your car      Enter = start      Esc / B / Circle = back"
			_cars.open()
		Screen.OPTIONS:
			_hint.text = "Move: arrows / D-pad / stick      Enter / A / Cross = choose      Esc / B / Circle = back"
			options_screen.open()


func _pick_stage(stage: int) -> void:
	Game.pending_stage = stage
	show_screen(Screen.PLAYERS)


func _start_race() -> void:
	SaveManager.store_prefs(Game.players)
	AudioManager.play("go", -6.0)
	Game.go_to_race(Game.pending_stage)


func _input(event: InputEvent) -> void:
	if InputManager.is_duplicate(event):
		return   # the same press from a mirrored (virtual) gamepad
	if screen == Screen.STAGES and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		show_screen(Screen.HOME)


func _process(delta: float) -> void:
	_scroll += delta * 260.0
	for s in _bg_cars:
		s.position.y -= s.get_meta("speed") * delta
		if s.position.y < -150.0:
			s.position.y = size.y + 150.0
	queue_redraw()
