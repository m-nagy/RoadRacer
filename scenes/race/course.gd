class_name Course
extends RefCounted
## The road course itself: where every obstacle and fuel can sits (plain data, built once from the
## stage), and the live nodes for the ones near the players (created and freed as the players drive).

## One obstacle or fuel can on the course.
class CourseSpec:
	var kind := ""
	var pos := Vector2.ZERO
	var d := 0.0


const COURSE_BEHIND := 1300.0   # live course objects reach this far behind the rearmost player...
const COURSE_AHEAD := 3600.0    # ...and this far ahead of the front one (more than traffic can see)

var world: World
var road: Road
var stage: StageData
var level: DifficultyLevel
var rng: RandomNumberGenerator
var rivals: Array[Rival]
var obstacles: Array[Obstacle]   # live nodes only, sorted by distance
var pickups: Array[Pickup]
var players: Array[PlayerCar]
var obstacle_layer: Node2D
var pickup_layer: Node2D

var pickups_total := 0
var pickups_taken := 0

var _obstacle_specs: Array[CourseSpec] = []
var _pickup_specs: Array[CourseSpec] = []
var _obstacle_next := 0         # first spec not yet streamed in
var _pickup_next := 0


func _init(w: World, obstacle_parent: Node2D, pickup_parent: Node2D) -> void:
	world = w
	road = w.road
	stage = w.stage
	level = w.level
	rng = w.rng
	rivals = w.rivals
	obstacles = w.obstacles
	pickups = w.pickups
	players = w.players
	obstacle_layer = obstacle_parent
	pickup_layer = pickup_parent


func build() -> void:
	var ob := stage.obstacles
	var kinds := ob.kinds
	var length := stage.length
	var blocked_rows: Array = []  # [d, lane]
	var density: float = ob.density * level.obstacles
	if density > 0.0 and not kinds.is_empty():
		var d := 1600.0
		while d < length - 900.0:
			d += rng.randf_range(0.7, 1.3) * 1000.0 / (density * 1.6)
			if _near_marker(d):
				continue
			var n := road.lane_count(d)
			var count := 1  # never more than one obstacle per row
			var lanes := range(n)
			lanes.shuffle()
			for k in count:
				var lane: int = lanes[k]
				var spec := CourseSpec.new()
				spec.kind = kinds[rng.randi() % kinds.size()]
				spec.pos = Vector2(road.lane_x(d, lane) + rng.randf_range(-8.0, 8.0), -d)
				spec.d = d
				_obstacle_specs.append(spec)
				blocked_rows.append([d, lane])
	var f := 900.0
	while f < length - 600.0:
		f += rng.randf_range(0.7, 1.3) * Difficulty.fuel_spacing(stage, level)
		if _near_marker(f):
			continue
		var lane2 := rng.randi() % road.lane_count(f)
		var clash := false
		for row in blocked_rows:
			if absf(row[0] - f) < 200.0 and row[1] == lane2:
				clash = true
		if clash:
			continue
		var pk := CourseSpec.new()
		pk.pos = Vector2(road.lane_x(f, lane2), -f)
		pk.d = f
		_pickup_specs.append(pk)
	pickups_total = _pickup_specs.size()


func _near_marker(d: float) -> bool:
	for cp in road.checkpoints:
		if absf(cp - d) < 250.0:
			return true
	return absf(road.length - d) < 500.0


## Keeps live nodes for exactly the course objects within reach of the players: creates the ones
## that came into range, frees the ones left behind. The window only ever moves forward.
func stream() -> void:
	if players.is_empty():
		return
	var lo := 1.0e12
	var hi := -1.0e12
	for p in players:
		lo = minf(lo, p.d() - COURSE_BEHIND)
		hi = maxf(hi, p.d() + COURSE_AHEAD)
	for i in range(obstacles.size() - 1, -1, -1):
		if obstacles[i].d() <= lo:
			obstacles[i].queue_free()
			obstacles.remove_at(i)
	for i in range(pickups.size() - 1, -1, -1):
		if pickups[i].d() <= lo:
			pickups[i].queue_free()
			pickups.remove_at(i)
	while _obstacle_next < _obstacle_specs.size() and _obstacle_specs[_obstacle_next].d < hi:
		var s := _obstacle_specs[_obstacle_next]
		_obstacle_next += 1
		if s.d > lo:
			var o := Obstacle.new()
			obstacle_layer.add_child(o)
			o.setup(s.kind, s.pos)
			obstacles.append(o)
	while _pickup_next < _pickup_specs.size() and _pickup_specs[_pickup_next].d < hi:
		var s2 := _pickup_specs[_pickup_next]
		_pickup_next += 1
		if s2.d > lo:
			var pk := Pickup.new()
			pickup_layer.add_child(pk)
			pk.position = s2.pos
			pickups.append(pk)


## Adds a hazard on the fly (used by the test bot).
func place_obstacle(kind: String, pos: Vector2) -> void:
	var o := Obstacle.new()
	obstacle_layer.add_child(o)
	o.setup(kind, pos)
	obstacles.insert(world.query.first_obstacle_at(o.d()), o)


## Removes traffic and hazards between two distances (used to give a respawned car room).
func clear_area(d_from: float, d_to: float) -> void:
	for r in rivals.duplicate():
		if r.d() > d_from - r.hh and r.d() < d_to + r.hh:
			world.traffic.remove_rival(r)
	for o in obstacles.duplicate():
		if o.d() > d_from and o.d() < d_to:
			obstacles.erase(o)
			o.queue_free()
