extends Node
## Developer-only bot used for automated checks. It only runs in debug builds (it frees itself in
## exported releases) and talks to the game through its public methods and signals. Activated by command line:
##   godot --path . -- --autotest stage=2 players=2 easy=1 seconds=60 gear=fast shots=5,15,30
## Drives the real game with the AutoPilot, prints stats and saves screenshots to user://autotest/.

var enabled := false
var stage_id := "city_1"
var players := 1
var easy := true
var seconds := 60.0
var gear := "fast"
var shots: Array = [5.0, 15.0]
var scale := 1.0
var title_mode := false
var steer_test := false
var title_screen := 0
var title_tab := 0
var title_fill := false
var pad_log := false
var flow := ""
var keydrive := false
var _kd_state := {}
var _flow_i := 0
var diff := ""
var gpu_mode := false   # gpu: measure and print the GPU time of every viewport (needs a real window, not --headless)
var _gpu_viewports: Array[RID] = []
var _gpu_sum: Array[float] = []
var _gpu_n := 0
var cleared_arg := ""   # cleared=city,bridge: pretend only these stages are cleared (in memory only)
var no_time := false
var hit_kind := ""
var police_at := -1.0
var _police_log := 0.0
var want_super := false
var _hit_done := false
var _hit_t := -1.0
var crashes_forced := 0
var _forced_done := 0
var _pad_t := 0.0
var _title_shown := false
var shortcut_test := false
var jump := 0.0
var pause_at := -1.0
var _jumped := false
var force_crash := -1.0
var _crashed := false
var _paused := false
var _t := 0.0
var _next_stat := 5.0
var stat_every := 5.0
var _started := false
var _shot_done: Dictionary = {}
var _race: Node = null


## `stage=7` (the 7th stage of the game), `stage=3-1` (world 3, stage 1) or a stage id.
func _parse_stage(v: String) -> String:
	var list := Stages.all()
	if v.is_valid_int():
		return list[clampi(int(v) - 1, 0, list.size() - 1)].id
	var parts := v.split("-")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		var world := Stages.WORLDS[clampi(int(parts[0]) - 1, 0, Stages.WORLDS.size() - 1)]
		return world.stages[clampi(int(parts[1]) - 1, 0, world.stages.size() - 1)].id
	return v


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			enabled = true
		elif a.begins_with("stage="):
			var v := a.get_slice("=", 1)
			stage_id = _parse_stage(v)
		elif a.begins_with("players="):
			players = int(a.get_slice("=", 1))
		elif a.begins_with("easy="):
			easy = a.get_slice("=", 1) == "1"
		elif a.begins_with("seconds="):
			seconds = float(a.get_slice("=", 1))
		elif a.begins_with("gear="):
			gear = a.get_slice("=", 1)
		elif a == "shortcut":
			shortcut_test = true
		elif a.begins_with("jump="):
			jump = float(a.get_slice("=", 1))
		elif a.begins_with("forcecrash="):
			force_crash = float(a.get_slice("=", 1))
		elif a.begins_with("pause="):
			pause_at = float(a.get_slice("=", 1))
		elif a.begins_with("stat="):
			stat_every = float(a.get_slice("=", 1))
			_next_stat = stat_every
		elif a == "boxes":
			Game.debug_boxes = true
		elif a.begins_with("screen="):
			title_screen = int(a.get_slice("=", 1))
		elif a.begins_with("tab="):
			title_tab = int(a.get_slice("=", 1))
		elif a.begins_with("graphics="):
			SaveManager.graphics = a.get_slice("=", 1)
		elif a == "gpu":
			gpu_mode = true
		elif a.begins_with("cleared="):
			cleared_arg = a.get_slice("=", 1)
		elif a.begins_with("diff="):
			diff = a.get_slice("=", 1)
		elif a == "notime":
			no_time = true
		elif a.begins_with("police="):
			police_at = float(a.get_slice("=", 1))
		elif a.begins_with("hit="):
			hit_kind = a.get_slice("=", 1)
		elif a == "super":
			want_super = true
		elif a.begins_with("crashes="):
			crashes_forced = int(a.get_slice("=", 1))
		elif a == "keydrive":
			keydrive = true
		elif a.begins_with("flow="):
			flow = a.get_slice("=", 1)
		elif a == "padlog":
			pad_log = true
		elif a == "fill":
			title_fill = true
		elif a == "steertest":
			steer_test = true
		elif a == "title":
			title_mode = true
		elif a.begins_with("scale="):
			scale = float(a.get_slice("=", 1))
		elif a.begins_with("shots="):
			shots = []
			for s in a.get_slice("=", 1).split(","):
				shots.append(float(s))
	if not enabled or not OS.is_debug_build():
		enabled = false
		queue_free()
		return
	AutoPilot.record_history = true
	SaveManager.save_path = "user://autotest/save.json"   # runs never touch the real save
	DirAccess.make_dir_recursive_absolute("user://autotest")
	Engine.time_scale = scale if scale > 0.0 else 1.0
	call_deferred("_begin")


