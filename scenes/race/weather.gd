class_name Weather
extends CanvasLayer
## Screen-space weather for one viewport (rain, snow, sand, leaves, wind streaks), built from a WeatherData.

var _emitters: Array = []
var _tint: ColorRect
var _tex_streak: ImageTexture
var _tex_dot: ImageTexture
var _tex_blob: GradientTexture2D


func _init() -> void:
	layer = 5


## Builds the tint and one particle emitter per layer of the weather. `density` thins the particles out.
func setup(weather: WeatherData, density := 1.0) -> void:
	_tex_streak = _make_tex(2, 20)
	_tex_dot = _make_tex(6, 6)
	_tex_blob = _make_blob()
	_tint = ColorRect.new()
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.color = weather.tint
	add_child(_tint)
	for l in weather.layers:
		_add(l, density)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _make_tex(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _make_blob() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


func _add(l: WeatherLayer, density: float) -> void:
	var tex: Texture2D = _tex_dot
	match l.shape:
		WeatherLayer.Shape.STREAK: tex = _tex_streak
		WeatherLayer.Shape.BLOB: tex = _tex_blob
	var p := CPUParticles2D.new()
	p.amount = maxi(1, roundi(l.amount * density))
	p.lifetime = l.lifetime
	p.preprocess = l.lifetime
	p.texture = tex
	p.direction = l.direction
	p.spread = 6.0 if l.speed > 500.0 else 25.0
	p.initial_velocity_min = l.speed * 0.8
	p.initial_velocity_max = l.speed * 1.2
	p.gravity = Vector2.ZERO
	p.color = l.color
	p.scale_amount_min = l.scale
	p.scale_amount_max = l.scale * 1.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(700, 10)
	p.local_coords = true
	p.set_meta("horizontal", l.horizontal)
	p.particle_flag_align_y = l.shape == WeatherLayer.Shape.STREAK
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
