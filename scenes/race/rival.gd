class_name Rival
extends Node2D
## A computer-driven car. Behaviour depends on its kind (see CarDefs).

## Called police stuck far behind in traffic asks to be put back just out of view.
signal reentry_requested(rival: Rival)
## A car that has been stuck for too long asks to be removed.
signal gave_up(rival: Rival)

var kind := "taxi"
var def: CarKind
var behavior := "keeper"
var world: World
var speed := 300.0
var base_speed := 300.0
var lane_pos := 0.0      # fractional lane index
var target_lane := 0
var lane_speed := 1.6    # lanes per second
var hw := 20.0
var hh := 43.0
var passed_by: Dictionary = {}   # slot -> true once that player has overtaken this car
var was_ahead: Dictionary = {}   # slot -> true while this car is ahead of that player
var dead := false
var limit := INF            # speed the traffic / obstacles ahead hold this car to
var chase: PlayerCar = null # police called by a cone: the player it is after

var _timer := 0.0
var _blink := 0.0
var _blink_dir := 0
var _free_x := false
var _free_u := 0.0        # sideways offset from the road centre while chasing
var _blocked := false     # waiting for a gap to steer round an obstacle
var _stuck_t := 0.0       # how long we have been waiting at a standstill
var _chase_t := 0.0
var _signal_t := 0.0
var _wall_wait := 0.0     # how long the "leave a lane open" rule has kept us standing
var _wall_skip := 0.0     # ...after too long, ignore it for a moment so nothing waits forever      # indicator on while waiting to merge out of an ending lane
var _ram_cd := 0.0
var _react := 0.0
var _frames: Array[Texture2D] = []
var _frame_t := 0.0
var _sprite: Sprite2D
var _blinker_drawn := NO_BLINK   # indicator state the node was last redrawn for

const NO_BLINK := -2


func setup(kind_name: String, w: World, lane: int, d: float, speed_mult: float) -> void:
	kind = kind_name
	def = CarDefs.KINDS[kind]
	behavior = def.behavior
	world = w
	hw = def.hw
	hh = def.hh
	base_speed = def.speed * (speed_mult if kind != "ambulance" else 1.0)
	base_speed *= randf_range(0.93, 1.07)
	if not CarDefs.FAST_KINDS.has(kind):
		base_speed = minf(base_speed, CarDefs.SLOW_CAP)   # only police and ambulance are fast
	speed = base_speed
	lane_pos = float(lane)
	target_lane = lane
	_timer = randf_range(1.5, 4.0)
	position = Vector2(w.road.lane_x(d, lane), -d)
	rotation = w.road.heading(d)
	_sprite = Sprite2D.new()
	_sprite.texture = def.texture
	_sprite.scale = Vector2.ONE * def.scale
	add_child(_sprite)
	_frames = def.frames
	if kind == "fuelcar":
		var m := ShaderMaterial.new()
		m.shader = Game.shader
		m.set_shader_parameter("rainbow", true)
		_sprite.material = m
	if kind == "viper":
		lane_speed = 2.6
	if kind == "ambulance":
		lane_speed = 2.2
	reset_physics_interpolation()


func d() -> float:
	return -position.y


func lane_now() -> int:
	return roundi(lane_pos)


