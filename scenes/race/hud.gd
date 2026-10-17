class_name Hud
extends Control
## Per-player overlay: timer/fuel, speed, score, course progress, button hints, pop-up messages.

var player: PlayerCar
var world: World
var stage_name := ""
var stage_no := 1
var all_players: Array = []

var _popups: Array = []   # {text, kind, age}
var _fade := 0.0
var _font: Font = ThemeDB.fallback_font
var _panel: StyleBoxTexture = UiTheme.box("panel_brown_dark.png", 24)
var _blink := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func add_popup(text: String, kind: String) -> void:
	_popups.append({"text": text, "kind": kind, "age": 0.0})
	if _popups.size() > 3:
		_popups.pop_front()


func fade() -> void:
	_fade = 1.0


func _process(delta: float) -> void:
	_blink += delta
	_fade = maxf(0.0, _fade - delta * 1.6)
	for p in _popups:
		p["age"] += delta
	_popups = _popups.filter(func(p): return p["age"] < 2.0)
	queue_redraw()


func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(_font, pos, s, align, width, size, 7, Color(0.08, 0.05, 0.03))
	draw_string(_font, pos, s, align, width, size, col)


func _draw() -> void:
	if player == null:
		return
	var w := size.x
	var h := size.y
	var low := player.time_left < 15.0

	# --- Timer panel (top-left)
	draw_style_box(_panel, Rect2(10, 10, 230, 104))
	_text(Vector2(26, 42), "TIME", 20, Color("ffd7a0"))
	var tcol := Color.WHITE if not low or int(_blink * 4.0) % 2 == 0 else Color("ff5a4a")
	_text(Vector2(26, 92), str(int(ceil(player.time_left))), 52, tcol)
	if player.penalty > 0.0:
		_text(Vector2(140, 92), "x1.5", 24, Color("ff8a4a"))
	# fuel bar
	var frac := clampf(player.time_left / 100.0, 0.0, 1.0)
	draw_rect(Rect2(150, 26, 18, 70), Color(0, 0, 0, 0.55))
	var bar_col := Color("5ad45a").lerp(Color("e04a3a"), clampf(1.0 - frac * 2.0, 0.0, 1.0))
	draw_rect(Rect2(152, 26 + 66 * (1.0 - frac) + 2, 14, 66 * frac), bar_col)

	# --- Score / speed panel (top-right of this half; leave room for progress bar)
	var rx := w - 270.0
	draw_style_box(_panel, Rect2(rx, 10, 232, 104))
	_text(Vector2(rx + 16, 40), "SCORE", 20, Color("ffd7a0"))
	_text(Vector2(rx + 76, 40), str(int(player.score)), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 140)
	_text(Vector2(rx + 16, 76), "SPEED", 20, Color("ffd7a0"))
	_text(Vector2(rx + 76, 78), "%d km/h" % int(player.kmh()), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 140)
	_text(Vector2(rx + 16, 104), "STAGE %d  -  %s" % [stage_no, String(world.level_name).to_upper()], 18, Color("c8e6ff"))

	# --- Course progress (right edge): this player's own bar and marker only
	var top := 130.0
	var bot := h - 120.0
	var bx := w - 24.0
	var pcol := _slot_color(player.slot)
	draw_rect(Rect2(bx - 5, top, 10, bot - top), Color(0, 0, 0, 0.55))
	var f := clampf(player.d() / world.road.length, 0.0, 1.0)
	var my := bot - (bot - top) * f
	draw_rect(Rect2(bx - 3, my, 6, bot - my), Color(pcol, 0.55))
	for cp in world.road.checkpoints:
		var yy: float = bot - (bot - top) * (cp / world.road.length)
		draw_rect(Rect2(bx - 11, yy - 2, 22, 4), Color("ffd23f"))
	draw_rect(Rect2(bx - 11, top - 2, 22, 5), Color.WHITE)
	draw_circle(Vector2(bx, my), 11.0, Color.BLACK)
	draw_circle(Vector2(bx, my), 8.5, pcol)

	_draw_controls(w, h)

	_draw_super(w)

	# --- Pop-ups
	var y := 190.0
	for p in _popups:
		var a := clampf(2.0 - p["age"], 0.0, 1.0)
		var col2 := Color("ffe36e") if p["kind"] == "good" else Color("ff6a5a")
		col2.a = a
		var sz := 36
		var tw := _font.get_string_size(p["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var o := Color(0.08, 0.05, 0.03, a)
		draw_string_outline(_font, Vector2(w * 0.5 - tw * 0.5, y - p["age"] * 14.0), p["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 8, o)
		draw_string(_font, Vector2(w * 0.5 - tw * 0.5, y - p["age"] * 14.0), p["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col2)
		y += 44.0

	# --- State overlays
	if player.state == PlayerCar.State.OUT:
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.45))
		var s := "OUT OF FUEL"
		var tw2 := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x
		_text(Vector2(w * 0.5 - tw2 * 0.5, h * 0.5), s, 48, Color("ff6a5a"))
	elif player.state == PlayerCar.State.FINISHED:
		var s2 := "FINISHED!"
		var tw3 := _font.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 56).x
		_text(Vector2(w * 0.5 - tw3 * 0.5, h * 0.4), s2, 56, Color("ffe36e"))
	if _fade > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, _fade * 0.9))


## Rainbow "super car" countdown bar (top centre).
func _draw_super(w: float) -> void:
	if player.super_t <= 0.0:
		return
	var bw := minf(w - 560.0, 320.0)
	if bw < 120.0:
		bw = 160.0
	var x0 := w * 0.5 - bw * 0.5
	var y0 := 128.0
	var frac := clampf(player.super_t / 15.0, 0.0, 1.0)
	draw_rect(Rect2(x0 - 4, y0 - 4, bw + 8, 26), Color(0, 0, 0, 0.7))
	var segs := 24
	for i in segs:
		var f := float(i) / segs
		if f > frac:
			break
		draw_rect(Rect2(x0 + bw * f, y0, bw / segs + 1.0, 18), Color.from_hsv(fposmod(f * 1.2 + _blink * 0.8, 1.0), 0.85, 1.0))
	var flash := player.super_t > 3.0 or int(_blink * 6.0) % 2 == 0
	_centered(w * 0.5, y0 - 10.0, "SUPER CAR  %d" % int(ceil(player.super_t)), 22, Color.WHITE if flash else Color("ff8a6a"))


func _centered(cx: float, y: float, s: String, size_px: int, col: Color) -> void:
	var tw := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	_text(Vector2(cx - tw * 0.5, y), s, size_px, col)


## Bottom-centre control pad: arrows light up while steering, slow/fast buttons while accelerating.
func _draw_controls(w: float, h: float) -> void:
	var slot := player.slot
	var kb: bool = Game.players[slot]["kb"]
	var cx := w * 0.5
	var y := h - 58.0
	var steer := InputManager.steer(slot)
	if player.easy:
		steer = clampf(player.vx / 120.0, -1.0, 1.0)  # show where the auto-steer is going
	var left_on := steer < -0.3
	var right_on := steer > 0.3
	var brake_on := InputManager.pressed(slot, "down") and not player.easy
	var ax := cx - 120.0
	var s := 40.0
	for item in [["left", -46.0, left_on], ["down", 0.0, brake_on], ["right", 46.0, right_on]]:
		var pos := Vector2(ax + item[1], y)
		if kb:
			KeyIcons.key(self, pos, InputManager.label(slot, item[0]), s, item[2])
		else:
			KeyIcons.pad_arrow(self, pos, item[0], s, item[2])
	_centered(ax, h - 12, "AUTO-STEER" if player.easy else "STEER", 15, Color("9be6ff") if player.easy else Color.WHITE)
	if player.braking and player.state == PlayerCar.State.RACING:
		var why := "SLOWING - TRAFFIC AHEAD" if player.easy else "BRAKING"
		_centered(cx, h - 100.0, why, 20, Color("ff8a6a"))
	# Gear buttons
	var a_on := InputManager.pressed(slot, "slow")
	var b_on := InputManager.pressed(slot, "fast")
	var bx := cx + 70.0
	var dev: int = Game.players[slot]["device"]
	var style := InputManager.pad_style(dev) if not kb and dev >= 0 else ""
	for g in [["slow", 0.0, Color("3ec45a"), a_on], ["fast", 64.0, Color("e0453a"), b_on]]:
		var lab := _gear_label(slot, g[0])
		if style == "ps" and lab in ["A", "B", "X", "Y"]:
			KeyIcons.face_button(self, Vector2(bx + g[1], y), lab, style, 22.0, g[3])   # Cross / Circle...
		else:
			KeyIcons.round_button(self, Vector2(bx + g[1], y), lab, g[2], 22.0, g[3])
	_centered(bx, h - 12, "SLOW", 15, Color.WHITE)
	_centered(bx + 64, h - 12, "FAST", 15, Color.WHITE)


func _gear_label(slot: int, action: String) -> String:
	var l := InputManager.label(slot, action)
	return l.substr(0, 4) if l.length() > 4 else l


func _slot_color(slot: int) -> Color:
	return Game.swatch(Game.players[slot]["color"])
