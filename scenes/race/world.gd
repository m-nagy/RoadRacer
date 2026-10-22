class_name World
extends Node2D
## The shared game world: road, traffic, hazards, pickups, and all race rules.

signal popup(slot: int, text: String, kind: String)
signal shake(slot: int, strength: float)
signal shortcut_taken(slot: int)
signal player_finished(slot: int)
signal player_out(slot: int)

const SCORE_OVERTAKE := 50
const SCORE_FUEL := 500
const SCORE_FUELCAR := 1000
const SCORE_CHECKPOINT := 1000
const TIME_FUEL := 10.0

var stage: Dictionary
var level: Dictionary          # difficulty settings (see Difficulty)
var level_name := "normal"
var cp_bonus := 25.0           # seconds added at each checkpoint (depends on stage + difficulty)
var road: Road
var running := false
var t := 0.0
var rivals: Array = []
var obstacles: Array = []
var pickups: Array = []
var players: Array = []
var rng := RandomNumberGenerator.new()

var _obstacle_layer: Node2D
var _pickup_layer: Node2D
var _rival_layer: Node2D
var _player_layer: Node2D
var _spawn_timer := 0.0
var _ambulance_timer := 18.0
var _fuelcar_timer := 6.0
var _out_notified: Dictionary = {}
var _finished_notified: Dictionary = {}
var pickups_total := 0
var pickups_taken := 0

## Obstacles and fuel cans exist as plain data for the whole course; a node is only created while it
## is within reach of a player (see _stream_course). `obstacles` / `pickups` hold just those live
## nodes, always sorted by distance.
class CourseSpec:
	var kind := ""
	var pos := Vector2.ZERO
	var d := 0.0

const COURSE_BEHIND := 1300.0   # live course objects reach this far behind the rearmost player...
const COURSE_AHEAD := 3600.0    # ...and this far ahead of the front one (more than traffic can see)
const OBSTACLE_MAX_HH := 30.0   # taller than any obstacle's half length (bounds the sorted searches)
const RIVAL_MAX_HH := 64.0      # ...and any rival's

var _obstacle_specs: Array[CourseSpec] = []
var _pickup_specs: Array[CourseSpec] = []
var _obstacle_next := 0         # first spec not yet streamed in
var _pickup_next := 0
var _by_d: Array[Rival] = []    # rivals sorted by distance, kept in step with their live positions


func setup(stage_index: int) -> void:
	stage = Stages.get_stage(stage_index)
	level_name = SaveManager.difficulty
	level = Difficulty.level(level_name)
	cp_bonus = Difficulty.checkpoint_bonus(stage, level)
	rng.seed = 7919 * (stage_index + 1) + 13
	seed(rng.seed)   # the global RNG (rivals, shuffles) repeats too, so a run can be replayed exactly
	road = Road.new()
	add_child(road)
	road.setup(stage, rng.randi())
	_obstacle_layer = Node2D.new()
	_pickup_layer = Node2D.new()
	_rival_layer = Node2D.new()
	_player_layer = Node2D.new()
	for l in [_obstacle_layer, _pickup_layer, _rival_layer, _player_layer]:
		add_child(l)
	_build_course()
	pickups_total = _pickup_specs.size()
	var dbg := DebugBoxes.new()
	dbg.world = self
	dbg.z_index = 50
	add_child(dbg)
	if stage["night"]:
		var cm := CanvasModulate.new()
		cm.color = Color(0.2, 0.24, 0.42)
		add_child(cm)


func add_player(slot: int, color_idx: int, easy: bool, lane: int) -> PlayerCar:
	var p := PlayerCar.new()
	_player_layer.add_child(p)
	p.setup(self, slot, color_idx, easy, lane)
	players.append(p)
	return p


func begin() -> void:
	# Populate the road ahead of every player before the lights go green.
	_stream_course()
	for i in 40:
		_traffic_update(true)
	for p in players:
		AudioManager.engine_start(p.slot)


# ------------------------------------------------------------ course generation

func _build_course() -> void:
	var ob: Dictionary = stage["obstacles"]
	var kinds: Array = ob["kinds"]
	var length: float = stage["length"]
	var blocked_rows: Array = []  # [d, lane]
	var density: float = ob["density"] * level["obstacles"]
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


## Keeps live nodes for exactly the course objects within reach of the players: creates the ones
## that came into range, frees the ones left behind. The window only ever moves forward.
func _stream_course() -> void:
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
			_obstacle_layer.add_child(o)
			o.setup(s.kind, s.pos)
			obstacles.append(o)
	while _pickup_next < _pickup_specs.size() and _pickup_specs[_pickup_next].d < hi:
		var s2 := _pickup_specs[_pickup_next]
		_pickup_next += 1
		if s2.d > lo:
			var pk := Pickup.new()
			_pickup_layer.add_child(pk)
			pk.position = s2.pos
			pickups.append(pk)


