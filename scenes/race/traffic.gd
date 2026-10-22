class_name Traffic
extends RefCounted
## The cars sharing the road: spawning and removing them around the players, the special arrivals
## (ambulance, super car, called police) and the sirens.

const POLICE_BEHIND := 470.0   # a called police car enters this far behind the player (just out of view)
const NARROW_TRAFFIC := 0.3    # traffic on roads of two lanes or fewer, as a share of the stage's density

var world: World
var road: Road
var stage: StageData
var level: DifficultyLevel
var rng: RandomNumberGenerator
var rivals: Array[Rival]
var obstacles: Array[Obstacle]
var players: Array[PlayerCar]
var rival_layer: Node2D

var _spawn_timer := 0.0
var _ambulance_timer := 18.0
var _fuelcar_timer := 6.0


func _init(w: World, rival_parent: Node2D) -> void:
	world = w
	road = w.road
	stage = w.stage
	level = w.level
	rng = w.rng
	rivals = w.rivals
	obstacles = w.obstacles
	players = w.players
	rival_layer = rival_parent


## One simulation step of the traffic: top up cars every 0.2 s, special arrivals, sirens.
func tick(dt: float) -> void:
	_spawn_timer -= dt
	if _spawn_timer <= 0.0:
		_spawn_timer = 0.2
		update_traffic(false)
	special_spawns(dt)
	update_sirens()


## Weight of a rival kind in the traffic mix; the "attacking" cars (they block / ram you)
## appear more or less often depending on the difficulty.
func _kind_weight(k: String) -> float:
	var w := stage.traffic.weight_of(k)
	if k == "viper" or k == "police":
		w *= level.attack
	return w


func _pick_kind() -> String:
	var kinds := stage.traffic.kinds
	var total := 0.0
	for k in kinds:
		if k != "ambulance":
			total += _kind_weight(k)
	var roll := rng.randf() * maxf(total, 0.001)
	for k in kinds:
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


func update_traffic(fill: bool) -> void:
	var dens := stage.traffic.density
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
		var target_f := dens * 2.4 * (hi - lo) / 1000.0
		if _lasting_lanes(hi) <= 2:
			target_f *= NARROW_TRAFFIC   # leave room to overtake where the road is narrow
		var target := int(round(target_f))
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
		spawn_rival(_pick_kind(), d, lane)

	# Clean up cars nobody can see any more.
	var min_d := 1.0e12
	var max_d := -1.0e12
	for p in players:
		min_d = minf(min_d, p.d())
		max_d = maxf(max_d, p.d())
	for r in rivals.duplicate():
		if r.d() < min_d - 1000.0 or r.d() > max_d + 2800.0:
			remove_rival(r)


## Nothing in this lane from just behind d to `ahead` past it (room for a fast car to enter).
func _lane_open_ahead(d: float, lane: int, ahead: float) -> bool:
	var lu := road.lane_x(d, lane) - road.center_x(d)
	for o in rivals:
		if o.d() > d - 150.0 and o.d() < d + ahead and absf(world.query.u_of(o) - lu) < 48.0:
			return false
	for ob in obstacles:
		if ob.d() > d - 100.0 and ob.d() < d + ahead + 300.0 and absf(world.query.u_of(ob) - lu) < 48.0:
			return false
	return true


## Lanes that exist here and for a while ahead (never spawn a car in a lane that is about to end).
func _lasting_lanes(d: float) -> int:
	var lf := road.lanes_at(d)
	for k in 4:
		lf = minf(lf, road.lanes_at(d + 250.0 * (k + 1)))
	return maxi(1, int(floor(lf + 0.02)))


func special_spawns(dt: float) -> void:
	var racing: Array = players.filter(func(p): return p.state == PlayerCar.State.RACING)
	if racing.is_empty():
		return
	if stage.traffic.has_kind("ambulance"):
		_ambulance_timer -= dt
		if _ambulance_timer <= 0.0:
			_ambulance_timer = rng.randf_range(22.0, 36.0)
			var target: PlayerCar = racing[rng.randi() % racing.size()]
			var d: float = target.d() - 800.0
			if d > 200.0:
				var lane := road.nearest_lane(d, target.position.x) if rng.randf() < 0.6 else rng.randi() % _lasting_lanes(d)
				if _lane_open_ahead(d, lane, 700.0):
					spawn_rival("ambulance", d, lane)
				else:
					_ambulance_timer = 2.0   # no room right now: try again shortly
	_fuelcar_timer -= dt
	if _fuelcar_timer <= 0.0:
		# The rainbow super car is rare (it makes you unstoppable for 15 s).
		_fuelcar_timer = rng.randf_range(45.0, 70.0) * level.fuel_spacing / 6000.0
		var tp: PlayerCar = racing[rng.randi() % racing.size()]
		var fd: float = tp.d() + 1600.0
		if fd < road.length - 600.0:
			var fl := rng.randi() % _lasting_lanes(fd)
			if not _lanes_occupied(fd, 320.0).has(fl):
				spawn_rival("fuelcar", fd, fl)


## Police / ambulance sirens get louder the closer the nearest such car is to any player.
func update_sirens() -> void:
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


func spawn_rival(kind: String, d: float, lane: int) -> Rival:
	var r := Rival.new()
	rival_layer.add_child(r)
	r.setup(kind, world, lane, d, stage.traffic.speed)
	rivals.append(r)
	world.query.track(r)
	r.reentry_requested.connect(bring_police_closer, CONNECT_DEFERRED)
	r.gave_up.connect(remove_rival, CONNECT_DEFERRED)
	for p in players:
		r.was_ahead[p.slot] = r.d() > p.d()
	return r


func remove_rival(r: Rival) -> void:
	rivals.erase(r)
	world.query.untrack(r)
	r.queue_free()


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
	var r := spawn_rival("police", d, _police_lane(p, d, null))
	r.start_chase(p)
	world.popup.emit(p.slot, "POLICE CALLED!", "bad")


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
			remove_rival(o)
	return best
