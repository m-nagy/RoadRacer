class_name HudOverlay
extends Control
## The HUD parts that are drawn rather than built from nodes: the course progress bar, the key /
## button pad at the bottom and the super-car countdown. It only redraws when something it shows
## has changed (the rainbow bar, while a super car is active, changes every frame).

var _hud: Hud
var _font: Font = ThemeDB.fallback_font
var _blink := 0.0
var _last_key: Array = []


func _ready() -> void:
	_hud = get_parent()
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	var player := _hud.player
	if player == null:
		return
	_blink += delta
	var key := _state_key(player)
	if key != _last_key or player.super_t > 0.0:
		_last_key = key
		queue_redraw()


## Everything the overlay shows apart from the rainbow bar, boiled down to a comparable value.
func _state_key(player: PlayerCar) -> Array:
	var slot := player.slot
	var steer := InputManager.steer(slot)
	if player.easy:
		steer = clampf(player.vx / 120.0, -1.0, 1.0)
	var f := clampf(player.d() / _hud.world.road.length, 0.0, 1.0)
	return [roundi(f * 2000.0), steer < -0.3, steer > 0.3, InputManager.pressed(slot, "down") and not player.easy,
		InputManager.pressed(slot, "slow"), InputManager.pressed(slot, "fast"),
		player.braking and player.state == PlayerCar.State.RACING, player.easy, player.super_t > 0.0]


func _text(pos: Vector2, s: String, size_px: int, col: Color) -> void:
	draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 7, Color(0.08, 0.05, 0.03))
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


func _centered(cx: float, y: float, s: String, size_px: int, col: Color) -> void:
	var tw := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	_text(Vector2(cx - tw * 0.5, y), s, size_px, col)


func _draw() -> void:
	var player := _hud.player
	if player == null:
		return
	var w := size.x
	var h := size.y
	_draw_course(player, w, h)
	_draw_controls(player, w, h)
	_draw_super(player, w)


## Course progress (right edge): this player's own bar and marker only.
func _draw_course(player: PlayerCar, w: float, h: float) -> void:
	var road: Road = _hud.world.road
	var top := 130.0
	var bot := h - 120.0
	var bx := w - 24.0
	var pcol := Game.swatch(Game.players[player.slot]["color"])
	draw_rect(Rect2(bx - 5, top, 10, bot - top), Color(0, 0, 0, 0.55))
	var f := clampf(player.d() / road.length, 0.0, 1.0)
	var my := bot - (bot - top) * f
	draw_rect(Rect2(bx - 3, my, 6, bot - my), Color(pcol, 0.55))
	for cp in road.checkpoints:
		var yy: float = bot - (bot - top) * (cp / road.length)
		draw_rect(Rect2(bx - 11, yy - 2, 22, 4), Color("ffd23f"))
	draw_rect(Rect2(bx - 11, top - 2, 22, 5), Color.WHITE)
	draw_circle(Vector2(bx, my), 11.0, Color.BLACK)
	draw_circle(Vector2(bx, my), 8.5, pcol)


## Rainbow "super car" countdown bar (top centre).
func _draw_super(player: PlayerCar, w: float) -> void:
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


## Bottom-centre control pad: arrows light up while steering, slow/fast buttons while accelerating.
func _draw_controls(player: PlayerCar, w: float, h: float) -> void:
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