func _begin() -> void:
	Game.reset_players()
	for i in players:
		Game.players[i].active = true
		Game.players[i].easy = easy
		Game.players[i].color = [0, 4][i]
		Game.players[i].ready = true
		InputManager.assign_keyboard(i)
	Game.prefs_applied = true
	if diff != "":
		SaveManager.difficulty = diff
	if cleared_arg != "":
		SaveManager.cleared.assign(Array(cleared_arg.split(",")) if cleared_arg != "none" else [])
	if title_mode:
		for i in players:
			Game.players[i].ready = false
		if players == 2 and OS.get_cmdline_user_args().has("padp2"):
			InputManager.assign_pad(1, 0)  # show what a gamepad player's card looks like
		_started = true
		get_tree().change_scene_to_file("res://scenes/title/title.tscn")
		return
	Game.go_to_race(stage_id)
	_started = true
	print("[autotest] stage=%d players=%d easy=%s gear=%s seconds=%.0f tracks=%d impacts=%s -> %s" % [Stages.index_of(stage_id) + 1, players, easy, gear, seconds, AudioManager.track_count(), str(AudioManager.impact_families()), ProjectSettings.globalize_path("user://autotest")])


func _process(delta: float) -> void:
	if not _started:
		return
	var scene := get_tree().current_scene
	if title_mode:
		_t += delta
		if pad_log:
			_pad_t -= delta
			if _pad_t <= 0.0:
				_pad_t = 0.5
				for dev in Input.get_connected_joypads():
					var b := []
					for i in JOY_BUTTON_SDL_MAX:
						if Input.is_joy_button_pressed(dev, i):
							b.append(i)
					var ax := []
					for a in JOY_AXIS_SDL_MAX:
						var v := Input.get_joy_axis(dev, a)
						if absf(v) > 0.2:
							ax.append("%d:%.2f" % [a, v])
					print("[padlog] t=%.1f dev=%d name=%s guid=%s buttons=%s axes=%s blocked=%s" % [_t, dev, Input.get_joy_name(dev), Input.get_joy_guid(dev), str(b), str(ax), str(InputManager.blocked_inputs(dev))])
		if flow != "":
			_run_flow(scene)
		if _t > 0.5 and flow == "" and not _title_shown and scene != null and scene.has_method("show_screen"):
			_title_shown = true
			scene.show_screen(title_screen)
			if title_screen == 2 and title_fill:
				var devs: Array = scene.players_screen.devices
				devs[0]["pos"] = -1
				devs[1]["pos"] = 1
			if title_screen == 4 and title_tab == 1:
				scene.options_screen.select_tab(1)
		for s in shots:
			if _t >= s and not _shot_done.has(s):
				_shot_done[s] = true
				get_viewport().get_texture().get_image().save_png("user://autotest/title_%03d.png" % int(s * 10))
		if _t >= seconds:
			get_tree().quit()
		return
	if scene == null or scene.get("world") == null:
		return
	var world: World = scene.world
	if not world.running:
		return
	if world != _world:
		_world = world
		for p in world.players:
			p.crashed.connect(_on_player_crashed.bind(p))
	_t += delta
	_sample_perf()
	_sample_gpu()
	if keydrive:
		_kd("h", _t > 1.0)                         # P1 default fast key
		_kd("d", _t > 3.0 and _t < 3.4)            # P1 default right key
		if int(_t * 10.0) % 5 == 0:
			var q: PlayerCar = world.players[0]
			print("[keydrive] t=%.1f v=%.0f u=%.1f" % [_t, q.speed, q.position.x - world.road.center_x(q.d())])
	for i in players:
		if gear != "none" and not keydrive:
			Input.action_press("p%d_%s" % [i, "fast" if gear == "fast" else "slow"])
	if jump > 0.0 and not _jumped:
		_jumped = true
		for p in world.players:
			p.teleport_to(world.road.length * jump)
			p.next_cp = world.road.checkpoints.size()
	if pause_at >= 0.0 and _t >= pause_at and not _paused:
		_paused = true
		scene.open_pause()
	if force_crash >= 0.0 and _t >= force_crash and not _crashed:
		_crashed = true
		world.players[0].crash("forced")
	if no_time:
		for p in world.players:
			p.time_left = maxf(p.time_left, 500.0)
	if want_super and _t > 1.0:
		for p in world.players:
			if p.super_t < 5.0:
				p.activate_super()
	if crashes_forced > 0 and _forced_done < crashes_forced:
		# spread the forced crashes evenly over the length of the stage
		var p1: PlayerCar = world.players[0]
		if p1.state == PlayerCar.State.RACING and p1.d() > world.road.length * float(_forced_done + 1) / float(crashes_forced + 1):
			_forced_done += 1
			p1.crash("forced")
	if hit_kind != "" and not _hit_done and _t > 2.0:
		_hit_done = true
		_hit_t = _t
		var hp: PlayerCar = world.players[0]
		var kinds_to_place := [hit_kind]
		if hit_kind == "all":
			kinds_to_place = ["cone", "barrel", "rock", "snowbank", "tire", "oil"]
		for k in kinds_to_place.size():
			var row: int = k / 3
			var col: int = k % 3
			var ox := hp.position.x if hit_kind != "all" else world.road.lane_x(hp.d() + 250.0, col)
			world.course.place_obstacle(kinds_to_place[k], Vector2(ox, hp.position.y - 330.0 - row * 190.0))
		print("[hit] placed %s ahead: p d=%.0f u=%.0f v=%.0f" % [hit_kind, hp.d(), hp.position.x - world.road.center_x(hp.d()), hp.speed])
	if _hit_t > 0.0 and _t < _hit_t + 4.0:
		var q: PlayerCar = world.players[0]
		print("[hit] t=+%.2f v=%.0f u=%.0f state=%d crashes=%d skid=%.1f stop=%.1f slide=%s rivals=%d siren_police=%s(%.0f dB) siren_amb=%s" % [_t - _hit_t, q.speed, q.position.x - world.road.center_x(q.d()), q.state, q.crashes, q.skid, q.stop_t, str(q.slide_u), world.rivals.size(), AudioManager.siren_playing("police"), AudioManager.siren_volume_db("police"), AudioManager.siren_playing("ambulance")])
	if police_at >= 0.0 and _t >= police_at:
		var pp: PlayerCar = world.players[0]
		if _police_log == 0.0:
			world.traffic.call_police(pp)
			_police_log = _t
		if _t >= _police_log and _t < police_at + 15.0:
			_police_log = _t + 0.5
			var line := "[police] t=%.1f player v=%.0f lane=%d bumps=%.1f |" % [_t - police_at, pp.speed, world.road.nearest_lane(pp.d(), pp.position.x), pp.penalty]
			for r in world.rivals:
				if r.kind == "police":
					line += " police ahead_by=%.0f v=%.0f lane=%d chasing=%s free=%s" % [r.d() - pp.d(), r.speed, r.lane_now(), r.chase != null, r.is_chasing()]
			print(line)
	if shortcut_test:
		_drive_shortcut(world)
	if steer_test:
		var p0: PlayerCar = world.players[0]
		var pressing := _t >= 2.0 and _t < 2.4
		if pressing:
			Input.action_press("p0_right")
		else:
			Input.action_release("p0_right")
		if _t >= 1.95 and _t < 3.3:
			print("[steer] t=%.2f pressing=%s u=%.1f vx=%.0f rot=%.3f head=%.3f" % [_t, pressing, p0.position.x - world.road.center_x(p0.d()), p0.vx, p0.rotation, world.road.heading(p0.d())])
	for s in shots:
		if _t >= s and not _shot_done.has(s):
			_shot_done[s] = true
			var img := get_viewport().get_texture().get_image()
			var path := "user://autotest/s%s_p%d_%03d.png" % [stage_id, players, int(s * 10)]
			img.save_png(path)
			print("[autotest] screenshot ", ProjectSettings.globalize_path(path))
	_audit_rivals(world)
	_audit_narrow(world)
	if _t >= _next_stat:
		_next_stat += stat_every
		var line := "[autotest] t=%.0f" % _t
		for p in world.players:
			line += " | P%d d=%.0f/%.0f v=%.0f u=%.1f rot=%.2f time=%.0f crashes=%d state=%d score=%d" % [p.slot + 1, p.d(), world.road.length, p.speed, p.position.x - world.road.center_x(p.d()), p.rotation, p.time_left, p.crashes, p.state, int(p.score)]
		if world.players[0].pilot:
			line += " | " + world.players[0].pilot.debug
		print(line, " rivals=", world.rivals.size(), " fps=", Engine.get_frames_per_second(), " audit: offroad=", _off_road, " on_obstacle=", _on_obstacle, " fast_bad=", _fast_bad, " overlaps=", _overlaps, " walls=", _walls, " police_near=", _police_near)
		for p in world.players:
			if p.pilot and p.speed < 50.0 and p.state == PlayerCar.State.RACING:
				print("   stuck: ", p.pilot.history.back() if not p.pilot.history.is_empty() else "")
	var done := _t >= seconds
	for p in world.players:
		if p.state == PlayerCar.State.FINISHED and jump <= 0.0:
			done = true
	if done:
		var wp: PlayerCar = world.players[0]
		var cr := 0
		for q in world.players:
			cr += q.crashes
		var eff: float = world.road.length / maxf(world.t - cr * Difficulty.CRASH_COST / float(world.players.size()), 1.0)
		for q in world.players:
			print("[totals] P%d score=%d crashes=%d overtakes=%d state=%d d=%.0f" % [q.slot + 1, int(q.score), q.crashes, q.overtakes, q.state, q.d()])
		print("[narrow] ticks=%d slow=%d share=%.1f%% avg_v=%.0f walls=%d" % [_narrow_ticks, _narrow_slow, 100.0 * _narrow_slow / maxf(_narrow_ticks, 1), _narrow_v / maxf(_narrow_ticks, 1), _walls_narrow])
		if gpu_mode and _gpu_n > 0:
			var g := "[gpu] frames=%d" % _gpu_n
			for i in _gpu_sum.size():
				g += "  %s=%.2f ms" % ["window" if i == 0 else "view%d" % i, _gpu_sum[i] / _gpu_n]
			print(g)
		print("[perf] samples=%d process_ms avg=%.3f max=%.3f | physics_ms avg=%.3f max=%.3f" % [_perf_n, _perf_proc / maxf(_perf_n, 1), _perf_proc_max, _perf_phys / maxf(_perf_n, 1), _perf_phys_max])
		print("[autotest] finished at t=%.1f  sim_t=%.1f length=%.0f crashes=%d  v_eff=%.0f px/s  state=%d time_left=%.0f fuel=%d/%d" % [_t, world.t, world.road.length, cr, eff, wp.state, wp.time_left, world.course.pickups_taken, world.course.pickups_total])
		get_tree().quit()


