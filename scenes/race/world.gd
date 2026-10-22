class_name World
extends Node2D
## The shared game world: owns the road, the cars and the course, and runs one simulation step per
## physics tick. The work is split over helpers that all read the same lists:
##   course     obstacles and fuel cans (data for the whole course, live nodes near the players)
##   query      what the traffic AI asks about its surroundings
##   traffic    spawning and removing cars, police, ambulances, sirens
##   collisions who touches whom
##   rules      checkpoints, shortcuts, finish, overtakes, out of fuel

signal popup(slot: int, text: String, kind: String)
signal shake(slot: int, strength: float)
signal shortcut_taken(slot: int)
signal player_finished(slot: int)
signal player_out(slot: int)

var stage: StageData
var level: DifficultyLevel     # difficulty settings (see Difficulty)
var level_name := "normal"
var cp_bonus := 25.0           # seconds added at each checkpoint (depends on stage + difficulty)
var start_time := 100.0        # what every player's timer starts at
var road: Road
var running := false
var t := 0.0
var rivals: Array[Rival] = []
var obstacles: Array[Obstacle] = []   # live ones only (see Course), sorted by distance
var pickups: Array[Pickup] = []
var players: Array[PlayerCar] = []
var rng := RandomNumberGenerator.new()

var course: Course
var query: TrafficQuery
var traffic: Traffic
var collisions: Collisions
var rules: RaceRules

var _player_layer: Node2D


func setup(stage_data: StageData) -> void:
	stage = stage_data
	level_name = SaveManager.difficulty
	level = Difficulty.level(level_name)
	var budget := Difficulty.time_budget(stage, level)
	cp_bonus = budget["checkpoint"]
	start_time = budget["start"]
	rng.seed = stage.rng_seed
	seed(rng.seed)   # the global RNG (rivals, shuffles) repeats too, so a run can be replayed exactly
	road = Road.new()
	add_child(road)
	road.setup(stage, rng.randi())
	var obstacle_layer := Node2D.new()
	var pickup_layer := Node2D.new()
	var rival_layer := Node2D.new()
	_player_layer = Node2D.new()
	for l in [obstacle_layer, pickup_layer, rival_layer, _player_layer]:
		add_child(l)
	query = TrafficQuery.new(self)
	course = Course.new(self, obstacle_layer, pickup_layer)
	traffic = Traffic.new(self, rival_layer)
	collisions = Collisions.new(self)
	rules = RaceRules.new(self)
	course.build()
	if OS.is_debug_build():
		var dbg := DebugBoxes.new()
		dbg.world = self
		dbg.z_index = 50
		add_child(dbg)
	if stage.night:
		var cm := CanvasModulate.new()
		cm.color = Color(0.2, 0.24, 0.42)
		add_child(cm)


func add_player(slot: int, color_idx: int, easy: bool, lane: int) -> PlayerCar:
	var p := PlayerCar.new()
	_player_layer.add_child(p)
	p.setup(self, slot, color_idx, easy, lane)
	p.start_time = start_time
	p.time_left = start_time
	p.crashed.connect(_on_player_crashed.bind(p))
	p.respawned.connect(_on_player_respawned.bind(p))
	p.bumped.connect(_on_player_bumped.bind(p))
	p.oil_hit.connect(_on_player_oil_hit)
	players.append(p)
	return p


func begin() -> void:
	# Populate the road ahead of every player before the lights go green.
	course.stream()
	for i in 40:
		traffic.update_traffic(true)
	for p in players:
		AudioManager.engine_start(p.slot)


func wind_at(_d: float) -> float:
	var strength := stage.drift + stage.weather.wind
	if strength <= 0.0:
		return 0.0
	return strength * sin(t * 0.9) * (0.5 + 0.5 * sin(t * 0.37 + 1.0))


## The whole simulation runs on the fixed physics tick, so the game plays at the same speed at any
## frame rate (a slow machine drops frames, not game time).
func _physics_process(delta: float) -> void:
	for p in players:
		p.tick(delta, running)
	if not running:
		return
	t += delta
	course.stream()
	query.resort()
	for r in rivals:
		r.tick(delta)
		query.reposition(r)
	collisions.separate_rivals()
	collisions.resolve()
	rules.update_progress()
	traffic.tick(delta)
	rules.update_players()


# ------------------------------------------------------------ player events

func _on_player_crashed(_reason: String, _impact_speed: float, p: PlayerCar) -> void:
	AudioManager.play("boom")
	AudioManager.play_impact("impactMetal", -2.0)
	popup.emit(p.slot, "CRASH!  -5", "bad")
	shake.emit(p.slot, 14.0)


## A respawned car gets room: whatever stands within reach of it is cleared away.
func _on_player_respawned(p: PlayerCar) -> void:
	course.clear_area(p.d() - 160.0, p.d() + 450.0)


func _on_player_bumped(p: PlayerCar) -> void:
	AudioManager.play_impact("impactGeneric", -2.0)
	AudioManager.play("skid", -4.0)
	popup.emit(p.slot, "BUMP! SLOWDOWN", "bad")
	shake.emit(p.slot, 6.0)


func _on_player_oil_hit() -> void:
	AudioManager.play("skid", -4.0)