## Adds a hazard on the fly (used by the test bot).
func place_obstacle(kind: String, pos: Vector2) -> void:
	var o := Obstacle.new()
	_obstacle_layer.add_child(o)
	o.setup(kind, pos)
	obstacles.insert(_first_obstacle_at(o.d()), o)


## Index of the first live obstacle at or beyond distance x (they are sorted by distance).
func _first_obstacle_at(x: float) -> int:
	var lo := 0
	var hi := obstacles.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if obstacles[mid].d() < x:
			lo = mid + 1
		else:
			hi = mid
	return lo


## Same for rivals.
func _first_rival_at(x: float) -> int:
	var lo := 0
	var hi := _by_d.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if _by_d[mid].d() < x:
			lo = mid + 1
		else:
			hi = mid
	return lo


## Restores the sorted order after any rival has moved (nearly sorted already, so this is cheap).
func _resort_rivals() -> void:
	for i in range(1, _by_d.size()):
		var r := _by_d[i]
		var rd := r.d()
		var j := i - 1
		while j >= 0 and _by_d[j].d() > rd:
			_by_d[j + 1] = _by_d[j]
			j -= 1
		_by_d[j + 1] = r


## Moves one rival that just changed distance to its place in the sorted list.
func _reposition_rival(r: Rival) -> void:
	var i := _by_d.find(r)
	if i < 0:
		return
	var rd := r.d()
	while i + 1 < _by_d.size() and _by_d[i + 1].d() < rd:
		_by_d[i] = _by_d[i + 1]
		i += 1
	while i > 0 and _by_d[i - 1].d() > rd:
		_by_d[i] = _by_d[i - 1]
		i -= 1
	_by_d[i] = r


func _near_marker(d: float) -> bool:
	for cp in road.checkpoints:
		if absf(cp - d) < 250.0:
			return true
	return absf(road.length - d) < 500.0


# ------------------------------------------------------------ queries used by AI

const FOLLOW_DECEL := 300.0   # rivals keep enough distance to stop behind the car ahead at this rate
const FOLLOW_GAP := 18.0       # bumper-to-bumper gap they settle at
const WALL_GAP := 60.0         # lengthwise room left round a car so the player can slip past it
const WALL_LOOK := 450.0       # how far ahead a rival looks for a row it must not complete
const WALL_AHEAD := 120.0      # ...counting what that row is about to draw level with
const POLICE_BEHIND := 470.0   # a called police car enters this far behind the player (just out of view)


## Speed the traffic ahead holds this rival to (-1 if none); used by the autopilot's prediction.
func lead_speed(r: Rival) -> float:
	return r.limit if r.limit < INF else -1.0


## Fastest a rival may go and still stop behind every car ahead that is in (or moving into) its path.
func follow_limit(r: Rival) -> float:
	var rd := r.d()
	var limit := INF
	for i in range(_first_rival_at(rd), _by_d.size()):
		var o := _by_d[i]
		var dy: float = o.d() - rd
		if dy > 700.0:
			break
		if o == r or dy <= 0.0 or not _paths_touch(r, o):
			continue
		var gap: float = dy - o.hh - r.hh - FOLLOW_GAP
		var v: float = o.speed + sqrt(2.0 * FOLLOW_DECEL * gap) if gap > 0.0 else maxf(o.speed - 60.0, 0.0)
		limit = minf(limit, v)
	return limit


## Do two rivals' bodies (where they are, or the lane they are moving into) share any of the road?
func _paths_touch(a: Rival, b: Rival) -> bool:
	var reach: float = a.hw + b.hw + 6.0
	for xa in _path_xs(a):
		for xb in _path_xs(b):
			if absf(xa - xb) < reach:
				return true
	return false


## Sideways offsets from the road centre (comparable between distances, unlike x on a bend).
func _path_xs(r: Rival) -> Array:
	var cx := road.center_x(r.d())
	if r.is_chasing():
		return [r.position.x - cx]
	return [r.position.x - cx, road.lane_x(r.d(), r.intended_lane()) - cx]


## Sideways offset of a car / obstacle from the road centre.
func u_of(n: Node2D) -> float:
	return n.position.x - road.center_x(-n.position.y)


## Lanes a rival takes up: the one it is in, plus the one it is moving or signalling into.
func rival_lanes(r: Rival) -> Array:
	var rd := r.d()
	var a := road.nearest_lane(rd, r.position.x)
	var b := a if r.is_chasing() else r.intended_lane()
	return [a] if a == b else [a, b]


