class_name DifficultyLevel
extends Resource
## One difficulty setting (see Difficulty for what the numbers are used for).

@export var label := ""
@export var allow := 5               # crashes a clean run can afford and still finish
@export var fuel_spacing := 6000.0   # px between fuel cans
@export var attack := 1.0            # how often blockers and police show up
@export var obstacles := 1.0         # hazard density multiplier
@export_range(0.0, 1.0) var speed_mix := 0.5   # 0 = driven in slow gear, 1 = in fast gear
