class_name AutoPilot
## Steering + braking assistant for "Easy" mode.
##
## Every frame it tries each (lane, speed) combination, simulates the next few seconds of our car
## and of every nearby car / hazard, and picks the safest fast option. Everything is computed in
## road coordinates (distance along the road, offset from the centre line), so bends don't matter.

const STEP := 0.1
const STEPS := 30           # 3 s look-ahead
const SPEED_FACTORS := [1.0, 0.75, 0.5, 0.25, 0.1, 0.0]
const DELAYS := [0.0, 0.25, 0.5, 0.8, 1.2, 1.6]   # keep the current lane this long before moving over
const SAFE_X := 12.0        # extra sideways clearance
const STEER_LIMIT := 0.85   # the real car uses the same limit, so predictions match reality
const SAFE_Y := 14.0        # extra lengthwise clearance (grows with closing speed)

var target_lane := -1
var debug := ""
var history: Array = []

## A car or hazard as the planner sees it: where it is, how it moves, how big it is.
class Predicted:
	var d := 0.0      # distance along the road
	var u := 0.0      # offset from the road centre
	var v := 0.0      # forward speed
	var ut := 0.0     # offset it is heading for
	var rate := 0.0   # how fast it moves sideways
	var hw := 0.0
	var hh := 0.0
	var kind := ""    # "car", "chaser", "static" or "oil"


	static func make(d_: float, u_: float, v_: float, ut_: float, rate_: float, hw_: float, hh_: float, kind_: String) -> Predicted:
		var p := Predicted.new()
		p.d = d_
		p.u = u_
		p.v = v_
		p.ut = ut_
		p.rate = rate_
		p.hw = hw_
		p.hh = hh_
		p.kind = kind_
		return p


var _cap := 9999.0
var _replan := 0            # ticks until the next full re-plan
var _objs: Array[Predicted] = []
var _pickup_d := PackedFloat64Array()   # fuel cans ahead: distance...
var _pickup_u := PackedFloat64Array()   # ...and offset from the road centre


## Staggers when this pilot re-plans, so two pilots never search on the same tick.
func set_stagger(ticks: int) -> void:
	_replan = ticks


## Returns {"x": where to steer now, "ff": sideways speed needed to follow the lane, "cap": max speed}.
func plan(p: PlayerCar, world: World) -> Dictionary:
	var road: Road = world.road
	var d := p.d()
	var v := p.speed
	var u := p.position.x - road.center_x(d)
	var n := road.lane_count(d + 120.0)
	var cur := road.nearest_lane(d, p.position.x)
	if target_lane < 0:
		target_lane = cur
	target_lane = clampi(target_lane, 0, n - 1)

	# The full search is expensive; run it every 3rd physics tick (20 times a second) and steer smoothly in between.
	_replan -= 1
	if _replan <= 0:
		_replan = 3
		_search(p, world, road, d, v, u, n, cur)

	# Steer towards the lane centre here, plus feed-forward for how the lane moves sideways
	# beyond what the car is already carried by the road.
	var tx := road.lane_x(d, target_lane)
	var ahead := 24.0
	var lane_drift := road.lane_x(d + ahead, target_lane) - tx
	var road_drift := road.center_x(d + ahead) - road.center_x(d)
	var ff := (lane_drift - road_drift) / ahead * v
	return {"x": tx, "ff": ff, "cap": _cap}