## Lanes taken by cars or obstacles anywhere between two distances (ignoring one rival).
## Cars further back than `min_d` are left out (they give way to us, not we to them).
func lanes_blocked(d_lo: float, d_hi: float, skip: Rival, min_d := -INF) -> Dictionary:
	var used := {}
	for i in range(_first_rival_at(maxf(d_lo - RIVAL_MAX_HH, min_d)), _by_d.size()):
		var o := _by_d[i]
		var od := o.d()
		if od >= d_hi + RIVAL_MAX_HH:
			break
		if o == skip or o.kind == "fuelcar" or od < min_d:
			continue
		if od + o.hh > d_lo and od - o.hh < d_hi:
			for l in rival_lanes(o):
				used[l] = true
	for i in range(_first_obstacle_at(d_lo - OBSTACLE_MAX_HH), obstacles.size()):
		var ob: Obstacle = obstacles[i]
		var obd: float = ob.d()
		if obd >= d_hi + OBSTACLE_MAX_HH:
			break
		if obd + ob.hh > d_lo and obd - ob.hh < d_hi:
			used[road.nearest_lane(obd, ob.position.x)] = true
	return used


## Would this rival, sitting in `lane`, be the car that closes the last open lane round it?
func lane_closes_road(r: Rival, lane: int) -> bool:
	var rd := r.d()
	var n := road.lane_count(rd)
	if n <= 1:
		return false
	var lo := rd - r.hh - WALL_GAP
	var hi := rd + r.hh + WALL_GAP
	if not _car_between(lo, hi, r, -INF):
		return false   # one car beside an obstacle is fine; only cars together close the road
	var used := lanes_blocked(lo, hi, r)
	if used.size() >= n or used.has(lane):
		return false   # not ours to fix: that lane is taken anyway
	return used.size() + 1 >= n


## Is any other car (not counting `skip`, or cars further back than min_d) between two distances?
func _car_between(d_lo: float, d_hi: float, skip: Rival, min_d: float) -> bool:
	for i in range(_first_rival_at(maxf(d_lo - RIVAL_MAX_HH, min_d)), _by_d.size()):
		var o := _by_d[i]
		var od := o.d()
		if od >= d_hi + RIVAL_MAX_HH:
			break
		if o != skip and o.kind != "fuelcar" and od >= min_d and od + o.hh > d_lo and od - o.hh < d_hi:
			return true
	return false


## Speed limit that keeps a rival from drawing level with a moving car ahead when, together with
## whatever else is round that car (or about to be: an obstacle it is passing), they would block every
## lane. It stays behind (or drops back) so the player always has a way through. Cars further ahead
## have priority, so two cars never wait for each other. Standing things (obstacles, stopped cars)
## are never waited for: they stay put, so waiting would only queue up the one lane left open.
func wall_limit(r: Rival) -> float:
	var rd := r.d()
	var n := road.lane_count(rd)
	if n <= 1:
		return INF
	var mine := rival_lanes(r)
	var limit := INF
	for i in range(_first_rival_at(rd), _by_d.size()):
		var o := _by_d[i]
		var dy: float = o.d() - rd
		if dy > WALL_LOOK:
			break
		if o == r or o.kind == "fuelcar" or o.speed < 40.0 or dy <= 0.0:
			continue
		var lo: float = o.d() - o.hh - WALL_GAP
		var used := lanes_blocked(lo, o.d() + o.hh + WALL_GAP + WALL_AHEAD, r, rd)
		if used.size() >= n:
			continue   # closed without us: we are behind someone in our own lane anyway
		var adds := false
		for l in mine:
			if not used.has(l):
				used[l] = true
				adds = true
		if not adds or used.size() < n:
			continue
		var gap: float = lo - (rd + r.hh)
		var v: float = o.speed + sqrt(2.0 * FOLLOW_DECEL * gap) if gap > 0.0 else maxf(o.speed - 70.0, 0.0)
		limit = minf(limit, v)
	return limit


func player_behind(r: Rival, max_dist: float, max_dx: float) -> PlayerCar:
	for p in players:
		if p.state != PlayerCar.State.RACING:
			continue
		var dd: float = r.d() - p.d()
		if dd > -60.0 and dd < max_dist and absf(u_of(p) - u_of(r)) < max_dx:
			return p
	return null


func car_ahead_in_lane(r: Rival, dist: float):
	for o in rivals:
		if o == r:
			continue
		var dy: float = o.d() - r.d()
		if dy > 0.0 and dy < dist and absf(u_of(o) - u_of(r)) < 50.0 and o.speed < r.speed:
			return o
	for p in players:
		var dy2: float = p.d() - r.d()
		if dy2 > 0.0 and dy2 < dist and absf(u_of(p) - u_of(r)) < 50.0 and p.speed < r.speed:
			return p
	return null


