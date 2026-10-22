class_name StageSelect
extends Control
## Stage Select: the campaign stages, and (when there are any) the challenge stages on a second tab.
## Keyboard: arrows move, Enter picks, Q / E switch tab. Gamepad: D-pad / stick, A picks, LB / RB switch tab.

signal picked(stage_id: String)
signal back

const STAGE_BUTTON := preload("res://scenes/title/stage_button.tscn")

var _tab := 0   # 0 = campaign, 1 = challenges

@onready var _tabs: Control = %Tabs
@onready var _campaign_tab: Button = %CampaignTab
@onready var _challenges_tab: Button = %ChallengesTab
@onready var _grid: GridContainer = %Grid
@onready var _back: Button = %BackButton


func _ready() -> void:
	_campaign_tab.pressed.connect(select_tab.bind(0))
	_challenges_tab.pressed.connect(select_tab.bind(1))
	_back.pressed.connect(func(): back.emit())
	for b in [_campaign_tab, _challenges_tab]:
		b.focus_entered.connect(func(): AudioManager.play("blip", -6.0))


## Called when the screen is shown: stages may have been unlocked since last time.
func open() -> void:
	select_tab(_tab, false)
	_focus_first_stage()


func select_tab(i: int, focus := true) -> void:
	var has_challenges := not Stages.challenges().is_empty()
	_tab = i if has_challenges else 0
	_tabs.visible = has_challenges   # a single list needs no tabs
	_challenges_tab.visible = has_challenges
	_campaign_tab.text = ("● " if _tab == 0 else "○ ") + "Campaign"
	_challenges_tab.text = ("● " if _tab == 1 else "○ ") + "Challenges"
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var list: Array[StageData] = Stages.CAMPAIGN if _tab == 0 else Stages.challenges()
	for i2 in list.size():
		var st := list[i2]
		var b: StageButton = STAGE_BUTTON.instantiate()
		_grid.add_child(b)
		b.setup(st, i2 + 1, SaveManager.is_unlocked(st.id), SaveManager.best_score(st.id))
		b.pressed.connect(func(): picked.emit(st.id))
	if focus:
		_focus_first_stage()


func _focus_first_stage() -> void:
	for b in _grid.get_children():
		if not b.disabled:
			b.call_deferred("grab_focus")
			return


func _input(event: InputEvent) -> void:
	if not visible or Stages.challenges().is_empty():
		return
	if InputManager.is_duplicate(event):
		return   # the same press from a mirrored (virtual) gamepad
	var switch := false
	if event is InputEventJoypadButton and event.pressed:
		switch = event.button_index == JOY_BUTTON_LEFT_SHOULDER or event.button_index == JOY_BUTTON_RIGHT_SHOULDER
	elif event is InputEventKey and event.pressed and not event.echo:
		switch = event.physical_keycode == KEY_Q or event.physical_keycode == KEY_E
	if switch:
		get_viewport().set_input_as_handled()
		select_tab(1 - _tab)