func _search(p: PlayerCar, world: World, road: Road, d: float, v: float, u: float, n: int, cur: int) -> void:
	_gather(p, world, road, d, v)

	var v_want := maxf(p.target_speed, 60.0)
	var lane_best: Array = []
	var lane_speed: Array = []
	var lane_delay: Array = []
	for lane in n:
		var best_score := INF
		var best_v := v_want
		var best_delay := 0.0
		for delay in (DELAYS if lane != target_lane else [0.0]):
			for f in SPEED_FACTORS:
				var s: float = v_want * f
				var res := _simulate(p, road, d, u, v, lane, s, delay)
				var score := _danger(res[0]) + 0.3 * _danger(res[2]) + (250.0 if res[3] else 0.0)
				var t_hit: float = res[0]
				score += (v_want - s) * 2.0
				score -= res[1] * 120.0                          # fuel cans on the way
				score += 25.0 * absi(lane - cur) + 60.0 * absi(lane - target_lane) + delay * 20.0
				if score < best_score:
					best_score = score
					best_v = s
					best_delay = delay
				var clean: bool = t_hit == INF and res[2] == INF and not res[3]
				if clean:
					break  # slower options in this plan can only score worse
			if best_v >= v_want - 1.0 and best_delay == delay and best_score < 1000.0:
				break      # already safe at full speed: no need to wait longer
		lane_best.append(best_score)
		lane_speed.append(best_v)
		lane_delay.append(best_delay)

	# Switch lanes only when clearly better (prevents dithering). A plan that first holds the
	# current lane keeps steering straight for now; it is re-planned next frame.
	var best := target_lane
	for lane in n:
		if lane_best[lane] < lane_best[best] - 60.0:
			best = lane
	var cap: float = lane_speed[best]
	if lane_delay[best] <= 0.0:
		target_lane = best
	if cap >= v_want - 1.0:
		cap = 9999.0
	_cap = cap
	debug = "lane=%d cap=%.0f scores=%s" % [target_lane, cap, str(lane_best.map(func(x): return int(x)))]
	if Autotest.enabled:
		var near := []
		for o in _objs:
			if o.d - d < 500.0 and o.d - d > -120.0:
				near.append("%s@%.0f/%.0f>%.0f v%.0f" % [o.kind.substr(0, 3), o.d - d, o.u, o.ut, o.v])
		history.append("d=%.0f u=%.0f v=%.0f %s near=%s" % [d, u, v, debug, str(near)])
		if history.size() > 30:
			history.pop_front()


## Penalty for a predicted collision at time t. Near ones are terrible; far ones only mildly bad,
## because we re-plan constantly and will usually find a way round as we get closer.
func _danger(t: float) -> float:
	if t == INF:
		return 0.0
	var k := clampf((2.2 - t) / 2.2, 0.0, 1.0)
	return 300.0 + 12000.0 * k * k


func _gather(p: PlayerCar, world: World, road: Road, d: float, v: float) -> void:
	_objs.clear()
	_pickup_d.clear()
	_pickup_u.clear()
	var lo := d - 700.0
	var hi := d + maxf(v, 300.0) * STEPS * STEP + 300.0
	for r in world.rivals:
		var rd: float = r.d()
		if rd < lo or rd > hi or r.kind == "fuelcar":
			continue
		var cx := road.center_x(rd)
		var ru: float = r.position.x - cx
		var kind := "car"
		if r.behavior == "blocker" or (r.behavior == "rammer" and (r.is_chasing() or rd - d < 700.0)):
			kind = "chaser"   # may move into whatever lane we pick
		var ut: float = road.lane_x(rd, r.target_lane) - cx
		# Rivals slow down behind slower traffic: predict that.
		var rv: float = r.speed
		var lead: float = world.query.lead_speed(r)
		if lead >= 0.0:
			rv = minf(rv, lead)
		_objs.append(Predicted.make(rd, ru, rv, ut, r.lane_speed * Road.LANE_W, r.hw, r.hh, kind))
		var il: int = r.intended_lane()
		if il != r.target_lane:
			# About to change lanes: also reserve the lane it is signalling towards.
			_objs.append(Predicted.make(rd, ru, rv, road.lane_x(rd, il) - cx, r.lane_speed * Road.LANE_W, r.hw, r.hh, "car"))
	for o in world.obstacles:
		var od: float = o.d()
		if od < lo or od > hi:
			continue
		var ou: float = o.position.x - road.center_x(od)
		_objs.append(Predicted.make(od, ou, 0.0, ou, 0.0, o.hw, o.hh, "oil" if o.kind == "oil" else "static"))
	for pk in world.pickups:
		var pd: float = pk.d()
		if pd > d and pd < hi:
			_pickup_d.append(pd)
			_pickup_u.append(pk.position.x - road.center_x(pd))
	for q in world.players:
		if q == p or q.state != PlayerCar.State.RACING:
			continue
		var qd: float = q.d()
		if qd < d or qd > hi:
			continue  # a player behind us looks after itself (players never crash into each other)
		var qcx := road.center_x(qd)
		var qu: float = q.position.x - qcx
		var qt := qu
		if q.pilot:
			qt = road.lane_x(qd, q.pilot.target_lane) - qcx  # the other auto-steer car's plan
		_objs.append(Predicted.make(qd, qu, q.speed, qt, 400.0, q.hw, q.hh, "car"))


