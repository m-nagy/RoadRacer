class_name StageVariant
extends Resource
## One playable stage: a track (a StageData in data/tracks/) with its own weather, time of day, length and
## difficulty tweaks. Nothing is copied by hand: build() takes the base track and applies the differences,
## so a change to the track shows up in every stage made from it.
## A world (see WorldData) lists three of these, each a little harder than the one before.

@export var id := ""                 # unique, used in the save file
@export var name := ""
@export_multiline var description := ""   # shown on the stage card
@export var base: StageData          # the track it is made from
@export var weather: WeatherData     # null = the track's weather
@export_enum("inherit", "day", "night") var time_of_day := "inherit"
@export_range(0.2, 1.0) var length_scale := 0.5
@export var lane_change := 0         # added to every lane section of 3 or more lanes (-1 = a narrower road, never below 2)
@export var curve_scale := 1.0       # multiplies how much the road bends
@export var traffic_scale := 1.0     # multiplies the track's traffic density
@export var traffic_speed_scale := 1.0   # multiplies the speed of the traffic
@export var obstacle_scale := 1.0    # multiplies the track's hazard density
@export var grip := -1.0             # >= 0 replaces the track grip (the weather multiplies it)
@export var wind := -1.0             # >= 0 replaces the track's own crosswind (the weather adds its own)
@export var v_slow := 0.0            # measured speeds (see Difficulty); 0 = the track's
@export var v_fast := 0.0
@export var rng_seed := 0            # fixes the course; give each stage its own


func build() -> StageData:
	var s: StageData = base.duplicate(true)   # a separate copy: the track itself is never touched
	s.id = id
	s.name = name
	s.description = description
	s.rng_seed = rng_seed
	if weather != null:
		s.weather = weather
	if time_of_day != "inherit":
		s.night = time_of_day == "night"
	s.length = roundf(base.length * length_scale / 100.0) * 100.0
	s.traffic.density = base.traffic.density * traffic_scale
	s.traffic.speed = base.traffic.speed * traffic_speed_scale
	s.obstacles.density = base.obstacles.density * obstacle_scale
	if lane_change != 0:
		var lanes_out: Array[LaneSection] = []
		for l in base.lanes:
			var c: LaneSection = l.duplicate()
			c.lanes = clampi(l.lanes + lane_change, mini(l.lanes, 2), 6) if l.lanes >= 3 else l.lanes
			lanes_out.append(c)
		s.lanes = lanes_out
	if curve_scale != 1.0:
		var curve_out: Array[CurveWave] = []
		for wv in base.curve:
			var c: CurveWave = wv.duplicate()
			c.amplitude = wv.amplitude * curve_scale
			curve_out.append(c)
		s.curve = curve_out
	if grip >= 0.0:
		s.grip = grip
	if wind >= 0.0:
		s.drift = wind
	if v_slow > 0.0:
		s.v_slow = v_slow
	if v_fast > 0.0:
		s.v_fast = v_fast
	# A shortcut skips less on a shorter stage, and one that would leave no road after it is dropped.
	s.shortcuts.clear()
	for sc in base.shortcuts:
		var skip := sc.skip * length_scale
		if sc.at * s.length + skip < s.length - 1500.0:
			var copy: ShortcutData = sc.duplicate()
			copy.skip = skip
			s.shortcuts.append(copy)
	return s