var _perf_n := 0
var _perf_proc := 0.0
var _perf_proc_max := 0.0
var _perf_phys := 0.0
var _perf_phys_max := 0.0


## Engine-reported cost (ms) of the last frame's idle-process and physics-process steps.
var _world: World   # the race whose players' crashes are being logged


func _on_player_crashed(reason: String, impact_speed: float, p: PlayerCar) -> void:
	print("[crash] P%d d=%.0f v=%.0f x=%.0f road=%.0f reason=%s" % [p.slot + 1, p.d(), impact_speed, p.position.x, _world.road.center_x(p.d()), reason])
	if p.pilot:
		for h in p.pilot.history.slice(-14):
			print("   ", h)


## GPU time (ms) per frame of the window and of every player's view; the first frame only switches
## the measuring on.
func _sample_gpu() -> void:
	if not gpu_mode:
		return
	if _gpu_viewports.is_empty():
		_gpu_viewports.append(get_tree().root.get_viewport_rid())
		for sv in get_tree().current_scene.find_children("*", "SubViewport", true, false):
			_gpu_viewports.append(sv.get_viewport_rid())
		for rid in _gpu_viewports:
			RenderingServer.viewport_set_measure_render_time(rid, true)
			_gpu_sum.append(0.0)
		return
	_gpu_n += 1
	for i in _gpu_viewports.size():
		_gpu_sum[i] += RenderingServer.viewport_get_measured_render_time_gpu(_gpu_viewports[i])


