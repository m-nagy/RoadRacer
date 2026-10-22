class_name Obstacle
extends Node2D
## Road hazard. Each kind behaves differently (see World._hit_obstacle):
##   rock     - crash
##   snowbank - bursts, halves your speed and flings the car to the far side of the road
##   cone     - harmless, but calls the police
##   barrel   - rolls away and stops your car dead
##   tire     - bounces you sideways and slows you down
##   oil      - skid
## Drawn procedurally from above, with a drop shadow.

var kind := "cone"
var hw := 12.0
var hh := 12.0

const VIS := 1.3          # drawn bigger than the raw shapes so they read clearly on screen
const HIT := 1.15         # and the collision box grows a little with them

var _flying := false
var _vel := Vector2.ZERO
var _spin := 0.0
var _life := 0.0
var _age := 0.0
var _seed := 0.0


func setup(kind_name: String, pos: Vector2) -> void:
	kind = kind_name
	position = pos
	_seed = fposmod(pos.x * 0.37 + pos.y * 0.11, 1.0)
	rotation = 0.0
	scale = Vector2.ONE * VIS
	match kind:
		"cone":
			hw = 13.0; hh = 13.0
		"barrel":
			hw = 17.0; hh = 17.0
		"rock":
			hw = 24.0; hh = 22.0
		"oil":
			hw = 26.0; hh = 22.0
		"snowbank":
			hw = 34.0; hh = 22.0
		"tire":
			hw = 18.0; hh = 18.0
	hw *= HIT
	hh *= HIT
	set_physics_process(false)   # nothing to simulate until the obstacle is knocked away
	queue_redraw()


func d() -> float:
	return -position.y


## Knock the obstacle away (it is no longer part of the course).
func fly(velocity: Vector2, spin: float, life: float) -> void:
	_flying = true
	_vel = velocity
	_spin = spin
	_life = life
	_age = 0.0
	z_index = 5
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_age += delta
	position += _vel * delta
	rotation += _spin * delta
	_vel *= (1.0 - 1.2 * delta)
	if _age >= _life:
		queue_free()
		return
	if kind == "snowbank":
		scale = Vector2.ONE * VIS * (1.0 + _age * 1.6)
	modulate.a = clampf(1.0 - (_age / _life) * (_age / _life), 0.0, 1.0)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	for k in 18:
		var a := TAU * k / 18.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	draw_colored_polygon(pts, col)


func _shadow(rx: float, ry: float) -> void:
	_ellipse(Vector2(4, 6), rx, ry, Color(0, 0, 0, 0.28))


func _draw() -> void:
	match kind:
		"cone": _draw_cone()
		"barrel": _draw_barrel()
		"rock": _draw_rock()
		"oil": _draw_oil()
		"snowbank": _draw_snowbank()
		"tire": _draw_tire()


func _draw_cone() -> void:
	# Seen at a slight angle so it reads as a traffic cone: square base, striped orange cone.
	_ellipse(Vector2(3, 12), 17, 7, Color(0, 0, 0, 0.28))
	draw_rect(Rect2(-14, 5, 28, 9), Color("20232a"))
	draw_rect(Rect2(-14, 5, 28, 3), Color("3a3f48"))
	draw_colored_polygon(PackedVector2Array([Vector2(-11, 8), Vector2(11, 8), Vector2(3, -16), Vector2(-3, -16)]), Color("ee5b10"))
	draw_colored_polygon(PackedVector2Array([Vector2(-9.3, 3), Vector2(9.3, 3), Vector2(8.0, -1), Vector2(-8.0, -1)]), Color("f6f6f2"))
	draw_colored_polygon(PackedVector2Array([Vector2(-6.3, -6), Vector2(6.3, -6), Vector2(5.3, -9), Vector2(-5.3, -9)]), Color("f6f6f2"))
	draw_colored_polygon(PackedVector2Array([Vector2(-11, 8), Vector2(-6, 8), Vector2(-1.5, -16), Vector2(-3, -16)]), Color("ff9a52"))
	draw_colored_polygon(PackedVector2Array([Vector2(11, 8), Vector2(7, 8), Vector2(1.5, -16), Vector2(3, -16)]), Color("b8400a"))
	_ellipse(Vector2(0, -16), 3.0, 1.6, Color("7a2a06"))


