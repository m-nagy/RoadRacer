class_name StageVariant
extends Resource
## A challenge stage: an existing stage with another weather, time of day and length (and, if wanted,
## traffic, hazards, grip and wind). Nothing is copied by hand: build() takes the base stage and
## applies the differences, so a change to the base track shows up in its variants too.
## To add a challenge: duplicate one of the files in data/challenges/, change the fields, and list it in
## Stages.VARIANTS.

@export var id := ""                 # unique, used in the save file
@export var name := ""
@export var base: StageData          # the stage it is made from; clearing this unlocks the challenge
@export var weather: WeatherData     # null = the base stage's weather
@export_enum("inherit", "day", "night") var time_of_day := "inherit"
@export_range(0.2, 1.0) var length_scale := 0.5
@export var traffic_scale := 1.0     # multiplies the base's traffic density
@export var obstacle_scale := 1.0    # multiplies the base's hazard density
@export var grip := -1.0             # >= 0 replaces the track grip (the weather multiplies it)
@export var wind := -1.0             # >= 0 replaces the track's own crosswind (the weather adds its own)
@export var v_slow := 0.0            # measured speeds (see Difficulty); 0 = the base stage's
@export var v_fast := 0.0
@export var rng_seed := 0            # fixes the course; give each challenge its own


func build() -> StageData:
	var s: StageData = base.duplicate(true)   # a separate copy: the base stage is never touched
	s.id = id
	s.name = name
	s.rng_seed = rng_seed
	s.requires = base.id
	if weather != null:
		s.weather = weather
	if time_of_day != "inherit":
		s.night = time_of_day == "night"
	s.length = roundf(base.length * length_scale / 100.0) * 100.0
	s.traffic.density = base.traffic.density * traffic_scale
	s.obstacles.density = base.obstacles.density * obstacle_scale
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
