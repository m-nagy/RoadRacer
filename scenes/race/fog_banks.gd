class_name FogBanks
extends Node2D
## Fog as drifting clouds that cover some stretches of the road and leave the rest clear.
## The banks are placed from the stage seed (so a run repeats), drawn in world space above the road and
## the cars, and only for the part of the road that is on screen. density_at() tells how deep in fog a
## distance is, which the weather layer turns into a screen haze.

const EDGE := 350.0          # a bank thins out over this distance at both ends
const CLEAR_START := 1800.0  # the start and the finish stay clear
const CLEAR_END := 1500.0
const TEX := 128

class Bank:
	var d0 := 0.0
	var d1 := 0.0
	var puffs: Array = []    # {d, x, size, alpha, speed, phase}

var _road: Road
var _weather: WeatherData
var _banks: Array[Bank] = []
var _tex: ImageTexture
var _t := 0.0


func setup(road: Road, weather: WeatherData, rng_seed: int, puff_scale := 1.0) -> void:
	_road = road
	_weather = weather
	z_index = 20
	_tex = _make_texture(rng_seed)
	# A separate generator, so the clouds never disturb the random numbers the course uses.
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed * 31 + 7
	var d := CLEAR_START + rng.randf_range(0.0, 1200.0)
	var end := road.length - CLEAR_END
	var cover := clampf(weather.fog_banks, 0.05, 0.9)
	while d < end:
		var b := Bank.new()
		b.d0 = d
		b.d1 = minf(d + rng.randf_range(700.0, 1800.0), end)
		var count := maxi(3, roundi((b.d1 - b.d0) / 130.0 * puff_scale))
		for i in count:
			b.puffs.append({
				"d": rng.randf_range(b.d0, b.d1),
				"x": rng.randf_range(0.0, 1.0),
				"size": rng.randf_range(420.0, 760.0),
				"alpha": rng.randf_range(0.55, 1.0),
				"speed": rng.randf_range(8.0, 30.0) * (1.0 if rng.randf() < 0.5 else -1.0),
				"phase": rng.randf_range(0.0, TAU),
			})
		_banks.append(b)
		# Gap so that banks cover about `cover` of the road: gap = bank length * (1 - cover) / cover.
		d = b.d1 + (b.d1 - b.d0) * (1.0 - cover) / cover * rng.randf_range(0.7, 1.3)


## Soft, cloud-like puff: seamless noise under a round falloff.
func _make_texture(rng_seed: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = rng_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	var src := noise.get_seamless_image(TEX, TEX, false)
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var c := (TEX - 1) * 0.5
	for y in TEX:
		for x in TEX:
			var r := Vector2(x - c, y - c).length() / c
			var fall := 1.0 - smoothstep(0.25, 1.0, r)
			var n := src.get_pixel(x, y).r
			img.set_pixel(x, y, Color(1, 1, 1, clampf(fall * (0.35 + 0.9 * n), 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## 0 (clear) to 1 (middle of a bank) at distance d along the road.
func density_at(d: float) -> float:
	for b in _banks:
		if d >= b.d0 - EDGE and d <= b.d1 + EDGE:
			var k := minf(smoothstep(b.d0 - EDGE, b.d0 + EDGE, d), 1.0 - smoothstep(b.d1 - EDGE, b.d1 + EDGE, d))
			return clampf(k, 0.0, 1.0)
	return 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for r in _road.view_ranges:
		for b in _banks:
			if b.d1 + 700.0 < r.x or b.d0 - 700.0 > r.y:
				continue
			for p in b.puffs:
				if p["d"] + p["size"] < r.x or p["d"] - p["size"] > r.y:
					continue
				_draw_puff(b, p)


func _draw_puff(b: Bank, p: Dictionary) -> void:
	var d: float = p["d"]
	var span := _road.half_width(d) * 2.0 + 900.0
	var along := fposmod(p["x"] * span + _t * p["speed"], span)
	var x := _road.center_x(d) - span * 0.5 + along
	var fade := minf(smoothstep(b.d0 - EDGE, b.d0 + EDGE, d), 1.0 - smoothstep(b.d1 - EDGE, b.d1 + EDGE, d))
	var edge := minf(along, span - along) / 300.0   # a puff thins out where it wraps around
	var a: float = p["alpha"] * _weather.fog_alpha * clampf(fade, 0.0, 1.0) * clampf(edge, 0.0, 1.0) \
		* (0.85 + 0.15 * sin(_t * 0.4 + p["phase"]))
	if a <= 0.01:
		return
	var s: float = p["size"]
	var col := _weather.fog_color
	col.a = a
	draw_texture_rect(_tex, Rect2(x - s * 0.5, -d - s * 0.35, s, s * 0.7), false, col)
