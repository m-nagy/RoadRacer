class_name TrafficQuery
extends RefCounted
## Questions the traffic AI asks about its surroundings: who is ahead, which lanes are taken, is a
## lane clear. Rivals are also kept sorted by distance here, so a query only looks at the cars
## that can matter instead of every car on the road.

const FOLLOW_DECEL := 300.0   # rivals keep enough distance to stop behind the car ahead at this rate
const FOLLOW_GAP := 18.0       # bumper-to-bumper gap they settle at
const WALL_GAP := 60.0         # lengthwise room left round a car so the player can slip past it
const NARROW_PASS_GAP := 200.0 # ...on roads of two lanes or fewer: a full-speed car needs room to change lane twice
const WALL_LOOK := 450.0       # how far ahead a rival looks for a row it must not complete
const WALL_AHEAD := 120.0      # ...counting what that row is about to draw level with
const OBSTACLE_MAX_HH := 30.0  # taller than any obstacle's half length (bounds the sorted searches)
const RIVAL_MAX_HH := 64.0     # ...and any rival's

var road: Road
var rivals: Array[Rival]
var obstacles: Array[Obstacle]   # live obstacles, sorted by distance
var players: Array[PlayerCar]

var _by_d: Array[Rival] = []     # rivals sorted by distance, kept in step with their live positions


func _init(world: World) -> void:
	road = world.road
	rivals = world.rivals
	obstacles = world.obstacles
	players = world.players


## A rival joined the road / left it.
func track(r: Rival) -> void:
	_by_d.append(r)


func untrack(r: Rival) -> void:
	_by_d.erase(r)


## Index of the first live obstacle at or beyond distance x (they are sorted by distance).
func first_obstacle_at(x: float) -> int:
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
func resort() -> void:
	for i in range(1, _by_d.size()):
		var r := _by_d[i]
		var rd := r.d()
		var j := i - 1
		while j >= 0 and _by_d[j].d() > rd:
			_by_d[j + 1] = _by_d[j]
			j -= 1
		_by_d[j + 1] = r


## Moves one rival that just changed distance to its place in the sorted list.
func reposition(r: Rival) -> void:
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
	for i in range(first_obstacle_at(d_lo - OBSTACLE_MAX_HH), obstacles.size()):
		var ob: Obstacle = obstacles[i]
		var obd: float = ob.d()
		if obd >= d_hi + OBSTACLE_MAX_HH:
			break
		if obd + ob.hh > d_lo and obd - ob.hh < d_hi:
			used[road.nearest_lane(obd, ob.position.x)] = true
	return used


## Lengthwise room cars keep between lanes (wall_limit) on a road with this many lanes.
func gap_for(lanes: int) -> float:
	return WALL_GAP if lanes >= 3 else NARROW_PASS_GAP


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
	var wall := gap_for(n)
	var limit := INF
	for i in range(_first_rival_at(rd), _by_d.size()):
		var o := _by_d[i]
		var dy: float = o.d() - rd
		if dy > WALL_LOOK:
			break
		if o == r or o.kind == "fuelcar" or o.speed < 40.0 or dy <= 0.0:
			continue
		var lo: float = o.d() - o.hh - wall
		var used := lanes_blocked(lo, o.d() + o.hh + wall + WALL_AHEAD, r, rd)
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
	for i in range(first_obstacle_at(d_from), obstacles.size()):
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
	for i in range(first_obstacle_at(r.d() - OBSTACLE_MAX_HH), obstacles.size()):
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
