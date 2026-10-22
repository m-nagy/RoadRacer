class_name Stages
## The stages. The campaign is the 6 stages in play order (StageData resources in data/stages/).
## Challenges are variants of campaign stages with their own weather and length (see StageVariant);
## they are listed separately in Stage Select and unlock when the stage they are based on is cleared.
## Everything refers to a stage by its `id`, so lists can grow or change order without breaking saves.

const LANE_W := 88.0

const CAMPAIGN: Array[StageData] = [
	preload("res://data/stages/stage1.tres"),
	preload("res://data/stages/stage2.tres"),
	preload("res://data/stages/stage3.tres"),
	preload("res://data/stages/stage4.tres"),
	preload("res://data/stages/stage5.tres"),
	preload("res://data/stages/stage6.tres"),
]

const CHECKPOINTS := [0.25, 0.5, 0.75]

## The challenge stages, built once from their variants.
static var _challenges: Array[StageData] = []


static func challenges() -> Array[StageData]:
	return _challenges


## The stage with this id (the first campaign stage if there is no such stage).
static func by_id(id: String) -> StageData:
	for s in CAMPAIGN:
		if s.id == id:
			return s
	for s in _challenges:
		if s.id == id:
			return s
	return CAMPAIGN[0]


static func is_challenge(id: String) -> bool:
	for s in _challenges:
		if s.id == id:
			return true
	return false


## The list (campaign or challenges) this stage belongs to.
static func list_of(id: String) -> Array[StageData]:
	return _challenges if is_challenge(id) else CAMPAIGN


## Position of a stage in its own list, 0-based.
static func index_of(id: String) -> int:
	var list := list_of(id)
	for i in list.size():
		if list[i].id == id:
			return i
	return 0


## The stage that follows in the same list, or "" at the end.
static func next_id(id: String) -> String:
	var list := list_of(id)
	var i := index_of(id) + 1
	return list[i].id if i < list.size() else ""


## "STAGE 3" or "CHALLENGE 2".
static func label(id: String) -> String:
	return "%s %d" % ["CHALLENGE" if is_challenge(id) else "STAGE", index_of(id) + 1]


## The stage that has to be cleared before this one can be played ("" = always open).
static func requirement(id: String) -> String:
	var s := by_id(id)
	if s.requires != "":
		return s.requires
	var i := index_of(id)
	return "" if i == 0 or is_challenge(id) else CAMPAIGN[i - 1].id
