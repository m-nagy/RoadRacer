class_name Collisions
extends RefCounted
## Who touches whom: rival cars keeping apart, the players against traffic, hazards and fuel cans.
## The test is an exact oriented-box overlap (separating axes), with a cheap distance check first.

const SCORE_FUEL := 500
const SCORE_FUELCAR := 1000
const TIME_FUEL := 10.0

var world: World
var rng: RandomNumberGenerator
var rivals: Array[Rival]
var obstacles: Array[Obstacle]
var pickups: Array[Pickup]
var players: Array[PlayerCar]


func _init(w: World) -> void:
	world = w
	rng = w.rng
	rivals = w.rivals
	obstacles = w.obstacles
	pickups = w.pickups
	players = w.players


## Safety net: rival cars never overlap. A car that slid into another during a lane change goes
## back towards the lane it came from; one that ran into the back of another is held behind it.
func separate_rivals() -> void:
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


func resolve() -> void:
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
				world.popup.emit(p.slot, "SUPER CAR!  15 s", "good")
				AudioManager.play("fuel")
				world.traffic.remove_rival(r)
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
				world.popup.emit(p.slot, "FUEL +10", "good")
				AudioManager.play("fuel")
				pickups.erase(pk)
				world.course.pickups_taken += 1
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
			world.popup.emit(p.slot, "SNOWBANK! SLIDING", "bad")
		"cone":
			AudioManager.play_impact("impactTin", -4.0)
			_knock_obstacle(o, p)
			world.traffic.call_police(p)
		"barrel":
			AudioManager.play_impact("impactMetal", -3.0)
			p.hit_barrel()
			_knock_obstacle(o, p)
			world.popup.emit(p.slot, "BARREL! STOPPED", "bad")
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
