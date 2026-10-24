class_name StageCard
extends Button
## One stage in Stage Select: a picture of its road, then its name, what it is like, a short description
## and the best score (or what unlocks it). The picture is a screenshot kept in assets/previews/ (see
## Autotest "previews"); a stage without one shows its road colours instead.

const PREVIEW_DIR := "res://assets/previews/"

var stage_id := ""
var unlocked := true

@onready var _picture: TextureRect = %Picture
@onready var _lock: Label = %Lock
@onready var _title: Label = %Title
@onready var _facts: Label = %Facts
@onready var _description: Label = %Description
@onready var _status: Label = %Status


static func preview_path(id: String) -> String:
	return PREVIEW_DIR + id + ".webp"


func setup(stage: StageData, is_unlocked: bool, best: int) -> void:
	stage_id = stage.id
	unlocked = is_unlocked
	_title.text = "%s   %s" % [Stages.short_label(stage.id), stage.name]
	_facts.text = facts(stage)
	_description.text = stage.description
	if is_unlocked:
		_status.text = "Best: %d" % best if best > 0 else "Not cleared yet"
	else:
		_status.text = "Locked - clear %s first" % Stages.short_label(Stages.requirement(stage.id))
	_lock.visible = not is_unlocked
	_picture.modulate = Color.WHITE if is_unlocked else Color(0.45, 0.45, 0.5)
	var path := preview_path(stage.id)
	if ResourceLoader.exists(path):
		_picture.texture = load(path)
	else:
		_picture.texture = _fallback(stage)


## "Fog | Night | 2-3 lanes | 5.6 km"
static func facts(stage: StageData) -> String:
	var lo := 9
	var hi := 0
	for l in stage.lanes:
		lo = mini(lo, l.lanes)
		hi = maxi(hi, l.lanes)
	var lanes := "%d lanes" % lo if lo == hi else "%d-%d lanes" % [lo, hi]
	var km := stage.length / 8.0 / 1000.0   # 8 px = 1 displayed metre
	return "%s | %s | %s | %.1f km" % [stage.weather.label, "Night" if stage.night else "Day", lanes, km]


## A plain picture of the road in the stage's own colours, for a stage that has no screenshot yet.
func _fallback(stage: StageData) -> Texture2D:
	var img := Image.create_empty(32, 18, false, Image.FORMAT_RGB8)
	img.fill(stage.ground)
	for y in 18:
		for x in range(9, 23):
			img.set_pixel(x, y, stage.asphalt)
	return ImageTexture.create_from_image(img)
