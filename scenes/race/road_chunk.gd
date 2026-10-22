class_name RoadChunk
extends Node2D
## One stretch of road scenery on one layer (see Road). Its drawing is recorded once, when the chunk
## comes into view, and then replayed by the renderer until the chunk is freed again.
##   GROUND   ground, bands and waves
##   DECOR    buildings, trees, boats beside the road
##   SURFACE  curbs, asphalt, lane lines and shortcut strips
##   FRONT    tunnel mouths, signs and the checkpoint / goal banners
## The layers of all chunks are drawn in that order, so a building that reaches into the next chunk
## is never covered by that chunk's ground, and decor never ends up on top of a neighbour's road.

enum Layer { GROUND, DECOR, SURFACE, FRONT }

var road: Road
var layer := Layer.GROUND
var d0 := 0.0
var d1 := 0.0

var _font: Font = ThemeDB.fallback_font
var _boats: Array = []   # [node, x, phase]: bridge boats are nodes so they can drift without a redraw


func setup(r: Road, which: Layer, from_d: float, to_d: float) -> void:
	road = r
	layer = which
	d0 = from_d
	d1 = to_d


func _ready() -> void:
	if layer == Layer.DECOR and road.theme == "bridge":
		var idx := road.first_decor(d0)
		while idx < road.decor.size() and road.decor[idx]["d"] < d1:
			var it: Dictionary = road.decor[idx]
			idx += 1
			if it["kind"] != 0:
				continue
			var boat := Node2D.new()
			boat.draw.connect(_draw_boat.bind(boat))
			boat.position = Vector2(road.center_x(it["d"]) + it["side"] * (road.half_width(it["d"]) + 120.0 + it["off"]), -it["d"])
			add_child(boat)
			_boats.append([boat, boat.position.x, it["r"]])


## Boats bob sideways on the water.
func animate(t: float) -> void:
	for b in _boats:
		b[0].position.x = b[1] + sin(t * 0.5 + b[2] * 6.0) * 6.0


func _draw() -> void:
	match layer:
		Layer.GROUND: _draw_ground()
		Layer.DECOR: _draw_decor_layer()
		Layer.SURFACE: _draw_surface()
		Layer.FRONT: _draw_front()


# ---------------------------------------------------------------- ground and decor

func _draw_ground() -> void:
	var ground: Color = road.stage.ground
	var ground2: Color = road.stage.ground2
	var cx_mid := road.center_x((d0 + d1) * 0.5)
	var half_view := 1100.0

	# Ground with alternating bands (gives a sense of speed). Bands are cut at the chunk edge.
	var x0 := cx_mid - half_view - 600.0
	var w := (half_view + 600.0) * 2.0
	draw_rect(Rect2(x0, -d1, w, d1 - d0), ground)
	var band := 160.0
	for b in range(int(floor(d0 / band)), int(ceil(d1 / band)) + 1):
		if b % 2 == 0:
			var lo := maxf(b * band, d0)
			var hi := minf((b + 1) * band, d1)
			if hi > lo:
				draw_rect(Rect2(x0, -hi, w, hi - lo), ground2)

	if road.theme == "bridge":
		_draw_waves(cx_mid)


func _draw_decor_layer() -> void:
	if road.theme == "bridge":
		return   # the boats are child nodes
	var idx := road.first_decor(d0)
	while idx < road.decor.size() and road.decor[idx]["d"] < d1:
		_draw_decor(road.decor[idx])
		idx += 1


