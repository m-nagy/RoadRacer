class_name Stages
## Stage definitions. Distances are in pixels (8 px = 1 displayed metre).
## lanes: [[from_y_fraction, lane_count], ...] interpolated smoothly.
## v_slow / v_fast: measured average speed (px/s) of a clean run in slow / fast gear (see Difficulty).
## traffic.mix: weight per rival kind. obstacles.kinds: cone, barrel, rock, oil, snowbank, tire.

const LANE_W := 88.0

const LIST := [
	{
		"name": "City Centre", "theme": "city", "weather": "none", "night": false,
		"length": 70000.0, "lanes": [[0.0, 4]],
		"curve": [[90.0, 4200.0], [40.0, 1700.0]],
		"ground": Color("6b7280"), "ground2": Color("5b6270"), "asphalt": Color("3d3f45"), "curb": Color("d6d6d6"),
		"traffic": {"density": 0.9, "speed": 0.8, "mix": {"taxi": 4, "van": 3, "pickup": 1, "viper": 1}},
		"obstacles": {"density": 0.3, "kinds": ["cone"]},
		"fuel": 1.1, "v_slow": 297.0, "v_fast": 401.0, "grip": 1.0, "drift": 0.0,
		"shortcuts": [{"at": 0.45, "skip": 4800.0, "hidden": false, "side": 1}],
	},
	{
		"name": "Countryside", "theme": "country", "weather": "leaves", "night": false,
		"length": 80000.0, "lanes": [[0.0, 4], [0.5, 3], [0.8, 4]],
		"curve": [[120.0, 3800.0], [50.0, 1600.0]],
		"ground": Color("5a9a45"), "ground2": Color("4f8a3c"), "asphalt": Color("45474d"), "curb": Color("e8e0c8"),
		"traffic": {"density": 1.2, "speed": 0.9, "mix": {"taxi": 3, "van": 2, "pickup": 3, "truck": 1, "viper": 1}},
		"obstacles": {"density": 0.5, "kinds": ["cone"]},
		"fuel": 1.0, "v_slow": 297.0, "v_fast": 401.0, "grip": 1.0, "drift": 0.0,
		"shortcuts": [{"at": 0.35, "skip": 5200.0, "hidden": false, "side": -1}],
	},
	{
		"name": "Seaside Bridge", "theme": "bridge", "weather": "wind", "night": false,
		"length": 90000.0, "lanes": [[0.0, 3], [0.3, 2], [0.5, 3], [0.8, 2]],
		"curve": [[110.0, 4000.0], [50.0, 1800.0]],
		"ground": Color("2f7fc4"), "ground2": Color("3a8fd6"), "asphalt": Color("4a4c52"), "curb": Color("ececec"),
		"traffic": {"density": 1.3, "speed": 1.0, "mix": {"taxi": 2, "van": 2, "pickup": 2, "viper": 2, "police": 1, "truck": 1}},
		"obstacles": {"density": 0.5, "kinds": ["barrel"]},
		"fuel": 0.95, "v_slow": 311.0, "v_fast": 420.0, "grip": 1.0, "drift": 0.0,
		"shortcuts": [{"at": 0.55, "skip": 5600.0, "hidden": true, "side": 1}],
	},
	{
		"name": "Desert Run", "theme": "desert", "weather": "sand", "night": false,
		"length": 100000.0, "lanes": [[0.0, 4], [0.35, 2], [0.55, 4], [0.85, 3]],
		"curve": [[150.0, 3600.0], [60.0, 1600.0]],
		"ground": Color("e0b862"), "ground2": Color("d3a84f"), "asphalt": Color("55504a"), "curb": Color("c9553a"),
		"traffic": {"density": 1.5, "speed": 1.1, "mix": {"taxi": 2, "pickup": 3, "viper": 3, "police": 1, "truck": 2, "ambulance": 1}},
		"obstacles": {"density": 0.8, "kinds": ["rock", "oil"]},
		"fuel": 0.9, "v_slow": 329.0, "v_fast": 444.0, "grip": 0.95, "drift": 0.0,
		"shortcuts": [{"at": 0.4, "skip": 6000.0, "hidden": true, "side": -1}],
	},
	{
		"name": "Snowy Mountains", "theme": "snow", "weather": "snow", "night": false,
		"length": 110000.0, "lanes": [[0.0, 3], [0.4, 2], [0.6, 3]],
		"curve": [[160.0, 3400.0], [60.0, 1500.0]],
		"ground": Color("e9f1f7"), "ground2": Color("d5e3ee"), "asphalt": Color("4b4f58"), "curb": Color("d33a3a"),
		"traffic": {"density": 1.7, "speed": 1.15, "mix": {"van": 2, "pickup": 2, "viper": 3, "police": 3, "truck": 3, "ambulance": 1}},
		"obstacles": {"density": 1.0, "kinds": ["snowbank", "cone", "barrel"]},
		"fuel": 0.9, "v_slow": 302.0, "v_fast": 408.0, "grip": 0.65, "drift": 0.0,
		"shortcuts": [{"at": 0.3, "skip": 6000.0, "hidden": true, "side": 1}, {"at": 0.7, "skip": 5200.0, "hidden": true, "side": -1}],
	},
	{
		"name": "Rainy Night City", "theme": "night", "weather": "rain", "night": true,
		"length": 120000.0, "lanes": [[0.0, 4], [0.3, 3], [0.55, 4], [0.8, 2]],
		"curve": [[150.0, 3400.0], [60.0, 1500.0]],
		"ground": Color("2a2f3d"), "ground2": Color("232837"), "asphalt": Color("2e3036"), "curb": Color("c9c9c9"),
		"traffic": {"density": 2.0, "speed": 1.25, "mix": {"taxi": 2, "van": 1, "pickup": 2, "viper": 4, "police": 3, "truck": 2, "ambulance": 2}},
		"obstacles": {"density": 1.2, "kinds": ["cone", "barrel", "oil", "tire"]},
		"fuel": 0.85, "v_slow": 318.0, "v_fast": 429.0, "grip": 0.7, "drift": 0.0,
		"shortcuts": [{"at": 0.25, "skip": 6400.0, "hidden": true, "side": -1}, {"at": 0.65, "skip": 5200.0, "hidden": true, "side": 1}],
	},
]

const CHECKPOINTS := [0.25, 0.5, 0.75]


static func get_stage(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]
