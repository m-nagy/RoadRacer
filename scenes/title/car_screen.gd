class_name CarScreen
extends Control
## Car choice for the players picked on the previous screen (one or two cards).
## Each player changes colour / steering mode with their own keys; "ready" (slow key / A) from all
## players, or Enter, starts the race. Esc / B goes back.

signal finished
signal back

var _row: HBoxContainer
var _cards: Array = []
var _open_t := 0.0
var _go_timer := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 40)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.offset_top = 150
	_row.offset_bottom = -52
	add_child(_row)


func open() -> void:
	visible = true
	InputManager.freeze_held()
	_open_t = 0.0
	_go_timer = -1.0
	for c in _cards:
		c.queue_free()
	_cards.clear()
	for slot in Game.active_slots():
		Game.players[slot]["ready"] = false
		var c := PlayerCard.new()
		c.slot = slot
		_row.add_child(c)
		_cards.append(c)


func _input(event: InputEvent) -> void:
	if not visible or _open_t < 0.25:
		return
	if InputManager.is_duplicate(event):
		return   # the same press from a mirrored (virtual) gamepad
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back.emit()
	elif event.is_action_pressed("ui_accept") and event is InputEventKey and _go_timer < 0.0:
		get_viewport().set_input_as_handled()
		_begin()


func _begin() -> void:
	for slot in Game.active_slots():
		Game.players[slot]["ready"] = true
	AudioManager.play("select")
	_go_timer = 0.4


func _process(delta: float) -> void:
	if not visible:
		return
	_open_t += delta
	if _go_timer >= 0.0:
		_go_timer -= delta
		if _go_timer < 0.0:
			finished.emit()
		return
	if _open_t < 0.35:
		return
	for c in _cards:
		var slot: int = c.slot
		var p: Dictionary = Game.players[slot]
		var changed := false
		if not p["ready"]:
			if InputManager.just_pressed(slot, "left"):
				p["color"] = posmod(int(p["color"]) - 1, Game.COLORS.size())
				changed = true
			if InputManager.just_pressed(slot, "right"):
				p["color"] = posmod(int(p["color"]) + 1, Game.COLORS.size())
				changed = true
			if InputManager.just_pressed(slot, "up") or InputManager.just_pressed(slot, "down"):
				p["easy"] = not p["easy"]
				changed = true
			if InputManager.just_pressed(slot, "slow"):
				p["ready"] = true
				AudioManager.play("select")
				changed = true
		elif InputManager.just_pressed(slot, "fast"):
			p["ready"] = false
			changed = true
		if changed:
			AudioManager.play("blip", -6.0)
			c.refresh()
	var act := Game.active_slots()
	if not act.is_empty() and act.all(func(s): return Game.players[s]["ready"]):
		_go_timer = 0.5