## Simulates our car keeping its current lane for `delay` seconds, then heading for `lane`,
## with speed limit `s`.
## Returns [time of first crash, fuel cans collected, time of first bump from behind, drove over oil].
func _simulate(p: PlayerCar, road: Road, d: float, u: float, v: float, lane: int, s: float, delay := 0.0) -> Array:
	var cd := d
	var cu := u
	var cv := v
	var lat_accel := 3000.0 * p.grip
	var cvx := 0.0
	var fuel := 0
	var hw := p.hw + SAFE_X
	var hh := p.hh + SAFE_Y
	var taken := {}
	var t_bump := INF
	var oil := false
	for k in range(0, STEPS + 1):
		var t := k * STEP
		if k > 0:
			# Speed: accelerate / brake towards s.
			if cv > s:
				cv = maxf(s, cv - PlayerCar.BRAKE_CAP_DECEL * STEP)
			else:
				cv = minf(s, cv + PlayerCar.SLOW_ACCEL * STEP)
			cd += cv * STEP
			# Sideways: same controller as the real car.
			var goal := road.lane_x(cd, lane if t >= delay else target_lane) - road.center_x(cd)
			var lat_max := minf(PlayerCar.steer_speed(cv) * STEER_LIMIT, PlayerCar.lateral_limit(cv))
			var want := clampf((goal - cu) * 7.0, -lat_max, lat_max)
			cvx = move_toward(cvx, want, lat_accel * STEP)
			cu += cvx * STEP
		for o in _objs:
			var od: float = o.d + o.v * t
			var ou: float = o.u
			if o.kind == "chaser":
				ou = move_toward(ou, cu, 150.0 * t)
			elif o.rate > 0.0:
				ou = move_toward(ou, o.ut, o.rate * t)
			var margin_y := maxf(cv - o.v, 0.0) * 0.1  # keep a bigger gap when closing fast
			if absf(cd - od) < hh + o.hh + margin_y and absf(cu - ou) < hw + o.hw:
				if o.kind == "oil":
					oil = oil or k <= 12          # only a skid; only care when close
				elif od < cd and o.v > cv:
					t_bump = minf(t_bump, t)      # something faster runs into us: just a bump
				else:
					return [t, fuel, t_bump, oil]
		for i in _pickup_d.size():
			if not taken.has(i) and absf(cd - _pickup_d[i]) < 40.0 and absf(cu - _pickup_u[i]) < 40.0:
				taken[i] = true
				fuel += 1
	return [INF, fuel, t_bump, oil]


## Debug helper (autotest only): re-simulates staying in the current lane at full speed.
func explain(p: PlayerCar, world: World) -> String:
	var road: Road = world.road
	var d := p.d()
	_gather(p, world, road, d, p.speed)
	var u := p.position.x - road.center_x(d)
	var res := _simulate(p, road, d, u, p.speed, target_lane, p.speed, 0.0)
	var objs := []
	for o in _objs:
		if o.d - d < 300.0 and o.d - d > -150.0:
			objs.append("%s d%+.0f u%.0f v%.0f hh%.0f" % [o.kind, o.d - d, o.u, o.v, o.hh])
	return "sim=%s u=%.0f v=%.0f objs=%s" % [str(res), u, p.speed, str(objs)]
