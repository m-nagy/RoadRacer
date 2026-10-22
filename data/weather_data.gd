class_name WeatherData
extends Resource
## A weather condition: how it looks (tint and particles) and how it changes the driving.

@export var id := "none"
@export var label := "Clear"
@export_range(0.3, 1.0) var grip := 1.0   # multiplier on the car's sideways grip
@export var wind := 0.0                   # crosswind strength (px/s pushing the car sideways)
@export var tint := Color(0, 0, 0, 0)     # laid over the whole screen
@export var layers: Array[WeatherLayer] = []