func _draw_waves(cx_mid: float) -> void:
	var step := 120.0
	for k in range(int(ceil(d0 / step)), int(ceil(d1 / step))):
		var h := fmod(abs(sin(k * 12.9898) * 43758.5453), 1.0)
		var d := k * step
		var x := cx_mid + (h - 0.5) * 1800.0
		var y := -d
		draw_line(Vector2(x, y), Vector2(x + 26, y), Color(1, 1, 1, 0.35), 2.0)
		draw_line(Vector2(x + 8, y + 7), Vector2(x + 30, y + 7), Color(1, 1, 1, 0.25), 2.0)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 14:
		var a := TAU * k / 14.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _draw_boat(boat: Node2D) -> void:
	for e in [[Vector2.ZERO, 18.0, 46.0, Color("f2f2f2")], [Vector2(0, -8), 10.0, 24.0, Color("c43b3b")]]:
		var pts := PackedVector2Array()
		for k in 14:
			var a := TAU * k / 14.0
			pts.append(e[0] + Vector2(cos(a) * e[1], sin(a) * e[2]))
		boat.draw_colored_polygon(pts, e[3])


func _draw_decor(it: Dictionary) -> void:
	var d: float = it["d"]
	var side: int = it["side"]
	var cx := road.center_x(d)
	var hw := road.half_width(d)
	var x: float = cx + side * (hw + Road.CURB + it["off"])
	var y := -d
	var sz: float = it["size"]
	var r: float = it["r"]
	match road.theme:
		"city", "night":
			var w := 70.0 + 60.0 * sz
			var h := 60.0 + 70.0 * r
			var cols := [Color("8d99ae"), Color("a5a58d"), Color("b08968"), Color("6d6875"), Color("7f8fa6")]
			var base: Color = cols[it["kind"] % cols.size()]
			if road.night:
				base = base.darkened(0.25)
			var rx: float = x if side > 0 else x - w
			draw_rect(Rect2(rx, y - h * 0.5, w, h), base.darkened(0.25))
			draw_rect(Rect2(rx + 5, y - h * 0.5 + 5, w - 10, h - 10), base)
			draw_rect(Rect2(rx + w * 0.2, y - h * 0.2, 14, 14), base.darkened(0.3))
			if road.night:
				for k in 4:
					draw_rect(Rect2(rx + 8 + k * 16, y - h * 0.5 + 8, 8, 5), Color("ffe08a"))
				if it["kind"] == 1:
					var lx := cx + side * (hw + Road.CURB + 6.0)
					draw_circle(Vector2(lx, y), 16, Color(1, 0.9, 0.5, 0.25))
					draw_circle(Vector2(lx, y), 5, Color("ffe9a0"))
		"country":
			if it["kind"] == 3 and r > 0.5:
				var rx2: float = x if side > 0 else x - 90.0
				draw_rect(Rect2(rx2, y - 36, 90, 72), Color("c97b5a").darkened(0.15))
				draw_rect(Rect2(rx2 + 4, y - 32, 82, 64), Color("b5483a"))
				draw_line(Vector2(rx2 + 4, y), Vector2(rx2 + 86, y), Color("8f3328"), 3.0)
			else:
				var rad := 22.0 + 20.0 * sz
				draw_circle(Vector2(x + side * rad, y + 6), rad, Color(0, 0, 0, 0.18))
				draw_circle(Vector2(x + side * rad, y), rad, Color("2f6d2c"))
				draw_circle(Vector2(x + side * rad - 5, y - 5), rad * 0.62, Color("3e8c3a"))
		"desert":
			var px: float = x + side * 14.0
			if it["kind"] == 0 or it["kind"] == 1:
				draw_line(Vector2(px, y - 22), Vector2(px, y + 22), Color("3f7d3a"), 8.0)
				draw_line(Vector2(px - 12, y - 4), Vector2(px + 12, y - 4), Color("3f7d3a"), 6.0)
				draw_line(Vector2(px - 12, y - 4), Vector2(px - 12, y - 16), Color("3f7d3a"), 5.0)
				draw_line(Vector2(px + 12, y - 4), Vector2(px + 12, y - 14), Color("3f7d3a"), 5.0)
			elif it["kind"] == 2:
				_ellipse(Vector2(px, y), 30.0 * sz, 20.0 * sz, Color("c79a47"))
			else:
				_ellipse(Vector2(px, y), 20.0 * sz, 14.0 * sz, Color("8a6d4b"))
				_ellipse(Vector2(px - 3, y - 3), 13.0 * sz, 8.0 * sz, Color("a88a63"))
		"snow":
			var px2: float = x + side * 16.0
			if it["kind"] == 3:
				_ellipse(Vector2(px2, y), 34.0 * sz, 20.0 * sz, Color("cfdde8"))
			else:
				var s := 20.0 + 14.0 * sz
				draw_colored_polygon(PackedVector2Array([Vector2(px2, y - s * 1.3), Vector2(px2 - s, y + s * 0.8), Vector2(px2 + s, y + s * 0.8)]), Color("245c3a"))
				draw_colored_polygon(PackedVector2Array([Vector2(px2, y - s * 1.3), Vector2(px2 - s * 0.45, y - s * 0.25), Vector2(px2 + s * 0.45, y - s * 0.25)]), Color("f4f8fb"))