func tick(dt: float) -> void:
	var road: Road = world.road
	var dd := d()
	_ram_cd = maxf(0.0, _ram_cd - dt)
	_react = maxf(0.0, _react - dt)
	_signal_t = maxf(0.0, _signal_t - dt)

	_frame_t += dt
	if not _frames.is_empty():
		_sprite.texture = _frames[int(_frame_t / 0.14) % _frames.size()]

	var want := base_speed
	var catching_up := false
	var ahead_by := 0.0
	if chase != null:
		_chase_t -= dt
		ahead_by = dd - chase.d()
		if _chase_t <= 0.0 or chase.state != PlayerCar.State.RACING or ahead_by > 300.0:
			chase = null
		elif ahead_by < -700.0:
			reentry_requested.emit(self)   # stuck in traffic: re-enter out of view
		elif ahead_by < -40.0:
			# Called police still behind its target: race up (always faster than the player),
			# easing off as it draws level so it ends up alongside.
			catching_up = true
			want = minf(maxf(base_speed, chase.speed + clampf((-ahead_by - 40.0) * 0.5, 50.0, 170.0)), PlayerCar.FAST_MAX + 200.0)

	# Keep a safe distance behind the cars ahead, and (ordinary traffic) never close the last open lane.
	limit = world.query.follow_limit(self)
	_wall_skip = maxf(0.0, _wall_skip - dt)
	if chase == null and not _free_x and not CarDefs.FAST_KINDS.has(kind) and _wall_skip <= 0.0:
		var wl: float = world.query.wall_limit(self)
		limit = minf(limit, wl)
		if wl < 30.0 and speed < 30.0:
			_wall_wait += dt
			if _wall_wait > 3.0:
				_wall_wait = 0.0
				_wall_skip = 2.5
		else:
			_wall_wait = 0.0
	# Every car steers round obstacles on the road (and never drives over them).
	_blocked = false
	var ob: Obstacle = world.query.obstacle_ahead(self, 80.0 + speed * speed / 800.0 + speed * 0.9)
	if ob != null:
		var gap: float = ob.d() - dd - ob.hh - hh
		if _react <= 0.0 and not _free_x:
			var n0 := road.lane_count(dd)
			var dirs := [-1, 1]
			dirs.shuffle()
			for dl in dirs:
				var nl: int = clampi(target_lane + dl, 0, n0 - 1)
				if nl != target_lane and world.query.lane_is_clear(self, nl, 150.0, maxf(gap + 150.0, 250.0)) \
						and not world.query.lane_closes_road(self, nl):
					target_lane = nl
					_blink_dir = dl
					lane_speed = maxf(lane_speed, 2.6)   # swerve briskly round the obstacle
					break
			_react = 0.35
		if absf(road.lane_x(ob.d(), target_lane) - ob.position.x) < hw + ob.hw + 12.0 or _free_x:
			# Still heading for it: stop in time and wait for a gap.
			_blocked = true
			limit = minf(limit, sqrt(2.0 * 520.0 * 0.8 * maxf(gap - 30.0, 0.0)))   # never faster than we can stop from
			if _free_x:
				_ram_cd = maxf(_ram_cd, 1.0)

	# Our lane ends ahead (the road narrows): signal, move over when there is room, and until
	# then never drive into the narrowing part (wait at the end of the lane like at an obstacle).
	if not _free_x:
		var end := _lane_end_ahead(dd, 900.0)
		if end < INF:
			if _react <= 0.0:
				_change_lane(-1, true)
				_react = 0.3
			if _lane_end_ahead(dd, 900.0) < INF:   # still in the ending lane
				_signal_t = 0.3
				_blocked = true
				limit = minf(limit, sqrt(2.0 * 520.0 * 0.8 * maxf(end - dd - hh - 10.0, 0.0)))

	# Safety net: a car that has been stuck waiting for a gap for too long simply disappears.
	if _blocked and speed < 8.0:
		_stuck_t += dt
		if _stuck_t > 5.0 and not dead:
			dead = true
			gave_up.emit(self)
			return
	else:
		_stuck_t = maxf(0.0, _stuck_t - dt * 2.0)

	match behavior:
		"passive":
			var p = world.query.player_behind(self, 280.0, 55.0)
			if p != null and _react <= 0.0:
				_change_lane(1 if lane_now() == 0 else (-1 if lane_now() >= road.lane_count(dd) - 1 else (1 if randf() < 0.5 else -1)))
				_react = 1.5
		"changer":
			_timer -= dt
			if _timer <= 0.0 and _blink <= 0.0:
				_blink = 0.8
				_blink_dir = 1 if randf() < 0.5 else -1
				if lane_now() == 0:
					_blink_dir = 1
				elif lane_now() >= road.lane_count(dd) - 1:
					_blink_dir = -1
			if _blink > 0.0:
				_blink -= dt
				if _blink <= 0.0:
					_change_lane(_blink_dir)
					_timer = randf_range(2.0, 4.5)
		"blocker":
			# Only on roads wide enough to get past: on two lanes nobody gets to block the player.
			var p2 = world.query.player_behind(self, 520.0, 400.0) if road.lane_count(dd) > 2 else null
			if p2 != null and _react <= 0.0:
				var pl: int = road.nearest_lane(dd, p2.position.x)
				if pl != lane_now():
					_change_lane(signi(pl - lane_now()))
					_react = 0.4
		"rammer":
			if catching_up:
				# Weave round slower traffic and line up in the lane next to the player's.
				if _react <= 0.0 and not _free_x:
					var pl3: int = road.nearest_lane(dd, chase.position.x)
					var n3 := road.lane_count(dd)
					if n3 > 1:
						pl3 = pl3 + 1 if pl3 == 0 or (lane_now() > pl3 and pl3 + 1 < n3) else pl3 - 1
					var toward := signi(pl3 - lane_now())
					if world.query.car_ahead_in_lane(self, 260.0) != null:
						if toward == 0:
							toward = 1 if randf() < 0.5 else -1
						if not _change_lane(toward):
							_change_lane(-toward)
						_react = 0.5
					elif toward != 0 and _change_lane(toward):
						_react = 0.6
			var p3 = chase if chase != null else world.query.player_behind(self, 620.0, 400.0)
			if p3 != null and not catching_up and _ram_cd <= 0.0 and not _blocked:
				if not _free_x:
					_free_x = true
					_free_u = position.x - road.center_x(dd)
				if chase == null:
					want = clampf(p3.speed + 40.0, base_speed * 0.8, base_speed * 1.4)
				else:
					# Called police: stay level with the player while swerving into them.
					want = clampf(p3.speed - (dd - p3.d()) * 1.5, base_speed * 0.6, p3.speed + 200.0)
				var pu: float = p3.position.x - road.center_x(p3.d())
				_free_u = move_toward(_free_u, pu, 150.0 * dt)
			elif _free_x and not catching_up:
				# Drift back into the nearest lane.
				var lane_u := road.lane_x(dd, road.nearest_lane(dd, road.center_x(dd) + _free_u)) - road.center_x(dd)
				_free_u = move_toward(_free_u, lane_u, 160.0 * dt)
				if absf(_free_u - lane_u) < 3.0:
					_free_x = false
					lane_pos = float(road.nearest_lane(dd, road.center_x(dd) + _free_u))
					target_lane = lane_now()
		"passer":
			var blocker = world.query.car_ahead_in_lane(self, 340.0)
			if blocker != null and _react <= 0.0:
				var n := road.lane_count(dd)
				var dir2 := 1 if lane_now() < n - 1 and (lane_now() == 0 or randf() < 0.5) else -1
				_change_lane(dir2)
				_react = 1.0

	want = minf(want, limit)
	var rate := 220.0
	if want < speed and (_blocked or want >= limit - 0.5):
		rate = 520.0     # held up by traffic or an obstacle: brake properly
	elif catching_up:
		rate = 360.0
	speed = move_toward(speed, want, rate * dt)
	var x0 := position.x
	position.y -= speed * dt
	dd = d()

	if not _free_x:
		lane_pos = move_toward(lane_pos, float(target_lane), lane_speed * dt)
		var n2 := road.lane_count(dd)
		if target_lane > n2 - 1:
			target_lane = n2 - 1
		position.x = road.lane_x_f(dd, lane_pos)
	else:
		# Chasing: stay on the tarmac and follow the bend like everyone else.
		var lim := road.half_width(dd) - hw - 6.0
		_free_u = clampf(_free_u, -lim, lim)
		position.x = road.center_x(dd) + _free_u
	# Point the body where it is going (follows bends and lane changes).
	var side_speed := (position.x - x0) / maxf(dt, 0.001) - road.slope(dd) * speed
	var yaw := clampf(atan2(side_speed, maxf(speed, 240.0)) * 0.6, -0.25, 0.25)
	rotation = lerp_angle(rotation, road.heading(dd) + yaw, 1.0 - exp(-10.0 * dt))
	var shown := _blinker_state()
	if shown != _blinker_drawn:
		_blinker_drawn = shown
		queue_redraw()


