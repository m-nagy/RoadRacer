class_name WeatherData
extends Resource
## A weather condition: how it looks (tint and particles) and how it changes the driving.

@export var id := "none"
@export var label := "Clear"
@export_range(0.3, 1.0) var grip := 1.0   # multiplier on the car's sideways grip
@export var wind := 0.0                   # crosswind strength (px/s pushing the car sideways)
@export var tint := Color(0, 0, 0, 0)     # laid over the whole screen
@export var layers: Array[WeatherLayer] = []

# Fog banks: drifting clouds that cover stretches of the road (see FogBanks). 0 = no fog banks.
@export_range(0.0, 0.9) var fog_banks := 0.0       # share of the road that lies in fog
@export var fog_color := Color(0.86, 0.89, 0.93)
@export_range(0.0, 1.0) var fog_alpha := 0.8       # thickness of the clouds
@export_range(0.0, 1.0) var fog_haze := 0.2        # screen haze while the player is inside a bank
