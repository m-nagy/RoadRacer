class_name CarDefs
## Sprite, size and behaviour per rival kind (CarKind resources in data/cars/). Speeds are px/s
## (1 km/h = 1.8 px/s).
## Only police and ambulance may be fast; everything else stays at or below the player's slow gear.
const SLOW_CAP := 340.0
const FAST_KINDS := ["police", "ambulance"]

const PLAYER: CarKind = preload("res://data/cars/player.tres")

const KINDS: Dictionary[String, CarKind] = {
	"taxi": preload("res://data/cars/taxi.tres"),
	"van": preload("res://data/cars/van.tres"),
	"pickup": preload("res://data/cars/pickup.tres"),
	"viper": preload("res://data/cars/viper.tres"),
	"police": preload("res://data/cars/police.tres"),
	"truck": preload("res://data/cars/truck.tres"),
	"ambulance": preload("res://data/cars/ambulance.tres"),
	"fuelcar": preload("res://data/cars/fuelcar.tres"),
}
