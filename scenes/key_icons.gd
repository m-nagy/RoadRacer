class_name KeyIcons
## Draws on-screen button / key glyphs (arrow keys, letter keys, round A/B buttons, D-pad).
## Arrows are drawn as shapes so they never depend on font glyph coverage.

const OUTLINE := Color(0.08, 0.05, 0.03)


static func text(ci: CanvasItem, center: Vector2, s: String, px: int, col: Color, outline := 6) -> void:
	var font := ThemeDB.fallback_font
	var sz := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	var pos := center + Vector2(-sz.x * 0.5, px * 0.36)
	if outline > 0:
		ci.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, Color(OUTLINE, col.a))
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


static func _triangle(ci: CanvasItem, c: Vector2, dir: String, r: float, col: Color) -> void:
	var pts: PackedVector2Array
	match dir:
		"left": pts = [c + Vector2(-r, 0), c + Vector2(r * 0.7, -r), c + Vector2(r * 0.7, r)]
		"right": pts = [c + Vector2(r, 0), c + Vector2(-r * 0.7, -r), c + Vector2(-r * 0.7, r)]
		"up": pts = [c + Vector2(0, -r), c + Vector2(-r, r * 0.7), c + Vector2(r, r * 0.7)]
		_: pts = [c + Vector2(0, r), c + Vector2(-r, -r * 0.7), c + Vector2(r, -r * 0.7)]
	ci.draw_colored_polygon(pts, col)


## A keyboard key cap. `label` is "left"/"right"/"up"/"down" for arrows, otherwise text.
static func key(ci: CanvasItem, c: Vector2, label: String, s: float, lit: bool) -> void:
	var r := Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
	ci.draw_rect(r.grow(3.0), OUTLINE)
	ci.draw_rect(r, Color("fff4d6") if lit else Color("8d7f6a"))
	ci.draw_rect(Rect2(r.position + Vector2(0, s - 5), Vector2(s, 5)), Color(0, 0, 0, 0.25))
	if lit:
		ci.draw_rect(r.grow(7.0), Color.WHITE, false, 3.0)
	var ink := Color("3a2210") if lit else Color("2a2018")
	if label in ["left", "right", "up", "down"]:
		_triangle(ci, c + Vector2(0, -1), label, s * 0.26, ink)
	else:
		var px := int(s * (0.5 if label.length() <= 1 else 0.32))
		text(ci, c + Vector2(0, -2), label, px, ink, 0)


## A round face button (gamepad A / B).
static func round_button(ci: CanvasItem, c: Vector2, label: String, col: Color, r: float, lit: bool) -> void:
	ci.draw_circle(c, r + 3.0, OUTLINE)
	ci.draw_circle(c, r, col if lit else col.darkened(0.55))
	if lit:
		ci.draw_arc(c, r + 6.0, 0.0, TAU, 32, Color.WHITE, 3.0)
	text(ci, c, label, int(r * 1.1), Color.WHITE, 0)


## A face button labelled the way this pad style prints it: Xbox letters (A B X Y, coloured), or
## PlayStation symbols (Cross Circle Square Triangle, drawn as shapes) for the same buttons.
static func face_button(ci: CanvasItem, c: Vector2, xbox_label: String, style: String, r: float, lit: bool) -> void:
	if style != "ps":
		var cols := {"A": Color("3ec45a"), "B": Color("e0453a"), "X": Color("5a7ad8"), "Y": Color("f2c230")}
		round_button(ci, c, xbox_label, cols.get(xbox_label, Color("5a7ad8")), r, lit)
		return
	ci.draw_circle(c, r + 3.0, OUTLINE)
	ci.draw_circle(c, r, Color("2c2f38") if lit else Color("1c1e24"))
	if lit:
		ci.draw_arc(c, r + 6.0, 0.0, TAU, 32, Color.WHITE, 3.0)
	var s := r * 0.48
	var w := maxf(2.0, r * 0.2)
	match xbox_label:
		"A":   # Cross
			var col := Color("7cb8ff")
			ci.draw_line(c + Vector2(-s, -s), c + Vector2(s, s), col, w)
			ci.draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, w)
		"B":   # Circle
			ci.draw_arc(c, s, 0.0, TAU, 24, Color("ff6a7a"), w)
		"X":   # Square
			ci.draw_rect(Rect2(c - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7), Color("e08cff"), false, w)
		_:     # Triangle
			var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, s * 0.75), c + Vector2(-s, s * 0.75), c + Vector2(0, -s)])
			ci.draw_polyline(pts, Color("6adf9a"), w)


