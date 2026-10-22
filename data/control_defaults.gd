class_name ControlDefaults
## Default key / gamepad bindings for the two player profiles.

const ACTIONS := ["left", "right", "up", "down", "slow", "fast", "pause"]
const ACTION_NAMES := {"left": "Left", "right": "Right", "up": "Up", "down": "Down / Brake",
	"slow": "Slow speed", "fast": "Fast speed", "pause": "Pause"}


static func profile(slot: int) -> Dictionary:
	var kb := {"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S, "slow": KEY_G, "fast": KEY_H, "pause": KEY_ESCAPE}
	if slot == 1:
		kb = {"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN, "slow": KEY_K, "fast": KEY_L, "pause": KEY_ESCAPE}
	var pad := {
		"left": [{"t": "b", "i": JOY_BUTTON_DPAD_LEFT}, {"t": "a", "i": JOY_AXIS_LEFT_X, "v": -1.0}],
		"right": [{"t": "b", "i": JOY_BUTTON_DPAD_RIGHT}, {"t": "a", "i": JOY_AXIS_LEFT_X, "v": 1.0}],
		"up": [{"t": "b", "i": JOY_BUTTON_DPAD_UP}, {"t": "a", "i": JOY_AXIS_LEFT_Y, "v": -1.0}],
		"down": [{"t": "b", "i": JOY_BUTTON_DPAD_DOWN}, {"t": "a", "i": JOY_AXIS_LEFT_Y, "v": 1.0}],
		"slow": [{"t": "b", "i": JOY_BUTTON_A}],
		"fast": [{"t": "b", "i": JOY_BUTTON_B}],
		"pause": [{"t": "b", "i": JOY_BUTTON_START}],
	}
	return {"kb": kb, "pad": pad}
