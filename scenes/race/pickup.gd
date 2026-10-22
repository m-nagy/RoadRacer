class_name Pickup
extends Node2D
## Fuel can that adds time to the timer.
## The can and its glow are drawn once; bobbing and pulsing only move/fade those two child nodes.

var hw := 17.0
var hh := 20.0
var _t := 0.0
@onready var _glow: Node2D = $Glow
@onready var _can: Node2D = $Can


func d() -> float:
	return -position.y


func _physics_process(delta: float) -> void:
	_t += delta
	var bob := sin(_t * 5.0) * 2.0
	_glow.position.y = bob
	_can.position.y = bob
	_glow.modulate.a = 0.28 + 0.1 * sin(_t * 6.0)


func _draw_glow() -> void:
	_glow.draw_circle(Vector2.ZERO, 24.0, Color(1.0, 0.9, 0.3))


func _draw_can() -> void:
	_can.draw_rect(Rect2(-14, -17, 28, 34), Color("7a1010"))
	_can.draw_rect(Rect2(-12, -15, 24, 30), Color("e03030"))
	_can.draw_rect(Rect2(-4, -22, 14, 7), Color("e03030"))
	_can.draw_rect(Rect2(-4, -22, 14, 7), Color("7a1010"), false, 2.0)
	_can.draw_rect(Rect2(-7, -8, 14, 16), Color("ffe36e"))
	_can.draw_string(ThemeDB.fallback_font, Vector2(-5, 6), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("7a1010"))