func lane_is_clear(r: Rival, lane: int, span: float, ahead := 420.0) -> bool:
	var lx := road.lane_x(r.d(), lane) - road.center_x(r.d())
	for o in rivals:
		if o == r:
			continue
		# Room needed lengthwise grows with the speed difference (a fast car must be able to
		# brake behind a slow one it pulls in behind, and never cut in front of a faster one).
		var dy: float = o.d() - r.d()
		var closing: float = maxf(r.speed - o.speed, 0.0) if dy > 0.0 else maxf(o.speed - r.speed, 0.0)
		if absf(dy) >= span + o.hh + closing * closing / (2.0 * FOLLOW_DECEL):
			continue
		for x in _path_xs(o):   # cars already in that lane, or already moving into it
			if absf(x - lx) < 48.0:
				return false
	for p in players:
		if absf(p.d() - r.d()) < span + 40.0 and absf(u_of(p) - lx) < 48.0:
			return false
	var look := maxf(ahead, 150.0 + r.speed * r.speed / (2.0 * 416.0))
	return not lane_has_obstacle(lane, r.d() - 120.0, r.d() + look)


## Is there an obstacle (any kind, oil included) in this lane between two distances?
func lane_has_obstacle(lane: int, d_from: float, d_to: float) -> bool:
	for i in range(_first_obstacle_at(d_from), obstacles.size()):
		var ob: Obstacle = obstacles[i]
		var od: float = ob.d()
		if od >= d_to:
			break
		if od > d_from and absf(ob.position.x - road.lane_x(od, lane)) < 46.0:
			return true
	return false


## First obstacle ahead that a rival would drive over (in its current or target lane).
func obstacle_ahead(r: Rival, dist: float) -> Obstacle:
	var best: Obstacle = null
	for i in range(_first_obstacle_at(r.d() - OBSTACLE_MAX_HH), obstacles.size()):
		var o: Obstacle = obstacles[i]
		var dy: float = o.d() - r.d()
		if dy > dist + r.hh:
			break
		if dy < -o.hh:
			continue
		var gap: float = r.hw + o.hw + 22.0
		if absf(u_of(o) - u_of(r)) < gap or absf(o.position.x - road.lane_x(o.d(), r.target_lane)) < gap:
			if best == null or o.d() < best.d():
				best = o
	return best


func wind_at(_d: float) -> float:
	var strength: float = stage["drift"]
	if strength <= 0.0:
		return 0.0
	return strength * sin(t * 0.9) * (0.5 + 0.5 * sin(t * 0.37 + 1.0))


## Removes traffic and hazards between two distances (used to give a respawned car room).
func clear_area(d_from: float, d_to: float) -> void:
	for r in rivals.duplicate():
		if r.d() > d_from - r.hh and r.d() < d_to + r.hh:
			_remove_rival(r)
	for o in obstacles.duplicate():
		if o.d() > d_from and o.d() < d_to:
			obstacles.erase(o)
			o.queue_free()


# ------------------------------------------------------------ simulation

## The whole simulation runs on the fixed physics tick, so the game plays at the same speed at any
## frame rate (a slow machine drops frames, not game time).
func _physics_process(delta: float) -> void:
	var dt := delta
	for p in players:
		p.tick(dt, running)
	if not running:
		return
	t += dt
	_stream_course()
	_resort_rivals()
	for r in rivals:
		r.tick(dt)
		_reposition_rival(r)
	_separate_rivals()
	_resolve_collisions()
	_update_progress()
	_spawn_timer -= dt
	if _spawn_timer <= 0.0:
		_spawn_timer = 0.2
		_traffic_update(false)
	_special_spawns(dt)
	_update_sirens()
	for p in players:
		if p.state == PlayerCar.State.RACING:
			AudioManager.engine_set(p.slot, p.speed / PlayerCar.FAST_MAX)
		else:
			AudioManager.engine_set(p.slot, 0.0)
		if p.state == PlayerCar.State.OUT and not _out_notified.has(p.slot):
			_out_notified[p.slot] = true
			AudioManager.engine_stop(p.slot)
			popup.emit(p.slot, "OUT OF FUEL", "bad")
			player_out.emit(p.slot)


## Safety net: rival cars never overlap. A car that slid into another during a lane change goes
## back towards the lane it came from; one that ran into the back of another is held behind it.
func _separate_rivals() -> void:
	for i in rivals.size():
		var a: Rival = rivals[i]
		for j in range(i + 1, rivals.size()):
			var b: Rival = rivals[j]
			var dy: float = b.d() - a.d()
			var oy: float = a.hh + b.hh + 2.0 - absf(dy)
			if oy <= 0.0:
				continue
			var ox: float = a.hw + b.hw + 2.0 - absf(a.position.x - b.position.x)
			if ox <= 0.0:
				continue
			var front: Rival = b if dy > 0.0 else a
			var rear: Rival = a if front == b else b
			if ox < oy:
				# Side by side: whoever is moving sideways gives way.
				var mover: Rival = rear
				for c in [rear, front]:
					if c.is_chasing() or c.is_changing_lane():
						mover = c
						break
				var other: Rival = front if mover == rear else rear
				var dir := signf(mover.position.x - other.position.x)
				if dir == 0.0:
					dir = 1.0
				mover.push_aside(dir, ox)
			else:
				rear.position.y += oy
				rear.speed = minf(rear.speed, front.speed)


