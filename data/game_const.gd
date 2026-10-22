class_name GameConst
## Constants shared by the autoloads and the screens. They live here, not in an autoload, so that
## every autoload can use them without depending on another autoload.

const MAX_PLAYERS := 2

## Hue shifts are relative to the red base sprite (Audi.png).
const COLORS := [
	{"name": "Red", "hue": 0.0, "sat": 1.0, "val": 1.0},
	{"name": "Orange", "hue": 0.07, "sat": 1.0, "val": 1.05},
	{"name": "Yellow", "hue": 0.14, "sat": 1.0, "val": 1.1},
	{"name": "Green", "hue": 0.33, "sat": 1.0, "val": 0.95},
	{"name": "Blue", "hue": 0.60, "sat": 1.0, "val": 1.0},
	{"name": "Purple", "hue": 0.76, "sat": 0.9, "val": 0.95},
	{"name": "Pink", "hue": 0.90, "sat": 0.55, "val": 1.15},
	{"name": "White", "hue": 0.0, "sat": 0.0, "val": 1.5},
]