func _sample_perf() -> void:
	var pr := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var ph := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_perf_n += 1
	_perf_proc += pr
	_perf_phys += ph
	_perf_proc_max = maxf(_perf_proc_max, pr)
	_perf_phys_max = maxf(_perf_phys_max, ph)


func _drive_shortcut(world: World) -> void:
	for p in world.players:
		var road := world.road
		var d: float = p.d()
		var target_x: float = road.lane_x(d, 1)
		for sh in road.shortcuts:
			if d > sh.d0 - 600.0 and d < sh.d1 + 50.0:
				var hw := road.half_width(d)
				if d < sh.d0 + 10.0:
					target_x = road.lane_x(d, 0 if sh.side < 0 else road.lane_count(d) - 1)
				else:
					target_x = road.center_x(d) + sh.side * (hw + road.STRIP_W * 0.5)
		var err: float = target_x - p.position.x
		var l := "p%d_left" % p.slot
		var r := "p%d_right" % p.slot
		Input.action_release(l)
		Input.action_release(r)
		if err < -4.0:
			Input.action_press(l, clampf(-err / 40.0, 0.2, 1.0))
		elif err > 4.0:
			Input.action_press(r, clampf(err / 40.0, 0.2, 1.0))


var _off_road := 0
var _on_obstacle := 0
var _fast_bad := 0
var _overlaps := 0
var _walls := 0
var _police_near := 0
var _narrow_ticks := 0
var _narrow_slow := 0
var _narrow_v := 0.0
var _walls_narrow := 0   # walls (every lane blocked) ahead of a player on a road of two lanes or fewer


