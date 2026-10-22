class_name Hud
extends Control
## Per-player overlay: timer/fuel, speed, score, pop-up messages and the finished / out-of-fuel
## banners. The layout lives in hud.tscn; the labels are only touched when their value changes.
## The progress bar, button pad and super-car bar are drawn by the HudOverlay child.

const POPUP_MAX := 3
const POPUP_LIFE := 2.0

var player: PlayerCar
var world: World
var stage_name := ""
var stage_label := "STAGE 1"
var all_players: Array = []

var _blink := 0.0
var _flash_tween: Tween
var _fuel_px := -1.0
var _time_shown := -1
var _time_low := false

@onready var _time_value: Label = %TimeValue
@onready var _penalty: Label = %Penalty
@onready var _fuel_fill: ColorRect = %FuelFill
@onready var _score_value: Label = %ScoreValue
@onready var _speed_value: Label = %SpeedValue
@onready var _stage_label: Label = %StageLabel
@onready var _popups: VBoxContainer = %Popups
@onready var _out_dim: ColorRect = %OutDim
@onready var _out_label: Label = %OutLabel
@onready var _finished_label: Label = %FinishedLabel
@onready var _flash: ColorRect = %Flash


func _ready() -> void:
	_stage_label.text = "%s  -  %s" % [stage_label, String(world.level_name).to_upper()]


func add_popup(text: String, kind: String) -> void:
	# Each message sits in a fixed-height row (so the rows stack evenly) and floats up inside it.
	var row := Control.new()
	row.custom_minimum_size = Vector2(0, 44)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 36)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
	l.add_theme_color_override("font_color", Color("ffe36e") if kind == "good" else Color("ff6a5a"))
	row.add_child(l)
	_popups.add_child(row)
	if _popups.get_child_count() > POPUP_MAX:
		_popups.get_child(0).queue_free()
	var tw := row.create_tween().set_parallel()
	tw.tween_property(l, "position:y", -28.0, POPUP_LIFE)
	tw.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(POPUP_LIFE - 1.0)
	tw.chain().tween_callback(row.queue_free)


## White flash that fades out (used when a shortcut is taken).
func fade() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash.color.a = 0.9
	_flash.visible = true
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.9 / 1.6)
	_flash_tween.tween_callback(func(): _flash.visible = false)


func _process(delta: float) -> void:
	if player == null:
		return
	_blink += delta

	var secs := int(ceil(player.time_left))
	var low := player.time_left < 15.0
	var red := low and int(_blink * 4.0) % 2 == 1
	if secs != _time_shown:
		_time_shown = secs
		_time_value.text = str(secs)
	if red != _time_low:
		_time_low = red
		_time_value.add_theme_color_override("font_color", Color("ff5a4a") if red else Color.WHITE)
	_penalty.visible = player.penalty > 0.0

	# Fuel bar: 66 px of fill inside the 70 px frame, snapped to half pixels.
	var frac := clampf(player.time_left / 100.0, 0.0, 1.0)
	var px := roundf(66.0 * frac * 2.0) / 2.0
	if px != _fuel_px:
		_fuel_px = px
		_fuel_fill.position.y = 68.0 - px
		_fuel_fill.size.y = px
		_fuel_fill.color = Color("5ad45a").lerp(Color("e04a3a"), clampf(1.0 - frac * 2.0, 0.0, 1.0))

	var score := str(int(player.score))
	if _score_value.text != score:
		_score_value.text = score
	var speed := "%d km/h" % int(player.kmh())
	if _speed_value.text != speed:
		_speed_value.text = speed

	var out := player.state == PlayerCar.State.OUT
	_out_dim.visible = out
	_out_label.visible = out
	_finished_label.visible = player.state == PlayerCar.State.FINISHED