# ---------------------------------------------------------------- surface

func _draw_surface() -> void:
	var ground: Color = road.stage.ground
	var asphalt: Color = road.stage.asphalt
	var curb: Color = road.stage.curb
	var bridge: bool = road.theme == "bridge"
	var seg := Road.SEG
	for i in range(int(floor(d0 / seg)), int(ceil(d1 / seg))):
		var da := i * seg
		var db := da + seg
		var ya := -da
		var yb := -db
		var ca := road.center_x(da)
		var cb := road.center_x(db)
		var ha := road.half_width(da)
		var hb := road.half_width(db)

		if bridge:
			var deck := Color("b9b9b2")
			draw_colored_polygon(PackedVector2Array([Vector2(ca - ha - 30, ya), Vector2(ca + ha + 30, ya), Vector2(cb + hb + 30, yb), Vector2(cb - hb - 30, yb)]), deck)

		# Shortcut strips.
		for s in road.shortcuts:
			if da >= s.d0 and db <= s.d1 + seg:
				var sd: float = s.side
				var inner_a := ca + sd * (ha - 4.0)
				var outer_a := ca + sd * (ha + Road.STRIP_W)
				var inner_b := cb + sd * (hb - 4.0)
				var outer_b := cb + sd * (hb + Road.STRIP_W)
				var col := Color("c9a868") if not s.hidden else ground.lerp(asphalt, 0.18)
				draw_colored_polygon(PackedVector2Array([Vector2(inner_a, ya), Vector2(outer_a, ya), Vector2(outer_b, yb), Vector2(inner_b, yb)]), col)
				if not s.hidden and (i / 3) % 2 == 0:
					draw_line(Vector2((inner_a + outer_a) * 0.5, ya), Vector2((inner_b + outer_b) * 0.5, yb), Color("fff3b0"), 3.0)

		# Curbs (with gaps where a shortcut begins).
		var cc := curb if (i / 4) % 2 == 0 else Color("c43b3b")
		if bridge:
			cc = Color("8a8a84") if (i / 4) % 2 == 0 else Color("6b6b66")
		if not road.gap_on_side(da, -1):
			draw_colored_polygon(PackedVector2Array([Vector2(ca - ha - Road.CURB, ya), Vector2(ca - ha, ya), Vector2(cb - hb, yb), Vector2(cb - hb - Road.CURB, yb)]), cc)
		if not road.gap_on_side(da, 1):
			draw_colored_polygon(PackedVector2Array([Vector2(ca + ha, ya), Vector2(ca + ha + Road.CURB, ya), Vector2(cb + hb + Road.CURB, yb), Vector2(cb + hb, yb)]), cc)

		# Asphalt.
		draw_colored_polygon(PackedVector2Array([Vector2(ca - ha, ya), Vector2(ca + ha, ya), Vector2(cb + hb, yb), Vector2(cb - hb, yb)]), asphalt)

		# Edge lines.
		var line_col := Color(1, 1, 1, 0.85)
		draw_line(Vector2(ca - ha + 6, ya), Vector2(cb - hb + 6, yb), line_col, 3.0)
		draw_line(Vector2(ca + ha - 6, ya), Vector2(cb + hb - 6, yb), line_col, 3.0)

		# Lane dividers, only where the lane count is stable.
		var la := road.lanes_at(da)
		var n := roundi(la)
		if absf(la - n) < 0.03 and (i / 4) % 2 == 0:
			for k in range(1, n):
				var xa := ca - ha + k * (2.0 * ha / n)
				var lb_ := road.lanes_at(db)
				var hb2 := hb
				var xb := cb - hb2 + k * (2.0 * hb2 / maxf(1.0, roundf(lb_)))
				draw_line(Vector2(xa, ya), Vector2(xb, yb), Color(1, 1, 1, 0.7), 3.0)