## Time fast-gear players spend on roads with two lanes or fewer, and how much of it they are held
## below 90% of top speed (by traffic): the road should leave room to pass at full speed.
func _audit_narrow(world: World) -> void:
	for p in world.players:
		if p.state != PlayerCar.State.RACING or p.target_speed < PlayerCar.FAST_MAX:
			continue
		if world.road.lane_count(p.d()) > 2:
			continue
		_narrow_ticks += 1
		_narrow_v += p.speed
		if p.speed < PlayerCar.FAST_MAX * 0.9:
			_narrow_slow += 1


## Counts (cumulatively) rival cars that leave the road, drive over obstacles, or are too fast.
func _audit_rivals(world: World) -> void:
	for r in world.rivals:
		var d: float = r.d()
		if not world.road.drivable(r.position.x, d, -2.0) or absf(r.position.x - world.road.center_x(d)) > world.road.half_width(d) - r.hw + 2.0:
			_off_road += 1
		for o in world.obstacles:
			if absf(o.d() - d) < o.hh + r.hh - 6.0 and absf(o.position.x - r.position.x) < o.hw + r.hw - 6.0:
				_on_obstacle += 1
				if _on_obstacle < 4:
					print("   [audit] %s over %s: rival d=%.0f x=%.0f lane_pos=%.2f target=%d speed=%.0f blocked=%s free=%s | obstacle d=%.0f x=%.0f" % [r.kind, o.kind, d, r.position.x, r.lane_pos, r.target_lane, r.speed, r.is_blocked(), r.is_chasing(), o.d(), o.position.x])
		if not CarDefs.FAST_KINDS.has(r.kind) and r.speed > CarDefs.SLOW_CAP + 1.0:
			_fast_bad += 1
		if r.chase != null and absf(r.d() - r.chase.d()) < 120.0:
			_police_near += 1
	# Rival cars drawn on top of each other.
	for i in world.rivals.size():
		for j in range(i + 1, world.rivals.size()):
			var a: Rival = world.rivals[i]
			var b: Rival = world.rivals[j]
			if absf(a.d() - b.d()) < a.hh + b.hh - 3.0 and absf(a.position.x - b.position.x) < a.hw + b.hw - 3.0:
				_overlaps += 1
				if _overlaps <= 10:
					print("   [overlap] %s(d=%.0f x=%.0f lp=%.2f tl=%d v=%.0f blk=%s free=%s) vs %s(d=%.0f x=%.0f lp=%.2f tl=%d v=%.0f blk=%s free=%s)" % [a.kind, a.d(), a.position.x, a.lane_pos, a.target_lane, a.speed, a.is_blocked(), a.is_chasing(), b.kind, b.d(), b.position.x, b.lane_pos, b.target_lane, b.speed, b.is_blocked(), b.is_chasing()])
	# Stretches of road ahead of a player where every lane is blocked (no way through).
	for p in world.players:
		if p.state != PlayerCar.State.RACING:
			continue
		var sd: float = p.d() + 150.0
		while sd < p.d() + 1000.0:
			var n := world.road.lane_count(sd)
			var used := {}
			var cars := 0
			for r in world.rivals:
				if r.kind != "fuelcar" and absf(r.d() - sd) < r.hh + 28.0:
					used[world.road.nearest_lane(r.d(), r.position.x)] = true
					cars += 1
			for o in world.obstacles:
				if absf(o.d() - sd) < o.hh + 28.0:
					used[world.road.nearest_lane(o.d(), o.position.x)] = true
			if used.size() >= n and cars >= 2:
				_walls += 1
				if n <= 2:
					_walls_narrow += 1
				break
			sd += 40.0


