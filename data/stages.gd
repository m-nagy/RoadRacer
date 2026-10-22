class_name Stages
## The stages, in play order. Each one is a StageData resource in data/stages/ (edit them in the Inspector).

const LANE_W := 88.0

const LIST: Array[StageData] = [
	preload("res://data/stages/stage1.tres"),
	preload("res://data/stages/stage2.tres"),
	preload("res://data/stages/stage3.tres"),
	preload("res://data/stages/stage4.tres"),
	preload("res://data/stages/stage5.tres"),
	preload("res://data/stages/stage6.tres"),
]

const CHECKPOINTS := [0.25, 0.5, 0.75]


static func get_stage(i: int) -> StageData:
	return LIST[clampi(i, 0, LIST.size() - 1)]