func _resolve_collisions() -> void:
	for p in players:
		if p.state != PlayerCar.State.RACING:
			continue
		for r in rivals.duplicate():
			var ov := overlap(p, r.position, r.hw * 0.92, r.hh * 0.95, r.rotation)
			if ov.x <= 0.0 or ov.y <= 0.0:
				continue
			if r.kind == "fuelcar":
				p.activate_super()
				p.score += SCORE_FUELCAR
				popup.emit(p.slot, "SUPER CAR!  15 s", "good")
				AudioManager.play("fuel")
				_remove_rival(r)
				continue
			if p.super_t > 0.0:
				# Unstoppable: other cars are simply knocked out of the way.
				r.kick(1 if r.position.x >= p.position.x else -1)
				continue
			if p.invuln > 0.0:
				continue
			var rel: Vector2 = (r.position - p.position).rotated(-p.rotation)
			var behind_us: bool = rel.y > p.hh * 0.6   # its centre is clearly behind our nose
			var ahead_of_us: bool = rel.y < 0.0
			if ov.x >= ov.y and ahead_of_us and p.speed > r.speed - 30.0:
				p.crash("rear-end " + r.kind)
				break
			var dir := -signf(rel.x)
			if dir == 0.0:
				dir = 1.0
			if behind_us or ov.x < 5.0:
				# Brushed by a car coming from behind, or only grazed: nudge aside, no penalty.
				p.nudge(dir, ov.x)
			else:
				p.bump(dir, ov.x)
				r.ram_done()
		if p.state != PlayerCar.State.RACING:
			continue
		for o in obstacles.duplicate():
			var ov2 := overlap(p, o.position, o.hw * 0.85, o.hh * 0.85, 0.0)
			if ov2.x <= 0.0 or ov2.y <= 0.0:
				continue
			_hit_obstacle(p, o, ov2)
			if p.state != PlayerCar.State.RACING:
				break
		if p.state != PlayerCar.State.RACING:
			continue
		for pk in pickups.duplicate():
			var ov3 := overlap(p, pk.position, pk.hw, pk.hh, 0.0)
			if ov3.x > 0.0 and ov3.y > 0.0:
				p.time_left += TIME_FUEL
				p.score += SCORE_FUEL
				popup.emit(p.slot, "FUEL +10", "good")
				AudioManager.play("fuel")
				pickups.erase(pk)
				pickups_taken += 1
				pk.queue_free()
	# Players nudge each other but never crash.
	if players.size() == 2:
		var a: PlayerCar = players[0]
		var b: PlayerCar = players[1]
		var ovp := overlap(a, b.position, b.hw, b.hh, b.rotation)
		if a.state == PlayerCar.State.RACING and b.state == PlayerCar.State.RACING and ovp.x > 0.0 and ovp.y > 0.0:
			var ox2 := ovp.x
			var oy2 := ovp.y
			if ox2 < oy2:
				var dir2 := signf(a.position.x - b.position.x)
				if dir2 == 0.0:
					dir2 = 1.0
				a.position.x += dir2 * (ox2 * 0.5 + 0.5)
				b.position.x -= dir2 * (ox2 * 0.5 + 0.5)
			else:
				# One is right behind the other: the rear car gets held back.
				var rear: PlayerCar = a if a.position.y > b.position.y else b
				var front: PlayerCar = b if rear == a else a
				rear.position.y += oy2 + 0.5
				rear.speed = minf(rear.speed, front.speed)


## Exact overlap test between player p and another oriented box. Returns (sideways overlap,
## lengthwise overlap) in p's own frame, both > 0 only when the boxes really touch.
func overlap(p: PlayerCar, pos: Vector2, ohw: float, ohh: float, orot: float) -> Vector2:
	# Broad phase: boxes whose bounding circles do not meet cannot touch.
	var reach := Vector2(p.hw, p.hh).length() + Vector2(ohw, ohh).length() + 1.0
	if p.position.distance_squared_to(pos) > reach * reach:
		return Vector2.ZERO
	var a := _corners(p.position, p.rotation, p.hw, p.hh)
	var b := _corners(pos, orot, ohw, ohh)
	if _separated(a, b, p.rotation) or _separated(a, b, orot):
		return Vector2.ZERO  # a separating axis: they do not touch
	var rel := (pos - p.position).rotated(-p.rotation)
	var dr := orot - p.rotation
	var ex := absf(ohw * cos(dr)) + absf(ohh * sin(dr))
	var ey := absf(ohw * sin(dr)) + absf(ohh * cos(dr))
	return Vector2(maxf(p.hw + ex - absf(rel.x), 0.01), maxf(p.hh + ey - absf(rel.y), 0.01))


