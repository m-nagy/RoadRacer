class_name PlayerCar
extends Node2D
## A human-driven car. All simulation is driven by World calling tick().

enum State { RACING, CRASHED, OUT, FINISHED }

const SLOW_MAX := 360.0     # ~200 km/h
const FAST_MAX := 720.0     # ~400 km/h
const SLOW_ACCEL := 240.0
const FAST_ACCEL := 150.0
const COAST_DECEL := 90.0
const BRAKE_DECEL := 380.0
const LATERAL_BASE := 230.0   # sideways speed when crawling...
const LATERAL_GAIN := 0.25    # ...plus this much per px/s of forward speed
const BRAKE_CAP_DECEL := 700.0
const EDGE_HW := 22.0       # visible half width/length of the body, used against the road edge
const EDGE_HH := 47.0
const EDGE_MARGIN := 5.0    # how far into the curb a corner may go before it counts as hitting the side
const START_TIME := 100.0
const CRASH_PENALTY := 5.0

var slot := 0
var easy := false
var world: World
var state := State.RACING
var speed := 0.0
var vx := 0.0
var time_left := START_TIME
var score := 0.0
var penalty := 0.0         # seconds of increased fuel consumption left
var invuln := 0.0
var bump_cd := 0.0
var skid := 0.0
var oil_skid := 0.0
var next_cp := 0
var overtakes := 0
var crashes := 0
var finish_d := 0.0
var hw := 19.0
var hh := 42.0
var grip := 1.0
var pilot: AutoPilot
var speed_cap := 9999.0
var target_speed := 0.0     # what the player is asking for (used by the autopilot)
var super_t := 0.0          # seconds of rainbow super car left (nothing can hurt it)
var stop_t := 0.0           # barrel: brakes to a standstill for this long
var slide_u := INF          # snowbank: sliding towards this offset from the road centre
var braking := false        # brake lights on (auto-brake or the brake key)

var _crash_t := 0.0
var _last_d := 0.0
var _sprite: Sprite2D
var _light: PointLight2D
var _wobble := 0.0
var _super_visual := false


func setup(w: World, slot_idx: int, color_idx: int, easy_mode: bool, lane: int) -> void:
	world = w
	slot = slot_idx
	easy = easy_mode
	grip = w.stage.grip
	hw = CarDefs.PLAYER.hw
	hh = CarDefs.PLAYER.hh
	_sprite = Sprite2D.new()
	_sprite.texture = CarDefs.PLAYER.texture
	_sprite.scale = Vector2.ONE * CarDefs.PLAYER.scale
	_sprite.material = Game.make_car_material(color_idx)
	add_child(_sprite)
	if easy:
		pilot = AutoPilot.new()
		pilot.set_stagger(slot_idx + 1)  # the two players plan on different ticks
	position = Vector2(w.road.lane_x(60.0, lane), -60.0)
	rotation = w.road.heading(60.0)
	_last_d = 60.0
	if w.stage.night:
		_light = PointLight2D.new()
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		g.width = 256
		g.height = 256
		var grad := Gradient.new()
		grad.set_color(0, Color.WHITE)
		grad.set_color(1, Color(1, 1, 1, 0))
		g.gradient = grad
		_light.texture = g
		_light.texture_scale = 3.2
		_light.position = Vector2(0, -170)
		_light.energy = 1.1
		_light.color = Color("fff1c4")
		add_child(_light)


## Full-lock sideways speed at a forward speed.
static func steer_speed(v: float) -> float:
	return LATERAL_BASE + v * LATERAL_GAIN


## Max sideways speed at a forward speed: grows with speed, but a rolling car can always
## creep sideways a little so it never gets trapped nose-to-nose with a cone.
static func lateral_limit(v: float) -> float:
	var lim := steer_speed(v) * clampf(v / 150.0, 0.0, 1.0)
	if v > 1.0:
		lim = maxf(lim, 120.0)
	return lim


func d() -> float:
	return -position.y


func is_active() -> bool:
	return state == State.RACING


func kmh() -> float:
	return speed / 1.8


