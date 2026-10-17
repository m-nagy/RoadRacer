class_name CarDefs
## Sprite, size and behaviour per rival kind. Speeds are px/s (1 km/h = 1.8 px/s).
## Only police and ambulance may be fast; everything else stays at or below the player's slow gear.
const SLOW_CAP := 340.0
const FAST_KINDS := ["police", "ambulance"]

const PLAYER := {"tex": "res://assets/cars/Audi.png", "scale": 0.46, "hw": 19.0, "hh": 42.0}

const KINDS := {
	"taxi": {"tex": "res://assets/cars/taxi.png", "scale": 0.46, "hw": 20.0, "hh": 43.0, "speed": 330.0, "behavior": "keeper"},
	"van": {"tex": "res://assets/cars/Mini_van.png", "scale": 0.5, "hw": 22.0, "hh": 52.0, "speed": 270.0, "behavior": "passive"},
	"pickup": {"tex": "res://assets/cars/Mini_truck.png", "scale": 0.48, "hw": 21.0, "hh": 48.0, "speed": 335.0, "behavior": "changer"},
	"viper": {"tex": "res://assets/cars/Black_viper.png", "scale": 0.46, "hw": 20.0, "hh": 43.0, "speed": 335.0, "behavior": "blocker"},
	"police": {"tex": "res://assets/cars/police/1.png", "frames": ["res://assets/cars/police/1.png", "res://assets/cars/police/2.png", "res://assets/cars/police/3.png"], "scale": 0.46, "hw": 20.0, "hh": 43.0, "speed": 500.0, "behavior": "rammer"},
	"truck": {"tex": "res://assets/cars/truck.png", "scale": 0.56, "hw": 21.0, "hh": 60.0, "speed": 220.0, "behavior": "keeper"},
	"ambulance": {"tex": "res://assets/cars/ambulance/1.png", "frames": ["res://assets/cars/ambulance/1.png", "res://assets/cars/ambulance/2.png", "res://assets/cars/ambulance/3.png"], "scale": 0.5, "hw": 22.0, "hh": 52.0, "speed": 780.0, "behavior": "passer"},
	"fuelcar": {"tex": "res://assets/cars/Car.png", "scale": 0.46, "hw": 20.0, "hh": 43.0, "speed": 290.0, "behavior": "keeper"},
}
