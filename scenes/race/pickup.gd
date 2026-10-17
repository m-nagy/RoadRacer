class_name Pickup
extends Node2D
## Fuel can that adds time to the timer.

var hw := 17.0
var hh := 20.0
var _t := 0.0


func d() -> float:
	return -position.y


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 5.0) * 2.0
	draw_circle(Vector2(0, bob), 24.0, Color(1.0, 0.9, 0.3, 0.28 + 0.1 * sin(_t * 6.0)))
	draw_rect(Rect2(-14, -17 + bob, 28, 34), Color("7a1010"))
	draw_rect(Rect2(-12, -15 + bob, 24, 30), Color("e03030"))
	draw_rect(Rect2(-4, -22 + bob, 14, 7), Color("e03030"))
	draw_rect(Rect2(-4, -22 + bob, 14, 7), Color("7a1010"), false, 2.0)
	draw_rect(Rect2(-7, -8 + bob, 14, 16), Color("ffe36e"))
	draw_string(ThemeDB.fallback_font, Vector2(-5, 6 + bob), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("7a1010"))
