class_name DebugBoxes
extends Node2D
## F3 overlay: draws the exact boxes used for collisions (green = player, red = traffic,
## yellow = hazards, cyan = the car body used against the road side).

var world: World


func _process(_delta: float) -> void:
	visible = Game.debug_boxes
	if visible:
		queue_redraw()


func _box(c: Vector2, rot: float, hw: float, hh: float, col: Color) -> void:
	var pts := PackedVector2Array([
		c + Vector2(-hw, -hh).rotated(rot), c + Vector2(hw, -hh).rotated(rot),
		c + Vector2(hw, hh).rotated(rot), c + Vector2(-hw, hh).rotated(rot), c + Vector2(-hw, -hh).rotated(rot)])
	draw_polyline(pts, col, 2.0)


func _draw() -> void:
	if world == null:
		return
	for p in world.players:
		_box(p.position, p.rotation, p.hw, p.hh, Color.LIME)
		_box(p.position, p.rotation, PlayerCar.EDGE_HW, PlayerCar.EDGE_HH, Color.CYAN)
	for r in world.rivals:
		_box(r.position, r.rotation, r.hw * 0.92, r.hh * 0.95, Color.RED)
	for o in world.obstacles:
		_box(o.position, 0.0, o.hw * 0.85, o.hh * 0.85, Color.YELLOW)
