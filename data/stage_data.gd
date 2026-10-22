class_name StageData
extends Resource
## Everything that makes one stage what it is. Distances are in pixels (8 px = 1 displayed metre).
## v_slow / v_fast: measured average speed (px/s) of a clean run in slow / fast gear (see Difficulty).

@export var id := ""             # unique, used in the save file and to pick the stage
@export var name := ""
@export var rng_seed := 0        # fixes the course (obstacles, fuel cans, scenery) of this stage
@export var requires := ""       # id of the stage that must be cleared first (challenges); empty = by list order
@export_enum("city", "country", "bridge", "desert", "snow", "night") var theme := "city"
@export var weather: WeatherData     # looks and handling of the weather (data/weather/)
@export var night := false
@export var length := 70000.0
@export var lanes: Array[LaneSection] = []
@export var curve: Array[CurveWave] = []
@export var ground := Color.WHITE
@export var ground2 := Color.WHITE
@export var asphalt := Color.WHITE
@export var curb := Color.WHITE
@export var traffic: TrafficData
@export var obstacles: ObstacleData
@export var fuel := 1.0          # fuel can spacing factor (higher = more cans)
@export var v_slow := 300.0
@export var v_fast := 400.0
@export var grip := 1.0          # grip of the track itself; the weather multiplies it
@export var drift := 0.0         # crosswind of the track itself; the weather adds its own
@export var shortcuts: Array[ShortcutData] = []