func _change_lane(dir: int, merging := false) -> bool:
	var n: int = world.road.lane_count(d())
	var nl := clampi(target_lane + dir, 0, n - 1)
	if nl == target_lane or not world.query.lane_is_clear(self, nl, 170.0):
		return false
	if not merging and chase == null and world.query.lane_closes_road(self, nl):
		return false   # would leave the player no way through
	target_lane = nl
	return true


## Where (distance) the lane we are heading for starts to disappear, within `look`; INF if it does not.
func _lane_end_ahead(dd: float, look: float) -> float:
	var road: Road = world.road
	var s := 0.0
	while s <= look:
		if road.lanes_at(dd + s) < float(target_lane) + 0.98:
			return dd + s
		s += 25.0
	return INF


## Puts the car somewhere else on the road (in a lane, not chasing).
func place(at_d: float, lane: int) -> void:
	var road: Road = world.road
	_free_x = false
	lane_pos = float(lane)
	target_lane = lane
	position = Vector2(road.lane_x(at_d, lane), -at_d)
	rotation = road.heading(at_d)
	reset_physics_interpolation()


## Police only: chase this player (they knocked over a cone).
func start_chase(p: PlayerCar) -> void:
	chase = p
	_chase_t = 16.0
	speed = maxf(speed, p.speed + 120.0)


