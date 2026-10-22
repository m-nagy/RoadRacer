class_name Weather
extends CanvasLayer
## Screen-space weather for one viewport (rain, snow, sand, leaves, wind streaks).

var kind := "none"
var _emitters: Array = []
var _tint: ColorRect
var _tex_streak: ImageTexture
var _tex_dot: ImageTexture


func _init() -> void:
	layer = 5


func setup(weather_kind: String) -> void:
	kind = weather_kind
	_tex_streak = _make_tex(2, 20)
	_tex_dot = _make_tex(6, 6)
	_tint = ColorRect.new()
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.color = Color(0, 0, 0, 0)
	add_child(_tint)
	match kind:
		"rain":
			_add(260, 0.55, Vector2(-0.2, 1.0), 1100.0, _tex_streak, Color(0.7, 0.8, 1.0, 0.55), 1.0)
			_tint.color = Color(0.05, 0.08, 0.2, 0.18)
		"snow":
			_add(160, 3.0, Vector2(-0.15, 1.0), 120.0, _tex_dot, Color(1, 1, 1, 0.9), 1.0)
			_tint.color = Color(0.85, 0.92, 1.0, 0.10)
		"sand":
			_add(120, 0.7, Vector2(-1.0, 0.25), 1100.0, _tex_streak, Color(0.86, 0.68, 0.38, 0.5), 1.0, true)
			_tint.color = Color(0.8, 0.55, 0.2, 0.22)
		"leaves":
			_add(14, 5.0, Vector2(-0.4, 1.0), 90.0, _tex_dot, Color(0.85, 0.55, 0.15, 0.9), 1.6)
		"wind":
			_add(30, 0.9, Vector2(-1.0, 0.1), 900.0, _tex_streak, Color(1, 1, 1, 0.25), 1.0, true)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _make_tex(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _add(amount: int, life: float, dir: Vector2, speed: float, tex: Texture2D, col: Color, scale_amt: float, horizontal := false) -> void:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.texture = tex
	p.direction = dir
	p.spread = 6.0 if speed > 500.0 else 25.0
	p.initial_velocity_min = speed * 0.8
	p.initial_velocity_max = speed * 1.2
	p.gravity = Vector2.ZERO
	p.color = col
	p.scale_amount_min = scale_amt
	p.scale_amount_max = scale_amt * 1.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(700, 10)
	p.local_coords = true
	p.set_meta("horizontal", horizontal)
	p.particle_flag_align_y = tex == _tex_streak
	add_child(p)
	_emitters.append(p)


## Emitters sit just outside the viewport edge they start from; only a resize moves them.
func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	for e in _emitters:
		if e.get_meta("horizontal"):
			# Emit from the right edge, travel left.
			e.position = Vector2(vp.x + 20.0, vp.y * 0.5)
			e.emission_rect_extents = Vector2(10, vp.y * 0.5)
		else:
			e.position = Vector2(vp.x * 0.5, -20.0)
			e.emission_rect_extents = Vector2(vp.x * 0.5 + 100.0, 10)