# ---------------------------------------------------------------- front

func _in_chunk(d: float) -> bool:
	return d >= d0 and d < d1


func _draw_front() -> void:
	for s in road.shortcuts:
		var sd: float = s.side
		# Tunnel mouth at the end of the strip.
		var d: float = s.d1
		if _in_chunk(d):
			var hw := road.half_width(d)
			var cx := road.center_x(d) + sd * (hw + Road.STRIP_W * 0.5)
			draw_rect(Rect2(cx - Road.STRIP_W * 0.5 - 8, -d - 14, Road.STRIP_W + 16, 26), Color("3b3b44"))
			draw_rect(Rect2(cx - Road.STRIP_W * 0.5 + 6, -d - 10, Road.STRIP_W - 12, 22), Color("050507"))
		if not s.hidden:
			# Arrow signs leading to the strip.
			for k in 3:
				var dd: float = s.d0 - 300.0 + k * 90.0
				if _in_chunk(dd):
					var sx := road.center_x(dd) + sd * (road.half_width(dd) + 30.0)
					var ay := -dd
					draw_colored_polygon(PackedVector2Array([Vector2(sx - 14, ay + 8), Vector2(sx + 14, ay + 8), Vector2(sx, ay - 14)]), Color("ffd23f"))
			var txt_d: float = s.d0 - 100.0
			if _in_chunk(txt_d):
				var tx := road.center_x(txt_d) + sd * (road.half_width(txt_d) + 70.0)
				draw_string(_font, Vector2(tx - 52, -txt_d), "SHORTCUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffd23f"))
	_draw_banners()


func _draw_banners() -> void:
	var marks := []
	for i in road.checkpoints.size():
		marks.append([road.checkpoints[i], "CHECKPOINT", Color("ffd23f")])
	marks.append([road.length, "GOAL", Color("ffffff")])
	for m in marks:
		var d: float = m[0]
		if not _in_chunk(d):
			continue
		var cx := road.center_x(d)
		var hw := road.half_width(d)
		var y := -d
		var cells := int(hw * 2.0 / 16.0) + 1
		for k in cells:
			for row in 2:
				var c := Color.WHITE if (k + row) % 2 == 0 else Color.BLACK
				draw_rect(Rect2(cx - hw + k * 16.0, y - 16.0 + row * 16.0, 16.0, 16.0), c)
		draw_rect(Rect2(cx - hw - 26, y - 40, 22, 56), Color("444"))
		draw_rect(Rect2(cx + hw + 4, y - 40, 22, 56), Color("444"))
		draw_rect(Rect2(cx - hw - 26, y - 70, hw * 2.0 + 52.0, 34), m[2])
		draw_rect(Rect2(cx - hw - 26, y - 70, hw * 2.0 + 52.0, 34), Color.BLACK, false, 3.0)
		var tw := _font.get_string_size(m[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(_font, Vector2(cx - tw * 0.5, y - 45), m[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.BLACK)