func tick(dt: float, running: bool) -> void:
	invuln = maxf(0.0, invuln - dt)
	bump_cd = maxf(0.0, bump_cd - dt)
	skid = maxf(0.0, skid - dt)
	oil_skid = maxf(0.0, oil_skid - dt)
	penalty = maxf(0.0, penalty - dt)
	_update_super(dt)
	var road: Road = world.road

	match state:
		State.CRASHED:
			_crash_t -= dt
			if _crash_t <= 0.0:
				_respawn()
			queue_redraw()
			return
		State.OUT, State.FINISHED:
			speed = move_toward(speed, 0.0, (160.0 if state == State.OUT else 110.0) * dt)
			position.y -= speed * dt
			# Roll on following the lane.
			position.x = move_toward(position.x, road.lane_x(d(), road.nearest_lane(d(), position.x)), 240.0 * dt)
			rotation = lerp_angle(rotation, road.heading(d()), 0.2)
			_sprite.rotation = 0.0
			return

	if not running:
		return

	# --- time
	time_left -= dt * (1.5 if penalty > 0.0 else 1.0)
	if time_left <= 0.0:
		time_left = 0.0
		state = State.OUT
		return

	# --- speed control
	var slow := InputManager.pressed(slot, "slow")
	var fast := InputManager.pressed(slot, "fast")
	var brake := InputManager.pressed(slot, "down") and not easy
	target_speed = FAST_MAX if fast else (SLOW_MAX if slow else speed)
	var cap := minf(speed_cap, FAST_MAX)
	if fast:
		var accel := FAST_ACCEL if speed >= SLOW_MAX else SLOW_ACCEL
		speed = move_toward(speed, minf(FAST_MAX, cap), accel * dt)
	elif slow:
		if speed > SLOW_MAX:
			speed = move_toward(speed, SLOW_MAX, 200.0 * dt)
		else:
			speed = move_toward(speed, minf(SLOW_MAX, cap), SLOW_ACCEL * dt)
	elif brake:
		speed = move_toward(speed, 0.0, BRAKE_DECEL * dt)
	else:
		speed = move_toward(speed, 0.0, COAST_DECEL * dt)
	var was_braking := braking
	braking = brake or speed > cap + 0.5
	if stop_t > 0.0:
		stop_t -= dt
		speed = move_toward(speed, 0.0, 1800.0 * dt)   # barrel: stopped dead, then gas again
		braking = true
	if speed > cap:
		speed = move_toward(speed, cap, BRAKE_CAP_DECEL * dt)
	if braking != was_braking:
		queue_redraw()

	# --- steering
	var steer := 0.0
	if easy:
		var plan := pilot.plan(self, world)
		speed_cap = plan["cap"]
		var err: float = plan["x"] - position.x
		steer = clampf((plan["ff"] + err * 7.0) / steer_speed(speed), -AutoPilot.STEER_LIMIT, AutoPilot.STEER_LIMIT)
	else:
		speed_cap = 9999.0
		steer = InputManager.steer(slot)

	var lat_lim := lateral_limit(speed)
	var want_vx := clampf(steer * steer_speed(speed), -lat_lim, lat_lim)
	var accel_lat := 2600.0 * grip
	if oil_skid > 0.0:
		accel_lat = 150.0
	elif skid > 0.0:
		accel_lat = 700.0
	if slide_u != INF:
		# Snowbank: flung to the far side of the road, steering is ignored.
		var cu := position.x - road.center_x(d())
		var diff := slide_u - cu
		if absf(diff) < 6.0:
			slide_u = INF
		else:
			want_vx = signf(diff) * 540.0
			accel_lat = 4000.0
	vx = move_toward(vx, want_vx, accel_lat * dt)

	var d0 := d()
	position.y -= speed * dt
	# The car follows the road exactly: only the driver's own steering moves it across the road.
	position.x += road.center_x(d()) - road.center_x(d0)
	position.x += vx * dt
	position.x += world.wind_at(d()) * dt

	# --- visuals: the body turns with the road, with a slight lean into a lane change
	var lean := clampf(vx / steer_speed(speed), -1.0, 1.0) * 0.07
	rotation = lerp_angle(rotation, road.heading(d()) + lean, 1.0 - exp(-14.0 * dt))
	var wob := 0.0
	if skid > 0.0 or oil_skid > 0.0:
		_wobble += dt * 22.0
		wob = sin(_wobble) * 0.3
	_sprite.rotation = lerpf(_sprite.rotation, wob, 0.3)
	_sprite.visible = invuln <= 0.0 or int(invuln * 12.0) % 2 == 0

	# --- road side: any corner of the body past the curb is a crash
	# (Easy mode and skids bounce off the curb instead).
	var dd := d()
	if easy or skid > 0.0 or oil_skid > 0.0 or super_t > 0.0 or slide_u != INF:
		var lim := road.half_width(dd) - EDGE_HW * cos(rotation) - EDGE_HH * absf(sin(rotation)) - 2.0
		var cx := road.center_x(dd)
		if absf(position.x - cx) > lim and road.strip_at(position.x, dd) < 0:
			position.x = cx + signf(position.x - cx) * lim
			vx = 0.0
	if not easy and super_t <= 0.0 and hits_road_side():
		crash("road side")
		return

	# --- scoring
	var gained := (dd - _last_d) / 8.0
	if gained > 0.0:
		score += gained
	_last_d = dd


## Body corners in world space (oriented with the car).
func corners() -> Array:
	var out := []
	for c in [Vector2(-EDGE_HW, -EDGE_HH), Vector2(EDGE_HW, -EDGE_HH), Vector2(-EDGE_HW, EDGE_HH), Vector2(EDGE_HW, EDGE_HH)]:
		out.append(position + c.rotated(rotation))
	return out


## True when any corner of the car is beyond the edge of the road at that corner's own distance,
## so bends are taken into account (the front corner meets the curb first on a bend).
func hits_road_side() -> bool:
	var road: Road = world.road
	for c in corners():
		if not road.drivable(c.x, -c.y, EDGE_MARGIN):
			return true
	return false