func is_changing_lane() -> bool:
	return not _free_x and absf(lane_pos - float(target_lane)) > 0.01


## Slid into the side of another car: back off sideways (or drop back where the road narrows).
func push_aside(dir: float, amount: float) -> void:
	if _free_x:
		_free_u += dir * amount
		position.x += dir * amount
	elif is_changing_lane():
		# Give up the lane change and head back to the lane we came from.
		var back := floori(lane_pos) if float(target_lane) > lane_pos else ceili(lane_pos)
		target_lane = back
		_blink = 0.0
		lane_pos = move_toward(lane_pos, float(back), amount / Road.LANE_W)
		position.x = world.road.lane_x_f(d(), lane_pos)
	else:
		position.y += 3.0
		speed *= 0.9


## The lane this car is about to move into (blinker on), else its target lane.
func intended_lane() -> int:
	if _blink > 0.0:
		return clampi(target_lane + _blink_dir, 0, world.road.lane_count(d()) - 1)
	return target_lane


func is_chasing() -> bool:
	return _free_x


## Waiting for a gap to steer round an obstacle or into a lane.
func is_blocked() -> bool:
	return _blocked


## Knocked aside by a super car: jump one lane away.
func kick(dir: int) -> void:
	var n: int = world.road.lane_count(d())
	target_lane = clampi(target_lane + dir, 0, n - 1)
	_react = 0.5
	if _free_x:
		_ram_cd = 3.0


func ram_done() -> void:
	_ram_cd = 3.5
	chase = null   # a called police car rams once, then goes back to normal


## What the indicators show right now: NO_BLINK, or the side (-1 / 0 / 1) that is lit.
func _blinker_state() -> int:
	var on := _blink > 0.0 and int(_blink * 10.0) % 2 == 0
	var side := _blink_dir
	if _signal_t > 0.0 and _blink <= 0.0:
		on = int(_frame_t * 5.0) % 2 == 0
		side = -1
	return side if on else NO_BLINK


func _draw() -> void:
	if _blinker_drawn != NO_BLINK:
		var sx := float(_blinker_drawn) * hw
		draw_rect(Rect2(sx - 3.0, -hh, 6.0, 8.0), Color("ffa200"))
		draw_rect(Rect2(sx - 3.0, hh - 8.0, 6.0, 8.0), Color("ffa200"))