func _draw_barrel() -> void:
	# Upright oil drum with an elliptical lid, steel hoops and a hazard band.
	_ellipse(Vector2(4, 14), 19, 7, Color(0, 0, 0, 0.28))
	draw_rect(Rect2(-14, -10, 28, 24), Color("b3300f"))
	_ellipse(Vector2(0, 14), 14, 5, Color("b3300f"))
	draw_rect(Rect2(-14, -10, 8, 24), Color("d9532a"))
	draw_rect(Rect2(8, -10, 6, 24), Color("8a2208"))
	for k in 7:
		var col := Color("f2c230") if k % 2 == 0 else Color("1c1c1c")
		draw_rect(Rect2(-14 + k * 4.0, 0, 4.0, 6), col)
	draw_line(Vector2(-14, -4), Vector2(14, -4), Color("6a1a06"), 2.0)
	draw_line(Vector2(-14, 9), Vector2(14, 9), Color("6a1a06"), 2.0)
	_ellipse(Vector2(0, -10), 14, 5.5, Color("7a2008"))
	_ellipse(Vector2(0, -10.5), 12, 4.4, Color("d9532a"))
	draw_circle(Vector2(-4, -10.5), 1.8, Color("5a1805"))
	draw_circle(Vector2(5, -10), 1.4, Color("5a1805"))


func _draw_rock() -> void:
	_shadow(26, 22)
	var base := PackedVector2Array()
	var n := 9
	for k in n:
		var a := TAU * k / n + _seed
		var r := 1.0 - 0.14 * fmod(float(k) * 0.37 + _seed * 3.0, 1.0)
		base.append(Vector2(cos(a) * 24.0 * r, sin(a) * 21.0 * r))
	draw_colored_polygon(base, Color("4a3f35"))
	# lit and shaded facets
	for k in n:
		var p0 := Vector2.ZERO + Vector2(-3, -3)
		var p1: Vector2 = base[k] * 0.92
		var p2: Vector2 = base[(k + 1) % n] * 0.92
		var lit := (p1 + p2).dot(Vector2(-1, -1)) > 0.0
		draw_colored_polygon(PackedVector2Array([p0, p1, p2]), Color("9c8a76") if lit else Color("6b5b4d"))
	draw_polyline(PackedVector2Array(base + PackedVector2Array([base[0]])), Color("2c241d"), 2.0)
	# cracks and moss
	draw_polyline(PackedVector2Array([Vector2(-6, -8), Vector2(-2, -2), Vector2(4, 1), Vector2(2, 8)]), Color("2c241d"), 1.6)
	draw_polyline(PackedVector2Array([Vector2(4, 1), Vector2(10, -3)]), Color("2c241d"), 1.4)
	_ellipse(Vector2(-9, 7), 4, 2.4, Color("5a7a3a"))
	_ellipse(Vector2(10, 8), 3, 2.0, Color("6a8a42"))


func _draw_oil() -> void:
	_ellipse(Vector2.ZERO, 26, 22, Color(0.04, 0.04, 0.07, 0.92))
	_ellipse(Vector2.ZERO, 14, 10, Color(0.25, 0.2, 0.45, 0.55))
	_ellipse(Vector2.ZERO, 7, 5, Color(0.2, 0.5, 0.5, 0.45))


func _draw_snowbank() -> void:
	_shadow(36, 22)
	var mounds := [[-16.0, 3.0, 17.0, 14.0], [14.0, 4.0, 18.0, 14.0], [0.0, -5.0, 22.0, 15.0], [-6.0, 9.0, 14.0, 9.0], [10.0, 10.0, 12.0, 8.0]]
	for m in mounds:
		_ellipse(Vector2(m[0], m[1] + 2.5), m[2], m[3], Color("a9c2d8"))
	for m in mounds:
		_ellipse(Vector2(m[0], m[1]), m[2] - 1.0, m[3] - 1.0, Color("f4f9fd"))
	for m in mounds:
		_ellipse(Vector2(m[0] - 3.0, m[1] - 3.5), m[2] * 0.55, m[3] * 0.45, Color.WHITE)
	# little sparkles
	for sp in [Vector2(-12, -6), Vector2(8, -10), Vector2(18, 2), Vector2(-4, 8)]:
		draw_line(sp + Vector2(-2.5, 0), sp + Vector2(2.5, 0), Color("bfe3ff"), 1.4)
		draw_line(sp + Vector2(0, -2.5), sp + Vector2(0, 2.5), Color("bfe3ff"), 1.4)


func _draw_tire() -> void:
	_shadow(20, 20)
	# two stacked tyres (the lower one peeks out)
	for off in [Vector2(2.5, 3.0), Vector2(-1.0, -1.5)]:
		draw_circle(off, 17.0, Color("0f0f10"))
		for k in 20:
			var a := TAU * k / 20.0
			draw_line(off + Vector2(cos(a), sin(a)) * 14.0, off + Vector2(cos(a), sin(a)) * 17.0, Color("3b3b3e"), 2.0)
		draw_circle(off, 11.5, Color("1b1b1d"))
		draw_circle(off, 8.0, Color("9aa0a8"))
		draw_circle(off, 5.4, Color("5a5f66"))
		draw_circle(off, 2.0, Color("2c2f34"))
	draw_arc(Vector2(-1.0, -1.5), 14.0, -2.6, -1.0, 8, Color("66666b"), 1.6)