func crash(reason := "") -> void:
	if state != State.RACING or super_t > 0.0:
		return
	if Autotest.enabled:
		print("[crash] P%d d=%.0f v=%.0f x=%.0f road=%.0f reason=%s" % [slot + 1, d(), speed, position.x, world.road.center_x(d()), reason])
		if pilot:
			for h in pilot.history.slice(-14):
				print("   ", h)
	state = State.CRASHED
	crashes += 1
	_crash_t = 1.6
	speed = 0.0
	vx = 0.0
	time_left = maxf(0.0, time_left - CRASH_PENALTY)
	_sprite.visible = false
	_sprite.rotation = 0.0
	world.on_player_crash(self)


func _respawn() -> void:
	var road: Road = world.road
	var dd := d()
	if time_left <= 0.0:
		state = State.OUT
		_sprite.visible = true
		return
	var lane := road.nearest_lane(dd, position.x)
	if not road.drivable(position.x, dd, -10.0):
		lane = road.lane_count(dd) / 2
	position.x = road.lane_x(dd, lane)
	rotation = road.heading(dd)
	state = State.RACING
	invuln = 2.0
	skid = 0.0
	oil_skid = 0.0
	speed = 0.0
	_sprite.visible = true
	queue_redraw()
	reset_physics_interpolation()
	world.clear_area(dd - 160.0, dd + 450.0)
	world.on_player_respawn(self)


## Brushed by another car without any penalty: just pushed aside.
func nudge(push_dir: float, overlap: float) -> void:
	position.x += push_dir * (overlap + 1.0)


func bump(push_dir: float, overlap: float) -> void:
	position.x += push_dir * (overlap + 1.0)
	if bump_cd > 0.0:
		return
	bump_cd = 0.7
	speed *= 0.5
	penalty = 5.0
	if not easy:
		# Knocked sideways and briefly out of control. (Easy mode keeps its grip so the
		# auto-steer is never shoved into the next hazard.)
		vx = push_dir * 260.0
		skid = 0.8
	world.on_player_bump(self)


func activate_super() -> void:
	super_t = 15.0


func _update_super(dt: float) -> void:
	if super_t <= 0.0 and not _super_visual:
		return
	super_t = maxf(0.0, super_t - dt)
	var on := super_t > 0.0 and (super_t > 3.0 or int(super_t * 6.0) % 2 == 0)
	if _sprite and _sprite.material is ShaderMaterial:
		(_sprite.material as ShaderMaterial).set_shader_parameter("rainbow", on)
	_super_visual = super_t > 0.0


## Snowbank: halve the speed and slide to the far side of the road.
func hit_snowbank() -> void:
	speed *= 0.5
	var road: Road = world.road
	var cu := position.x - road.center_x(d())
	var reach := road.half_width(d()) - EDGE_HW - 6.0
	slide_u = -signf(cu) * reach if absf(cu) > 1.0 else reach
	skid = 0.9


## Barrel: stops the car dead; the driver has to accelerate again.
func hit_barrel() -> void:
	stop_t = 0.6
	vx = 0.0


func hit_oil() -> void:
	if oil_skid <= 0.0 and invuln <= 0.0:
		oil_skid = 1.1
		world.on_player_oil(self)


func teleport_to(new_d: float) -> void:
	var road: Road = world.road
	var lane := road.lane_count(new_d) / 2
	position = Vector2(road.lane_x(new_d, lane), -new_d)
	rotation = road.heading(new_d)
	_last_d = new_d
	invuln = 1.5
	vx = 0.0
	reset_physics_interpolation()


func finish() -> void:
	if state == State.FINISHED:
		return
	state = State.FINISHED
	finish_d = d()
	_sprite.visible = true


func _draw() -> void:
	if state == State.RACING and braking:
		# Brake lights: tells everyone (and the player) why the car is slowing down.
		for sx in [-17.0, 17.0]:
			draw_rect(Rect2(sx - 6.0, hh + 2.0, 12.0, 6.0), Color("ff2a1a"))
			draw_circle(Vector2(sx, hh + 5.0), 11.0, Color(1.0, 0.1, 0.05, 0.35))
	if state != State.CRASHED:
		return
	var k := 1.0 - _crash_t / 1.6
	var r := 46.0 + k * 80.0
	var a := clampf(1.0 - k * 0.8, 0.0, 1.0)
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.45, 0.1, a * 0.9))
	draw_circle(Vector2.ZERO, r * 0.65, Color(1.0, 0.85, 0.2, a))
	draw_circle(Vector2.ZERO, r * 0.3, Color(1, 1, 1, a))
	for i in 10:
		var ang := TAU * i / 10.0 + k * 0.7
		var from := Vector2(cos(ang), sin(ang)) * (r * 0.7)
		var to := Vector2(cos(ang), sin(ang)) * (r * (1.1 + 0.5 * sin(i * 3.1)))
		draw_line(from, to, Color(1, 0.8, 0.3, a), 4.0)
	# charred car body
	draw_rect(Rect2(-hw, -hh * 0.6, hw * 2.0, hh * 1.2), Color(0.1, 0.1, 0.1, clampf(k * 2.0, 0.0, 0.8)))