## Do the two boxes have a gap along either axis of a box turned by `rot`?
func _separated(a: PackedVector2Array, b: PackedVector2Array, rot: float) -> bool:
	var c := cos(rot)
	var s := sin(rot)
	var ax := Vector2(c, s)
	var ay := Vector2(-s, c)
	var ra := _project(a, ax)
	var rb := _project(b, ax)
	if ra.y < rb.x or rb.y < ra.x:
		return true
	ra = _project(a, ay)
	rb = _project(b, ay)
	return ra.y < rb.x or rb.y < ra.x


func _corners(c: Vector2, rot: float, ohw: float, ohh: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(4)
	out[0] = c + Vector2(-ohw, -ohh).rotated(rot)
	out[1] = c + Vector2(ohw, -ohh).rotated(rot)
	out[2] = c + Vector2(ohw, ohh).rotated(rot)
	out[3] = c + Vector2(-ohw, ohh).rotated(rot)
	return out


func _project(pts: PackedVector2Array, axis: Vector2) -> Vector2:
	var lo := INF
	var hi := -INF
	for q in pts:
		var v: float = q.dot(axis)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return Vector2(lo, hi)


## What each obstacle does to a car that hits it.
func _hit_obstacle(p: PlayerCar, o: Obstacle, ov: Vector2) -> void:
	if o.kind == "oil":
		if p.super_t <= 0.0:
			p.hit_oil()
		return
	if p.super_t > 0.0:
		_knock_obstacle(o, p)           # the super car just ploughs through
		AudioManager.play_impact("impactPlate", -6.0)
		return
	if p.invuln > 0.0:
		return
	var dir := signf(p.position.x - o.position.x)
	if dir == 0.0:
		dir = 1.0
	match o.kind:
		"rock":
			p.crash("obstacle rock")
		"snowbank":
			AudioManager.play_impact("impactSoft", -2.0)
			p.hit_snowbank()
			_knock_obstacle(o, p)
			popup.emit(p.slot, "SNOWBANK! SLIDING", "bad")
		"cone":
			AudioManager.play_impact("impactTin", -4.0)
			_knock_obstacle(o, p)
			call_police(p)
		"barrel":
			AudioManager.play_impact("impactMetal", -3.0)
			p.hit_barrel()
			_knock_obstacle(o, p)
			popup.emit(p.slot, "BARREL! STOPPED", "bad")
		"tire":
			AudioManager.play_impact("impactPunch", -4.0)
			p.bump(dir, ov.x)
		_:
			p.crash("obstacle " + o.kind)


## Sends an obstacle flying (it is removed from the course).
func _knock_obstacle(o: Obstacle, p: PlayerCar) -> void:
	obstacles.erase(o)
	var dir := signf(o.position.x - p.position.x)
	if dir == 0.0:
		dir = 1.0 if rng.randf() < 0.5 else -1.0
	var fwd := -p.speed
	match o.kind:
		"cone": o.fly(Vector2(dir * 240.0, fwd * 0.9), 13.0 * dir, 0.9)
		"barrel": o.fly(Vector2(dir * 210.0, fwd * 0.35), 7.0 * dir, 1.8)
		"snowbank": o.fly(Vector2.ZERO, 0.0, 0.55)
		"rock": o.fly(Vector2(dir * 300.0, fwd), 9.0 * dir, 1.0)
		_: o.fly(Vector2(dir * 260.0, fwd * 0.6), 15.0 * dir, 1.0)


## A cone was hit: the police turn up behind that player.
## It drives up from just behind the screen, faster than the player, and side-swipes them.
func call_police(p: PlayerCar) -> void:
	for r in rivals:
		if r.chase == p:
			r.start_chase(p)   # already on the way: it just keeps going for longer
			return
	var d: float = p.d() - POLICE_BEHIND
	if d < 30.0:
		return
	var r := _spawn_rival("police", d, _police_lane(p, d, null))
	r.start_chase(p)
	popup.emit(p.slot, "POLICE CALLED!", "bad")


## A called police car stuck far behind in traffic re-enters just out of view.
func bring_police_closer(r: Rival) -> void:
	if r.dead or r.chase == null or not rivals.has(r):
		return
	var p: PlayerCar = r.chase
	var d: float = p.d() - POLICE_BEHIND
	if r.d() >= d:
		return
	r.place(d, _police_lane(p, d, r))
	r.start_chase(p)


## Lane for a police car entering at d: next to the player's lane if there is room, else the
## roomiest one. Whatever is in the way there is cleared (it is out of view).
func _police_lane(p: PlayerCar, d: float, skip: Rival) -> int:
	var best := 0
	var best_room := -1.0
	var pl := road.nearest_lane(d, p.position.x)
	for lane in _lasting_lanes(d):
		var room := 1.0e9
		for o in rivals:
			if o != skip and absf(o.position.x - road.lane_x(o.d(), lane)) < 48.0:
				room = minf(room, absf(o.d() - d) - o.hh)
		var score := minf(room, 400.0) + (60.0 if absi(lane - pl) == 1 else (30.0 if lane == pl else 0.0))
		if score > best_room:
			best_room = score
			best = lane
	for o in rivals.duplicate():
		if o != skip and absf(o.d() - d) < 150.0 + o.hh and absf(o.position.x - road.lane_x(o.d(), best)) < 48.0:
			_remove_rival(o)
	return best


func _update_progress() -> void:
	for p in players:
		if p.state != PlayerCar.State.RACING:
			continue
		var d: float = p.d()
		while p.next_cp < road.checkpoints.size() and d >= road.checkpoints[p.next_cp]:
			p.next_cp += 1
			p.time_left += cp_bonus
			p.score += SCORE_CHECKPOINT
			popup.emit(p.slot, "CHECKPOINT +%d" % int(cp_bonus), "good")
			AudioManager.play("checkpoint")
		var s := road.strip_at(p.position.x, d)
		if s >= 0 and d >= road.shortcuts[s]["d1"] - 50.0:  # nose reaches the tunnel
			var target: float = road.shortcuts[s]["exit_d"]
			p.teleport_to(target)
			_stream_course()
			p.score += 1000.0
			popup.emit(p.slot, "SHORTCUT!", "good")
			AudioManager.play("whoosh")
			shortcut_taken.emit(p.slot)
			continue
		if d >= road.length:
			p.score += int(p.time_left) * 100
			p.finish()
			AudioManager.engine_stop(p.slot)
			AudioManager.play("goal")
			popup.emit(p.slot, "GOAL!", "good")
			if not _finished_notified.has(p.slot):
				_finished_notified[p.slot] = true
				player_finished.emit(p.slot)
			continue
		# Overtakes
		for r in rivals:
			var ahead: bool = r.d() > d
			if r.was_ahead.get(p.slot, false) and not ahead and r.d() < d - r.hh and not r.passed_by.has(p.slot) and r.kind != "fuelcar":
				r.passed_by[p.slot] = true
				p.overtakes += 1
				p.score += SCORE_OVERTAKE
				AudioManager.play("overtake", -8.0)
			r.was_ahead[p.slot] = ahead


# ------------------------------------------------------------ traffic

## Weight of a rival kind in the traffic mix; the "attacking" cars (they block / ram you)
## appear more or less often depending on the difficulty.
func _kind_weight(k: String) -> float:
	var w: float = stage["traffic"]["mix"][k]
	if k == "viper" or k == "police":
		w *= level["attack"]
	return w


func _pick_kind() -> String:
	var mix: Dictionary = stage["traffic"]["mix"]
	var total := 0.0
	for k in mix:
		if k != "ambulance":
			total += _kind_weight(k)
	var roll := rng.randf() * maxf(total, 0.001)
	for k in mix:
		if k == "ambulance":
			continue
		roll -= _kind_weight(k)
		if roll < 0.0:
			return k
	return "taxi"


func _lanes_occupied(d: float, span: float) -> Array:
	var used := []
	for o in rivals:
		if absf(o.d() - d) < span:
			var l: int = road.nearest_lane(o.d(), o.position.x)
			if not used.has(l):
				used.append(l)
	for ob in obstacles:
		if absf(ob.d() - d) < span:
			var l2: int = road.nearest_lane(ob.d(), ob.position.x)
			if not used.has(l2):
				used.append(l2)
	return used


func _traffic_update(fill: bool) -> void:
	var dens: float = stage["traffic"]["density"]
	for p in players:
		if p.state == PlayerCar.State.OUT or p.state == PlayerCar.State.FINISHED:
			continue
		var pd: float = p.d()
		var lo := pd + (500.0 if fill else 750.0)
		var hi := pd + 1750.0
		if hi > road.length + 200.0:
			continue
		var count := 0
		for r in rivals:
			if r.kind != "ambulance" and r.kind != "fuelcar" and r.d() >= lo and r.d() <= hi:
				count += 1
		var target := int(round(dens * 2.4 * (hi - lo) / 1000.0))
		if count >= target:
			continue
		var d := hi - rng.randf_range(0.0, 140.0) if not fill else rng.randf_range(lo, hi)
		var n := _lasting_lanes(d)
		var used := _lanes_occupied(d, 320.0)
		var free := []
		for l in n:
			if not used.has(l):
				free.append(l)
		if free.size() < 2:
			continue  # keep at least one lane open after we place this car
		var lane: int = free[rng.randi() % free.size()]
		_spawn_rival(_pick_kind(), d, lane)

	# Clean up cars nobody can see any more.
	var min_d := 1.0e12
	var max_d := -1.0e12
	for p in players:
		min_d = minf(min_d, p.d())
		max_d = maxf(max_d, p.d())
	for r in rivals.duplicate():
		if r.d() < min_d - 1000.0 or r.d() > max_d + 2800.0:
			_remove_rival(r)


## Nothing in this lane from just behind d to `ahead` past it (room for a fast car to enter).
func _lane_open_ahead(d: float, lane: int, ahead: float) -> bool:
	var lu := road.lane_x(d, lane) - road.center_x(d)
	for o in rivals:
		if o.d() > d - 150.0 and o.d() < d + ahead and absf(u_of(o) - lu) < 48.0:
			return false
	for ob in obstacles:
		if ob.d() > d - 100.0 and ob.d() < d + ahead + 300.0 and absf(u_of(ob) - lu) < 48.0:
			return false
	return true


## Lanes that exist here and for a while ahead (never spawn a car in a lane that is about to end).
func _lasting_lanes(d: float) -> int:
	var lf := road.lanes_at(d)
	for k in 4:
		lf = minf(lf, road.lanes_at(d + 250.0 * (k + 1)))
	return maxi(1, int(floor(lf + 0.02)))


func _special_spawns(dt: float) -> void:
	var mix: Dictionary = stage["traffic"]["mix"]
	var racing: Array = players.filter(func(p): return p.state == PlayerCar.State.RACING)
	if racing.is_empty():
		return
	if mix.has("ambulance"):
		_ambulance_timer -= dt
		if _ambulance_timer <= 0.0:
			_ambulance_timer = rng.randf_range(22.0, 36.0)
			var target: PlayerCar = racing[rng.randi() % racing.size()]
			var d: float = target.d() - 800.0
			if d > 200.0:
				var lane := road.nearest_lane(d, target.position.x) if rng.randf() < 0.6 else rng.randi() % _lasting_lanes(d)
				if _lane_open_ahead(d, lane, 700.0):
					_spawn_rival("ambulance", d, lane)
				else:
					_ambulance_timer = 2.0   # no room right now: try again shortly
	_fuelcar_timer -= dt
	if _fuelcar_timer <= 0.0:
		# The rainbow super car is rare (it makes you unstoppable for 15 s).
		_fuelcar_timer = rng.randf_range(45.0, 70.0) * level["fuel_spacing"] / 6000.0
		var tp: PlayerCar = racing[rng.randi() % racing.size()]
		var fd: float = tp.d() + 1600.0
		if fd < road.length - 600.0:
			var fl := rng.randi() % _lasting_lanes(fd)
			if not _lanes_occupied(fd, 320.0).has(fl):
				_spawn_rival("fuelcar", fd, fl)


## Police / ambulance sirens get louder the closer the nearest such car is to any player.
func _update_sirens() -> void:
	var police := INF
	var amb := INF
	for r in rivals:
		if r.kind != "police" and r.kind != "ambulance":
			continue
		for p in players:
			var dist: float = absf(r.position.y - p.position.y) + absf(r.position.x - p.position.x) * 0.5
			if r.kind == "police":
				police = minf(police, dist)
			else:
				amb = minf(amb, dist)
	AudioManager.update_sirens(police, amb)


func _spawn_rival(kind: String, d: float, lane: int) -> Rival:
	var r := Rival.new()
	_rival_layer.add_child(r)
	r.setup(kind, self, lane, d, stage["traffic"]["speed"])
	rivals.append(r)
	_by_d.append(r)
	for p in players:
		r.was_ahead[p.slot] = r.d() > p.d()
	return r


func _remove_rival(r: Rival) -> void:
	rivals.erase(r)
	_by_d.erase(r)
	r.queue_free()


# ------------------------------------------------------------ player events

func on_player_crash(p: PlayerCar) -> void:
	AudioManager.play("boom")
	AudioManager.play_impact("impactMetal", -2.0)
	popup.emit(p.slot, "CRASH!  -5", "bad")
	shake.emit(p.slot, 14.0)


func on_player_respawn(_p: PlayerCar) -> void:
	pass


func on_player_bump(p: PlayerCar) -> void:
	AudioManager.play_impact("impactGeneric", -2.0)
	AudioManager.play("skid", -4.0)
	popup.emit(p.slot, "BUMP! SLOWDOWN", "bad")
	shake.emit(p.slot, 6.0)


func on_player_oil(_p: PlayerCar) -> void:
	AudioManager.play("skid", -4.0)
