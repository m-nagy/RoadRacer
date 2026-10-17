class_name Road
extends Node2D
## Procedural road. "d" is distance travelled along the road (d = -y). The road is defined by pure
## functions of d (centre line, width), and drawn on demand for the visible ranges only.

const LANE_W := Stages.LANE_W
const SEG := 16.0
const CURB := 14.0
const STRIP_W := 84.0
const STRIP_LEN := 760.0
const GATE_GAP := 40.0

var stage: Dictionary
var length := 0.0
var theme := "city"
var night := false
var checkpoints: Array = []  # distances
var shortcuts: Array = []    # {d0, d1, exit_d, side, hidden}
var view_ranges: Array = []  # Vector2(d_min, d_max)

var _lanes: Array = []
var _curve: Array = []
var _decor: Array = []
var _font: Font = ThemeDB.fallback_font
var _t := 0.0


func setup(stage_dict: Dictionary, rng_seed: int) -> void:
	stage = stage_dict
	length = stage["length"]
	theme = stage["theme"]
	night = stage["night"]
	_lanes = stage["lanes"]
	_curve = stage["curve"]
	checkpoints.clear()
	for f in Stages.CHECKPOINTS:
		checkpoints.append(length * f)
	shortcuts.clear()
	for s in stage["shortcuts"]:
		var d0: float = length * s["at"]
		shortcuts.append({"d0": d0, "d1": d0 + STRIP_LEN, "exit_d": d0 + s["skip"], "side": s["side"], "hidden": s["hidden"]})
	_generate_decor(rng_seed)


func _process(delta: float) -> void:
	_t += delta


# ---------------------------------------------------------------- geometry