## What the button is called on this pad style ("A" -> "Cross" on a PlayStation pad).
static func face_name(xbox_label: String, style: String) -> String:
	if style != "ps":
		return xbox_label
	return {"A": "Cross", "B": "Circle", "X": "Square", "Y": "Triangle", "Start": "Options", "Back": "Share"}.get(xbox_label, xbox_label)


## A D-pad arrow button (gamepad).
static func pad_arrow(ci: CanvasItem, c: Vector2, dir: String, s: float, lit: bool) -> void:
	var r := Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
	ci.draw_rect(r.grow(3.0), OUTLINE)
	ci.draw_rect(r, Color("e8e8e8") if lit else Color("4a4a4a"))
	if lit:
		ci.draw_rect(r.grow(7.0), Color.WHITE, false, 3.0)
	_triangle(ci, c, dir, s * 0.27, Color("222222") if lit else Color("bbbbbb"))


## Keyboard icon: dark keyboard body with rows of keys. `s` is the width.
static func keyboard_icon(ci: CanvasItem, c: Vector2, s: float, tint: Color = Color("e8e2d0")) -> void:
	var h := s * 0.5
	var r := Rect2(c - Vector2(s, h) * 0.5, Vector2(s, h))
	ci.draw_rect(r.grow(4.0), OUTLINE)
	ci.draw_rect(r, Color("3b3f4a"))
	var rows := 3
	var cols := 8
	var pad := s * 0.06
	var kw := (s - pad * 2.0) / cols
	var kh := (h - pad * 2.0) / (rows + 0.6)
	for row in rows:
		for col in cols:
			ci.draw_rect(Rect2(r.position + Vector2(pad + col * kw + 1.5, pad + row * kh + 1.5), Vector2(kw - 3.0, kh - 3.0)), tint)
	ci.draw_rect(Rect2(r.position + Vector2(pad + kw * 1.5, pad + rows * kh + 1.5), Vector2(kw * 5.0, kh * 0.55)), tint)


## Gamepad icon in "xbox" or "ps" style. `s` is the width.
static func pad_icon(ci: CanvasItem, c: Vector2, s: float, style := "xbox", tint: Color = Color("d8dbe3")) -> void:
	var w := s
	var h := s * 0.62
	# Body: wide centre with two grips.
	var body := PackedVector2Array([
		c + Vector2(-w * 0.34, -h * 0.5), c + Vector2(w * 0.34, -h * 0.5),
		c + Vector2(w * 0.5, -h * 0.1), c + Vector2(w * 0.5, h * 0.35),
		c + Vector2(w * 0.4, h * 0.5), c + Vector2(w * 0.3, h * 0.5), c + Vector2(w * 0.18, h * 0.12),
		c + Vector2(-w * 0.18, h * 0.12), c + Vector2(-w * 0.3, h * 0.5), c + Vector2(-w * 0.4, h * 0.5),
		c + Vector2(-w * 0.5, h * 0.35), c + Vector2(-w * 0.5, -h * 0.1)])
	var outline := body.duplicate()
	ci.draw_colored_polygon(body, tint)
	outline.append(outline[0])
	ci.draw_polyline(outline, OUTLINE, 3.0)
	var dark := Color("30343d")
	var stick_l := c + Vector2(-w * 0.26, -h * 0.02) if style == "xbox" else c + Vector2(-w * 0.14, h * 0.1)
	var dpad := c + Vector2(-w * 0.14, h * 0.1) if style == "xbox" else c + Vector2(-w * 0.28, -h * 0.05)
	var stick_r := c + Vector2(w * 0.14, h * 0.1)
	ci.draw_circle(stick_l, w * 0.075, dark)
	ci.draw_circle(stick_r, w * 0.075, dark)
	ci.draw_rect(Rect2(dpad - Vector2(w * 0.05, w * 0.015), Vector2(w * 0.1, w * 0.03)), dark)
	ci.draw_rect(Rect2(dpad - Vector2(w * 0.015, w * 0.05), Vector2(w * 0.03, w * 0.1)), dark)
	var fb := c + Vector2(w * 0.26, -h * 0.05) if style == "xbox" else c + Vector2(w * 0.28, -h * 0.05)
	var cols := [Color("3ec45a"), Color("e0453a"), Color("3a74e0"), Color("f2c230")] if style == "xbox" else [Color("5ab0ff"), Color("ff6a7a"), Color("d58cff"), Color("6adf9a")]
	var off := w * 0.065
	for i in 4:
		var d: Vector2 = [Vector2(0, off), Vector2(off, 0), Vector2(-off, 0), Vector2(0, -off)][i]
		ci.draw_circle(fb + d, w * 0.035, cols[i])
