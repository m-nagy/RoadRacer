class_name Difficulty
## Difficulty levels and the time budget they imply.
##
## The timer starts at 100. The rest of the time a race needs comes from the three checkpoints
## (and fuel cans). Each stage stores how fast a clean bot drives it in slow gear and in fast gear
## (v_slow / v_fast, measured with the autotest bot), so the checkpoint bonus can be worked out so
## that:  Easy = up to 10 crashes still finishes (even in slow gear),
##        Normal = up to 5 crashes (mixed gears),  Hard = a clean race in fast gear.

const LEVELS: Dictionary[String, DifficultyLevel] = {
	"easy": preload("res://data/difficulty/easy.tres"),
	"normal": preload("res://data/difficulty/normal.tres"),
	"hard": preload("res://data/difficulty/hard.tres"),
}

const CRASH_COST := 4.6       # net timer cost of a crash: 5 s penalty + re-accelerating, minus the 1.6 s the timer is paused while wrecked
const MARGIN := 1.03          # a clean run should finish with a little to spare
const FUEL_TAKEN := 0.5       # assume half of the fuel cans get collected


static func level(name: String) -> DifficultyLevel:
	return LEVELS.get(name, LEVELS["normal"])


static func fuel_spacing(stage: StageData, lv: DifficultyLevel) -> float:
	return lv.fuel_spacing / stage.fuel


static func fuel_count(stage: StageData, lv: DifficultyLevel) -> int:
	return int((stage.length - 1500.0) / fuel_spacing(stage, lv))


## Seconds added at each of the 3 checkpoints.
static func checkpoint_bonus(stage: StageData, lv: DifficultyLevel) -> float:
	var v: float = lerpf(stage.v_slow, stage.v_fast, lv.speed_mix)
	var need: float = stage.length / v * MARGIN + lv.allow * CRASH_COST
	var fuel_gain: float = FUEL_TAKEN * fuel_count(stage, lv) * 10.0
	return clampf(roundf((need - 100.0 - fuel_gain) / 3.0), 10.0, 90.0)