func lanes_at(d: float) -> float:
	var n := float(_lanes[0][1])
	for i in range(1, _lanes.size()):
		var at: float = _lanes[i][0] * length
		var k := clampf((d - (at - 500.0)) / 500.0, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		n = lerpf(n, float(_lanes[i][1]), k)
	return n


func half_width(d: float) -> float:
	return lanes_at(d) * LANE_W * 0.5


func center_x(d: float) -> float:
	var env := clampf(d / 1800.0, 0.0, 1.0) * clampf((length + 400.0 - d) / 1800.0, 0.0, 1.0)
	env = env * env * (3.0 - 2.0 * env)
	var x := 0.0
	var ph := 0.0
	for c in _curve:
		x += c[0] * sin(TAU * d / c[1] + ph)
		ph += 1.7
	return x * env


## Sideways drift of the road centre per unit of forward distance (dx/dd).
func slope(d: float) -> float:
	return (center_x(d + 8.0) - center_x(d - 8.0)) / 16.0


## Road direction as a rotation angle (0 = straight up, positive = bending right).
func heading(d: float) -> float:
	return atan(slope(d))


func edge_left(d: float) -> float:
	return center_x(d) - half_width(d)


func edge_right(d: float) -> float:
	return center_x(d) + half_width(d)


func lane_count(d: float) -> int:
	return maxi(1, roundi(lanes_at(d)))


func lane_x(d: float, lane: int) -> float:
	return lane_x_f(d, float(lane))


## Lane centres are LANE_W apart counted from the left edge; a lane that is disappearing as the
## road narrows slides smoothly towards the remaining ones, so positions never jump.
func lane_x_f(d: float, lane: float) -> float:
	var lf := lanes_at(d)
	var l := clampf(lane, 0.0, maxf(lf - 1.0, 0.0))
	return center_x(d) - lf * LANE_W * 0.5 + (l + 0.5) * LANE_W


func nearest_lane(d: float, x: float) -> int:
	var n := lane_count(d)
	var rel := (x - (center_x(d) - half_width(d))) / LANE_W
	return clampi(int(floor(rel)), 0, n - 1)


## Index of the shortcut strip containing this point, or -1.
func strip_at(x: float, d: float) -> int:
	for i in shortcuts.size():
		var s: Dictionary = shortcuts[i]
		if d >= s["d0"] and d <= s["d1"] + 60.0:  # includes the tunnel mouth
			var hw := half_width(d)
			var rel := (x - center_x(d)) * float(s["side"])
			if rel >= hw - 4.0 and rel <= hw + STRIP_W:
				return i
	return -1


## Is this point on tarmac (or the curb margin / a shortcut strip)?
func drivable(x: float, d: float, margin := 18.0) -> bool:
	if absf(x - center_x(d)) <= half_width(d) + margin:
		return true
	return strip_at(x, d) >= 0


# ---------------------------------------------------------------- decor

func _generate_decor(rng_seed: int) -> void:
	_decor.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for side in [-1, 1]:
		var d := -600.0
		while d < length + 1500.0:
			var item := {"d": d, "side": side, "off": rng.randf_range(24.0, 220.0), "size": rng.randf_range(0.7, 1.4),
				"r": rng.randf(), "kind": rng.randi() % 4}
			_decor.append(item)
			d += rng.randf_range(70.0, 190.0) if theme != "bridge" else rng.randf_range(300.0, 900.0)
	_decor.sort_custom(func(a, b): return a["d"] < b["d"])


func _first_decor(d_min: float) -> int:
	var lo := 0
	var hi := _decor.size()
	while lo < hi:
		var mid := (lo + hi) / 2
		if _decor[mid]["d"] < d_min:
			lo = mid + 1
		else:
			hi = mid
	return lo


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	# Merge overlapping camera ranges first, otherwise one view's ground would paint over
	# the other view's road where they overlap.
	var rs: Array = view_ranges.map(func(r): return Vector2(r.x - 160.0, r.y + 160.0))
	rs.sort_custom(func(a, b): return a.x < b.x)
	var merged: Array = []
	for r in rs:
		if not merged.is_empty() and r.x <= merged[-1].y:
			merged[-1].y = maxf(merged[-1].y, r.y)
		else:
			merged.append(r)
	for r in merged:
		_draw_range(r.x, r.y)


func _gap_on_side(d: float, side: int) -> bool:
	for s in shortcuts:
		if s["side"] == side and d >= s["d0"] - GATE_GAP and d <= s["d1"] + GATE_GAP:
			return true
	return false


func _draw_range(d_min: float, d_max: float) -> void:
	var ground: Color = stage["ground"]
	var ground2: Color = stage["ground2"]
	var asphalt: Color = stage["asphalt"]
	var curb: Color = stage["curb"]
	var cx_mid := center_x((d_min + d_max) * 0.5)
	var half_view := 1100.0

	# Ground with alternating bands (gives a sense of speed).
	draw_rect(Rect2(cx_mid - half_view - 600.0, -d_max, (half_view + 600.0) * 2.0, d_max - d_min), ground)
	var band := 160.0
	var b0 := int(floor(d_min / band))
	var b1 := int(ceil(d_max / band))
	for b in range(b0, b1 + 1):
		if b % 2 == 0:
			var y1 := -(b + 1) * band
			draw_rect(Rect2(cx_mid - half_view - 600.0, y1, (half_view + 600.0) * 2.0, band), ground2)

	if theme == "bridge":
		_draw_waves(d_min, d_max, cx_mid)

	# Decor behind the road.
	var idx := _first_decor(d_min - 300.0)
	while idx < _decor.size() and _decor[idx]["d"] <= d_max + 300.0:
		_draw_decor(_decor[idx])
		idx += 1

	var i0 := int(floor(d_min / SEG))
	var i1 := int(ceil(d_max / SEG))
	for i in range(i0, i1):
		var da := i * SEG
		var db := da + SEG
		var ya := -da
		var yb := -db
		var ca := center_x(da)
		var cb := center_x(db)
		var ha := half_width(da)
		var hb := half_width(db)

		if theme == "bridge":
			var deck := Color("b9b9b2")
			draw_colored_polygon(PackedVector2Array([Vector2(ca - ha - 30, ya), Vector2(ca + ha + 30, ya), Vector2(cb + hb + 30, yb), Vector2(cb - hb - 30, yb)]), deck)

		# Shortcut strips.
		for s in shortcuts:
			if da >= s["d0"] and db <= s["d1"] + SEG:
				var sd: float = s["side"]
				var inner_a := ca + sd * (ha - 4.0)
				var outer_a := ca + sd * (ha + STRIP_W)
				var inner_b := cb + sd * (hb - 4.0)
				var outer_b := cb + sd * (hb + STRIP_W)
				var col := Color("c9a868") if not s["hidden"] else ground.lerp(asphalt, 0.18)
				draw_colored_polygon(PackedVector2Array([Vector2(inner_a, ya), Vector2(outer_a, ya), Vector2(outer_b, yb), Vector2(inner_b, yb)]), col)
				if not s["hidden"] and (i / 3) % 2 == 0:
					draw_line(Vector2((inner_a + outer_a) * 0.5, ya), Vector2((inner_b + outer_b) * 0.5, yb), Color("fff3b0"), 3.0)

		# Curbs (with gaps where a shortcut begins).
		var cc := curb if (i / 4) % 2 == 0 else Color("c43b3b")
		if theme == "bridge":
			cc = Color("8a8a84") if (i / 4) % 2 == 0 else Color("6b6b66")
		if not _gap_on_side(da, -1):
			draw_colored_polygon(PackedVector2Array([Vector2(ca - ha - CURB, ya), Vector2(ca - ha, ya), Vector2(cb - hb, yb), Vector2(cb - hb - CURB, yb)]), cc)
		if not _gap_on_side(da, 1):
			draw_colored_polygon(PackedVector2Array([Vector2(ca + ha, ya), Vector2(ca + ha + CURB, ya), Vector2(cb + hb + CURB, yb), Vector2(cb + hb, yb)]), cc)

		# Asphalt.
		draw_colored_polygon(PackedVector2Array([Vector2(ca - ha, ya), Vector2(ca + ha, ya), Vector2(cb + hb, yb), Vector2(cb - hb, yb)]), asphalt)

		# Edge lines.
		var line_col := Color(1, 1, 1, 0.85)
		draw_line(Vector2(ca - ha + 6, ya), Vector2(cb - hb + 6, yb), line_col, 3.0)
		draw_line(Vector2(ca + ha - 6, ya), Vector2(cb + hb - 6, yb), line_col, 3.0)

		# Lane dividers, only where the lane count is stable.
		var la := lanes_at(da)
		var n := roundi(la)
		if absf(la - n) < 0.03 and (i / 4) % 2 == 0:
			for k in range(1, n):
				var xa := ca - ha + k * (2.0 * ha / n)
				var lb_ := lanes_at(db)
				var hb2 := hb
				var xb := cb - hb2 + k * (2.0 * hb2 / maxf(1.0, roundf(lb_)))
				draw_line(Vector2(xa, ya), Vector2(xb, yb), Color(1, 1, 1, 0.7), 3.0)

	_draw_gates(d_min, d_max)
	_draw_banners(d_min, d_max)


func _draw_waves(d_min: float, d_max: float, cx_mid: float) -> void:
	var step := 120.0
	var k0 := int(floor(d_min / step))
	var k1 := int(ceil(d_max / step))
	for k in range(k0, k1):
		var h := fmod(abs(sin(k * 12.9898) * 43758.5453), 1.0)
		var d := k * step
		var x := cx_mid + (h - 0.5) * 1800.0
		var y := -d
		draw_line(Vector2(x, y), Vector2(x + 26, y), Color(1, 1, 1, 0.35), 2.0)
		draw_line(Vector2(x + 8, y + 7), Vector2(x + 30, y + 7), Color(1, 1, 1, 0.25), 2.0)


func _draw_gates(d_min: float, d_max: float) -> void:
	for s in shortcuts:
		var sd: float = s["side"]
		# Tunnel mouth at the end of the strip.
		var d: float = s["d1"]
		if d < d_min - 100 or d > d_max + 100:
			continue
		var hw := half_width(d)
		var cx := center_x(d) + sd * (hw + STRIP_W * 0.5)
		draw_rect(Rect2(cx - STRIP_W * 0.5 - 8, -d - 14, STRIP_W + 16, 26), Color("3b3b44"))
		draw_rect(Rect2(cx - STRIP_W * 0.5 + 6, -d - 10, STRIP_W - 12, 22), Color("050507"))
		if not s["hidden"]:
			# Arrow signs leading to the strip.
			for k in 3:
				var dd: float = s["d0"] - 300.0 + k * 90.0
				var sx := center_x(dd) + sd * (half_width(dd) + 30.0)
				var ay := -dd
				draw_colored_polygon(PackedVector2Array([Vector2(sx - 14, ay + 8), Vector2(sx + 14, ay + 8), Vector2(sx, ay - 14)]).duplicate(), Color("ffd23f"))
			var txt_d: float = s["d0"] - 100.0
			var tx := center_x(txt_d) + sd * (half_width(txt_d) + 70.0)
			draw_string(_font, Vector2(tx - 52, -txt_d), "SHORTCUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffd23f"))


