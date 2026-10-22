class_name Stages
## The stages. The game is 6 worlds (WorldData in data/worlds/) of 3 stages each (StageVariant in
## data/stages/), played in that order: a stage opens when the one before it has been cleared.
## Everything refers to a stage by its `id`, so the lists can grow or change order without breaking saves.

const LANE_W := 88.0

const WORLDS: Array[WorldData] = [
	preload("res://data/worlds/city.tres"),
	preload("res://data/worlds/country.tres"),
	preload("res://data/worlds/bridge.tres"),
	preload("res://data/worlds/desert.tres"),
	preload("res://data/worlds/snow.tres"),
	preload("res://data/worlds/night_city.tres"),
]

const CHECKPOINTS := [0.25, 0.5, 0.75]

static var _all: Array[StageData] = []      # every stage in play order, built on first use
static var _world_index: Dictionary = {}    # stage id -> index into WORLDS
static var _pos_in_world: Dictionary = {}   # stage id -> 0-based position inside its world


static func all() -> Array[StageData]:
	if _all.is_empty():
		for wi in WORLDS.size():
			var world := WORLDS[wi]
			for i in world.stages.size():
				var s := world.stages[i].build()
				_all.append(s)
				_world_index[s.id] = wi
				_pos_in_world[s.id] = i
	return _all


## The stage with this id (the first stage if there is no such stage).
static func by_id(id: String) -> StageData:
	for s in all():
		if s.id == id:
			return s
	return all()[0]


static func has(id: String) -> bool:
	for s in all():
		if s.id == id:
			return true
	return false


## Position in the whole game, 0-based.
static func index_of(id: String) -> int:
	var list := all()
	for i in list.size():
		if list[i].id == id:
			return i
	return 0


## The stage that follows, or "" after the last one.
static func next_id(id: String) -> String:
	var list := all()
	var i := index_of(id) + 1
	return list[i].id if i < list.size() else ""


static func world_of(id: String) -> WorldData:
	all()
	return WORLDS[_world_index.get(id, 0)]


## 1-based position of the stage inside its world (1..3).
static func number_in_world(id: String) -> int:
	all()
	return int(_pos_in_world.get(id, 0)) + 1


static func is_last_in_world(id: String) -> bool:
	return number_in_world(id) == world_of(id).stages.size()


## "2-3": world 2, third stage.
static func short_label(id: String) -> String:
	return "%d-%d" % [WORLDS.find(world_of(id)) + 1, number_in_world(id)]


## "STAGE 2-3".
static func label(id: String) -> String:
	return "STAGE " + short_label(id)


## The stage that has to be cleared before this one can be played ("" = always open).
static func requirement(id: String) -> String:
	var i := index_of(id)
	return "" if i == 0 else all()[i - 1].id
