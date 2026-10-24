class_name StageSelect
extends Control
## Stage Select: the 6 worlds as rows of three stage cards (a picture of the road, then the description).
## The list scrolls to follow the focus. Keyboard: arrows move, Enter picks. Gamepad: D-pad / stick, A picks.
## A locked stage can be looked at but not started.

signal picked(stage_id: String)
signal back

const STAGE_CARD := preload("res://scenes/title/stage_card.tscn")

@onready var _scroll: ScrollContainer = %Scroll
@onready var _worlds: VBoxContainer = %Worlds
@onready var _back: Button = %BackButton


func _ready() -> void:
	_back.pressed.connect(func(): back.emit())


## Called when the screen is shown: stages may have been unlocked since last time.
func open() -> void:
	for c in _worlds.get_children():
		_worlds.remove_child(c)
		c.queue_free()
	var focus: StageCard = null
	var resume := SaveManager.continue_id()
	for wi in Stages.WORLDS.size():
		var world := Stages.WORLDS[wi]
		var header := Label.new()
		header.text = "WORLD %d   %s" % [wi + 1, world.name.to_upper()]
		header.add_theme_font_size_override("font_size", 26)
		header.add_theme_color_override("font_color", Color("ffe9b0"))
		header.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
		header.add_theme_constant_override("outline_size", 7)
		_worlds.add_child(header)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		_worlds.add_child(row)
		for v in world.stages:
			var st := Stages.by_id(v.id)
			var card: StageCard = STAGE_CARD.instantiate()
			row.add_child(card)
			card.setup(st, SaveManager.is_unlocked(st.id), SaveManager.best_score(st.id))
			card.pressed.connect(_on_card_pressed.bind(card))
			card.focus_entered.connect(func(): AudioManager.play("blip", -6.0))
			if st.id == resume:
				focus = card
	_scroll.scroll_vertical = 0
	if focus != null:
		focus.call_deferred("grab_focus")


func _on_card_pressed(card: StageCard) -> void:
	if card.unlocked:
		picked.emit(card.stage_id)
	else:
		AudioManager.play("blip", -6.0)