func _draw_banners(d_min: float, d_max: float) -> void:
	var marks := []
	for i in checkpoints.size():
		marks.append([checkpoints[i], "CHECKPOINT", Color("ffd23f")])
	marks.append([length, "GOAL", Color("ffffff")])
	for m in marks:
		var d: float = m[0]
		if d < d_min - 100 or d > d_max + 100:
			continue
		var cx := center_x(d)
		var hw := half_width(d)
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


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 14:
		var a := TAU * k / 14.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _draw_decor(it: Dictionary) -> void:
	var d: float = it["d"]
	var side: int = it["side"]
	var cx := center_x(d)
	var hw := half_width(d)
	if theme == "bridge":
		# Occasional boat out on the water.
		if it["kind"] == 0:
			var bx: float = cx + side * (hw + 120.0 + it["off"])
			var by := -d
			var drift := sin(_t * 0.5 + it["r"] * 6.0) * 6.0
			_ellipse(Vector2(bx + drift, by), 18, 46, Color("f2f2f2"))
			_ellipse(Vector2(bx + drift, by - 8), 10, 24, Color("c43b3b"))
		return
	var x: float = cx + side * (hw + CURB + it["off"])
	var y := -d
	var sz: float = it["size"]
	var r: float = it["r"]
	match theme:
		"city", "night":
			var w := 70.0 + 60.0 * sz
			var h := 60.0 + 70.0 * r
			var cols := [Color("8d99ae"), Color("a5a58d"), Color("b08968"), Color("6d6875"), Color("7f8fa6")]
			var base: Color = cols[it["kind"] % cols.size()]
			if night:
				base = base.darkened(0.25)
			var rx: float = x if side > 0 else x - w
			draw_rect(Rect2(rx, y - h * 0.5, w, h), base.darkened(0.25))
			draw_rect(Rect2(rx + 5, y - h * 0.5 + 5, w - 10, h - 10), base)
			draw_rect(Rect2(rx + w * 0.2, y - h * 0.2, 14, 14), base.darkened(0.3))
			if night:
				for k in 4:
					draw_rect(Rect2(rx + 8 + k * 16, y - h * 0.5 + 8, 8, 5), Color("ffe08a"))
				if it["kind"] == 1:
					var lx := cx + side * (hw + CURB + 6.0)
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