# --- scripted menu walk-through (keyboard or gamepad events), to check navigation end to end ---

func _key(code: int) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)


func _pad(button: int) -> void:
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = 0
		e.button_index = button
		e.pressed = pressed
		Input.parse_input_event(e)


## The same button on pad 0 and pad 1 at once, as a DS4Windows virtual pad copying a real one.
func _pad_twin(button: int) -> void:
	for pressed in [true, false]:
		for dev in [0, 1]:
			var e := InputEventJoypadButton.new()
			e.device = dev
			e.button_index = button
			e.pressed = pressed
			Input.parse_input_event(e)


func _shot(name_: String) -> void:
	if DisplayServer.get_name().to_lower() != "headless" and get_viewport().get_texture() != null:
		get_viewport().get_texture().get_image().save_png("user://autotest/flow_%s.png" % name_)


func _run_flow(scene: Node) -> void:
	# step list: [time, action]; action = "key:<code>" / "pad:<button>" / "shot:<name>" / "say"
	var steps: Array = []
	if flow == "kb":
		steps = [[0.8, "key:%d" % KEY_ENTER], [1.6, "key:%d" % KEY_A], [2.0, "key:%d" % KEY_RIGHT], [2.6, "shot:players"],
			[2.8, "key:%d" % KEY_ENTER], [3.6, "shot:cars"], [3.8, "key:%d" % KEY_ESCAPE], [4.6, "shot:back_to_players"],
			[4.8, "key:%d" % KEY_ENTER], [5.6, "key:%d" % KEY_ENTER], [8.0, "say"]]
	elif flow == "mirror":
		steps = [[0.8, "twin:%d" % JOY_BUTTON_DPAD_DOWN], [1.0, "focus"], [1.2, "twin:%d" % JOY_BUTTON_DPAD_DOWN], [1.4, "focus"],
			[1.6, "twin:%d" % JOY_BUTTON_DPAD_DOWN], [1.8, "focus"], [2.0, "twin:%d" % JOY_BUTTON_DPAD_UP], [2.2, "focus"], [2.4, "say"]]
	elif flow == "color":
		steps = [[0.8, "key:%d" % KEY_ENTER], [1.4, "key:%d" % KEY_A], [1.8, "key:%d" % KEY_ENTER], [2.6, "color"],
			[2.8, "kdown:%d" % KEY_D], [2.9, "kup:%d" % KEY_D], [3.0, "color"], [3.2, "kdown:%d" % KEY_D], [3.3, "kup:%d" % KEY_D],
			[3.4, "color"], [3.6, "kdown:%d" % KEY_A], [3.7, "kup:%d" % KEY_A], [3.8, "color"],
			[4.0, "kdown:%d" % KEY_W], [4.1, "kup:%d" % KEY_W], [4.2, "color"], [4.4, "shot:cars_color"]]
	elif flow == "remap":
		steps = [[0.8, "call:open_controls"], [1.0, "call:cap_kb_left"], [1.6, "key:%d" % KEY_F], [2.0, "call:report"],
			[2.2, "call:cap_pad_slow"], [2.8, "pad:%d" % JOY_BUTTON_X], [3.2, "call:report"], [3.4, "call:cap_kb_fast"], [4.0, "key:%d" % KEY_A],
			[4.4, "call:report"], [4.6, "call:reset"], [4.8, "call:report"]]
	else:
		steps = [[0.8, "pad:%d" % JOY_BUTTON_DPAD_DOWN], [1.2, "pad:%d" % JOY_BUTTON_DPAD_DOWN], [1.6, "pad:%d" % JOY_BUTTON_DPAD_DOWN],
			[1.8, "shot:home_down3"], [2.0, "pad:%d" % JOY_BUTTON_A], [2.8, "shot:options"], [3.0, "pad:%d" % JOY_BUTTON_B],
			[3.8, "shot:home_again"], [4.0, "pad:%d" % JOY_BUTTON_A], [4.8, "shot:players_pad"], [5.0, "pad:%d" % JOY_BUTTON_B],
			[5.8, "say"]]
	while _flow_i < steps.size() and _t >= steps[_flow_i][0]:
		var act: String = steps[_flow_i][1]
		_flow_i += 1
		if act.begins_with("key:"):
			_key(int(act.get_slice(":", 1)))
		elif act.begins_with("pad:"):
			_pad(int(act.get_slice(":", 1)))
		elif act.begins_with("kdown:") or act.begins_with("kup:"):
			var e := InputEventKey.new()
			e.physical_keycode = int(act.get_slice(":", 1)) as Key
			e.keycode = e.physical_keycode
			e.pressed = act.begins_with("kdown:")
			Input.parse_input_event(e)
		elif act.begins_with("twin:"):
			_pad_twin(int(act.get_slice(":", 1)))
		elif act == "focus":
			var fo := get_viewport().gui_get_focus_owner()
			print("[flow] focus = ", str(fo.get("text")).get_slice("  ", 0) if fo else "<none>", "  mirrors=", InputManager.mirrored_pads())
		elif act == "color":
			print("[flow] screen=%s P1 color=%s (%s) easy=%s" % [scene.get("screen"), str(Game.players[0].color), Game.COLORS[Game.players[0].color]["name"], Game.players[0].easy])
		elif act.begins_with("call:"):
			var o: OptionsScreen = scene.options_screen
			match act.get_slice(":", 1):
				"open_controls":
					scene.show_screen(4)
					o.select_tab(1)
				"cap_kb_left": o.start_capture("kb", "left")
				"cap_pad_slow": o.start_capture("pad", "slow")
				"cap_kb_fast": o.start_capture("kb", "fast")
				"reset":
					SaveManager.reset_controls(0)
					o.refresh_cells()
				"report":
					var pr: Dictionary = SaveManager.controls[0]
					var saved = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.save_path))
					print("[remap] kb left=%s fast=%s slow=%s  pad slow=%s | on disk: left=%s | other player kb left=%s fast=%s" % [InputManager.key_label(pr["kb"]["left"]), InputManager.key_label(pr["kb"]["fast"]), InputManager.key_label(pr["kb"]["slow"]), str(pr["pad"]["slow"]), str(saved["controls"][0]["kb"]["left"]), InputManager.key_label(SaveManager.controls[1]["kb"]["left"]), InputManager.key_label(SaveManager.controls[1]["kb"]["fast"])])
		elif act.begins_with("shot:"):
			_shot(act.get_slice(":", 1))
		elif act == "say":
			print("[flow] usable pads = ", InputManager.usable_pads(), " connected = ", Input.get_connected_joypads(), " tex=", load("res://assets/ui/panel_grey_dark.png"))
			print("[flow] current scene = ", scene.name, "  screen=", scene.get("screen"), "  players active=", Game.active_slots(), " kb=", Game.players.map(func(p): return p.kb))


func _kd(which: String, down: bool) -> void:
	if _kd_state.get(which, false) == down:
		return
	_kd_state[which] = down
	var e := InputEventKey.new()
	e.physical_keycode = {"h": KEY_H, "d": KEY_D}[which]
	e.keycode = e.physical_keycode
	e.pressed = down
	Input.parse_input_event(e)
