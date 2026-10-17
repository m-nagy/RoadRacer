class_name PlayerCard
extends Control
## One player's panel on the car selection screen: live recoloured car preview, colour and
## steering-mode choice, and a legend showing exactly this player's own keys / buttons.

var slot := 0
var _t := 0.0
var _sprite: Sprite2D
var _font: Font = ThemeDB.fallback_font
var _bg: StyleBoxTexture = UiTheme.box("panel_brown_dark.png", 28)


func _ready() -> void:
	custom_minimum_size = Vector2(560, 505)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/cars/Audi.png")
	_sprite.scale = Vector2(0.72, 0.72)
	add_child(_sprite)
	refresh()


func refresh() -> void:
	var cfg: Dictionary = Game.players[slot]
	_sprite.material = Game.make_car_material(cfg["color"])
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_sprite.position = Vector2(size.x * 0.5, 182 + sin(_t * 2.0) * 5.0)
	_sprite.rotation = sin(_t * 1.3) * 0.07
	queue_redraw()


func _centered(y: float, s: String, px: int, col: Color) -> void:
	KeyIcons.text(self, Vector2(size.x * 0.5, y), s, px, col, 7)


## Icon spec: ["key", label] keyboard key, ["pad", dir] D-pad arrow, ["btn", "A"/"B"] face button, ["start"].
func _icon_width(ic: Array) -> float:
	if ic[0] == "start" or (ic[0] == "key" and String(ic[1]).length() > 2 and not ic[1] in ["left", "right", "up", "down"]):
		return 62.0
	return 34.0


func _draw_icon(ic: Array, c: Vector2, lit := false) -> void:
	match ic[0]:
		"key":
			var lab: String = ic[1]
			var w := 30.0 if lab.length() <= 2 or lab in ["left", "right", "up", "down"] else 56.0
			if w > 30.0:
				var r := Rect2(c - Vector2(w, 30) * 0.5, Vector2(w, 30))
				draw_rect(r.grow(3.0), KeyIcons.OUTLINE)
				draw_rect(r, Color("8d7f6a"))
				KeyIcons.text(self, c + Vector2(0, -2), lab, 15, Color("2a2018"), 0)
			else:
				KeyIcons.key(self, c, lab, 30.0, lit)
		"pad":
			KeyIcons.pad_arrow(self, c, ic[1], 28.0, lit)
		"btn":
			KeyIcons.face_button(self, c, ic[1], _pad_style(), 15.0, true)
		"start":
			var r2 := Rect2(c - Vector2(56, 24) * 0.5, Vector2(56, 24))
			draw_rect(r2.grow(3.0), KeyIcons.OUTLINE)
			draw_rect(r2, Color("4a4a4a"))
			KeyIcons.text(self, c, "OPTIONS" if _pad_style() == "ps" else "START", 11 if _pad_style() == "ps" else 13, Color.WHITE, 0)


## Draws a centred row of [icons, caption] groups.
func _legend_row(y: float, groups: Array) -> void:
	var total := 0.0
	for g in groups:
		var w := 0.0
		for ic in g[0]:
			w += _icon_width(ic) + 4.0
		w += 6.0 + _font.get_string_size(g[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		total += w
	total += 18.0 * (groups.size() - 1)
	var x := size.x * 0.5 - total * 0.5
	for g in groups:
		for ic in g[0]:
			var iw := _icon_width(ic)
			_draw_icon(ic, Vector2(x + iw * 0.5, y))
			x += iw + 4.0
		x += 6.0
		var font_pos := Vector2(x, y + 7.0)
		draw_string_outline(_font, font_pos, g[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, KeyIcons.OUTLINE)
		draw_string(_font, font_pos, g[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		x += _font.get_string_size(g[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 18.0


func _pad_style() -> String:
	var dev: int = Game.players[slot]["device"]
	return InputManager.pad_style(dev) if dev >= 0 else "xbox"


## Icon for one of this player's actions, from their saved profile.
func _icons(action: String) -> Array:
	var cfg: Dictionary = Game.players[slot]
	var lab := InputManager.label(slot, action)
	if cfg["kb"]:
		return ["key", lab]
	match lab:
		"A", "B", "X", "Y": return ["btn", lab]
		"Start": return ["start"]
		"left", "right", "up", "down": return ["pad", lab]
	return ["key", lab]


func _draw() -> void:
	var cfg: Dictionary = Game.players[slot]
	draw_style_box(_bg, Rect2(Vector2.ZERO, size))
	var pcol := Color("ff6a5a") if slot == 0 else Color("5ab0ff")
	_centered(44, "PLAYER %d" % (slot + 1), 40, pcol)
	_centered(80, "Keyboard" if cfg["kb"] else ("PlayStation gamepad" if _pad_style() == "ps" else "Gamepad"), 20, Color(1, 1, 1, 0.75))

	# Colour name with arrows, and swatches
	var c: Dictionary = Game.COLORS[cfg["color"]]
	var ay := 296.0
	_centered(ay, c["name"].to_upper(), 34, Game.swatch(cfg["color"]).lightened(0.15))
	var nw := _font.get_string_size(c["name"].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	var blink := int(_t * 3.0) % 2 == 0
	_draw_icon(_icons("left"), Vector2(size.x * 0.5 - nw * 0.5 - 34, ay), blink)
	_draw_icon(_icons("right"), Vector2(size.x * 0.5 + nw * 0.5 + 34, ay), blink)
	var n := Game.COLORS.size()
	var sx := size.x * 0.5 - (n - 1) * 20.0
	for i in n:
		var p := Vector2(sx + i * 40.0, ay + 36)
		draw_circle(p, 13 if i == cfg["color"] else 9, Color.BLACK)
		draw_circle(p, 11 if i == cfg["color"] else 7, Game.swatch(i))

	# Steering mode
	var auto: bool = cfg["easy"]
	var lbl := "AUTO-STEER: press one button, the car steers itself" if auto else "MANUAL: you steer the car"
	_centered(372, lbl, 20, Color("9be6ff") if auto else Color("ffe9b0"))

	# What each button does on THIS screen
	draw_rect(Rect2(18, 392, size.x - 36, 98), Color(0, 0, 0, 0.32))
	if cfg["ready"]:
		_centered(430, "READY!", 40, Color("6dff7a"))
		_legend_row(472, [[[_icons("fast")], "not ready yet"]])
	else:
		_legend_row(414, [[[_icons("left"), _icons("right")], "CHANGE CAR COLOUR"]])
		_legend_row(447, [[[_icons("up"), _icons("down")], "CHANGE STEERING MODE"]])
		var groups := [[[_icons("slow")], "READY"]]
		if cfg["kb"]:
			groups.append([[["key", "Enter"]], "START NOW"])
		_legend_row(480, groups)
