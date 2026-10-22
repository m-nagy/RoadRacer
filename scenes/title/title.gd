extends Control
## Home screen and menu flow:
##   Home -> (Stage Select) -> Players -> Cars -> race;  Home -> Options.
## Keyboard: arrows / W A S D move, Enter confirms, Esc goes back.
## Gamepad: D-pad or left stick moves, A confirms, B goes back.

enum Screen { HOME, STAGES, PLAYERS, CARS, OPTIONS }

var screen := Screen.HOME
var _bg_cars: Array = []
var _scroll := 0.0

@onready var _bg_layer: Node2D = %BgLayer
@onready var _hint: Label = %Hint
@onready var _menu_box: VBoxContainer = %MenuBox
@onready var stage_select: StageSelect = %StageSelect
@onready var players_screen: PlayersScreen = %PlayersScreen
@onready var _cars: CarScreen = %CarScreen
@onready var options_screen: OptionsScreen = %OptionsScreen


func _init() -> void:
	theme = UiTheme.make()   # before the child screens get ready


func _ready() -> void:
	if not Game.prefs_applied:
		Game.prefs_applied = true
		for i in Game.MAX_PLAYERS:
			Game.players[i].color = SaveManager.prefs[i]["color"]
			Game.players[i].easy = SaveManager.prefs[i]["easy"]
	_build_background()
	_setup_menu()
	stage_select.picked.connect(_pick_stage)
	stage_select.back.connect(func(): show_screen(Screen.HOME))
	players_screen.finished.connect(func(): show_screen(Screen.CARS))
	players_screen.back.connect(func(): show_screen(Screen.HOME))
	_cars.finished.connect(_start_race)
	_cars.back.connect(func(): show_screen(Screen.PLAYERS))
	options_screen.back.connect(func(): show_screen(Screen.HOME))
	show_screen(Screen.HOME)
	AudioManager.engines_stop_all()
	AudioManager.play_music(0)
	AudioManager.apply_volumes()


# ------------------------------------------------------------ building

func _build_background() -> void:
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


## The menu buttons are in title.tscn; this fills in the texts that depend on the save and wires them up.
func _setup_menu() -> void:
	var cont := SaveManager.continue_id()
	var continue_button: Button = %Continue
	continue_button.text = "Continue  -  %s: %s" % [Stages.label(cont).capitalize(), Stages.by_id(cont).name]
	continue_button.pressed.connect(func(): _pick_stage(cont))
	_menu_box.get_node("NewGame").pressed.connect(func(): _pick_stage(Stages.CAMPAIGN[0].id))
	_menu_box.get_node("StageSelectButton").pressed.connect(func(): show_screen(Screen.STAGES))
	_menu_box.get_node("OptionsButton").pressed.connect(func(): show_screen(Screen.OPTIONS))
	_menu_box.get_node("Fullscreen").pressed.connect(func():
		Game.set_fullscreen(not Game.is_fullscreen())
		_update_fullscreen_label())
	_menu_box.get_node("Quit").pressed.connect(func(): get_tree().quit())
	for b in _menu_box.get_children():
		b.focus_entered.connect(func(): AudioManager.play("blip", -6.0))


func _update_fullscreen_label() -> void:
	var b: Button = _menu_box.get_node("Fullscreen")
	b.text = "Full Screen:  %s   (F11)" % ("ON" if Game.is_fullscreen() else "OFF")


# ------------------------------------------------------------ flow

func show_screen(s: Screen) -> void:
	screen = s
	InputManager.freeze_held()
	_menu_box.get_parent().visible = s == Screen.HOME
	stage_select.visible = s == Screen.STAGES
	players_screen.visible = s == Screen.PLAYERS
	_cars.visible = s == Screen.CARS
	options_screen.visible = s == Screen.OPTIONS
	match s:
		Screen.HOME:
			_hint.text = "Move: arrows / D-pad / stick      Enter / A / Cross = choose"
			_update_fullscreen_label()
			%Continue.call_deferred("grab_focus")
		Screen.STAGES:
			_hint.text = "Pick a stage      Enter / A / Cross = choose      Esc / B / Circle = back"
			stage_select.open()
		Screen.PLAYERS:
			_hint.text = "Move a controller to Player 1 or 2      Enter / A / Cross = go on      Esc / B / Circle = back"
			players_screen.open()
		Screen.CARS:
			_hint.text = "Pick your car      Enter = start      Esc / B / Circle = back"
			_cars.open()
		Screen.OPTIONS:
			_hint.text = "Move: arrows / D-pad / stick      Enter / A / Cross = choose      Esc / B / Circle = back"
			options_screen.open()


func _pick_stage(id: String) -> void:
	Game.pending_stage_id = id
	show_screen(Screen.PLAYERS)


func _start_race() -> void:
	SaveManager.store_prefs(Game.players)
	AudioManager.play("go", -6.0)
	Game.go_to_race(Game.pending_stage_id)


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
