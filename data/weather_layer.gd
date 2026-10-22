class_name WeatherLayer
extends Resource
## One kind of particle in a weather: rain drops, snowflakes, wind streaks...

enum Shape { STREAK, DOT, BLOB }   # BLOB: a soft round puff (fog)

@export var amount := 100
@export var lifetime := 1.0
@export var direction := Vector2(0.0, 1.0)
@export var speed := 500.0
@export var shape := Shape.STREAK
@export var color := Color.WHITE
@export var scale := 1.0
@export var horizontal := false   # blows in from the right edge instead of falling from the top
