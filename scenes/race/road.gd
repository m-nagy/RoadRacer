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
const CHUNK := 1024.0        # length of one scenery chunk (a whole number of segments)
const VIEW_MARGIN := 400.0   # chunks are kept this far beyond the visible range

var stage: StageData
var length := 0.0
var theme := "city"
var night := false
var checkpoints: Array = []  # distances
## A side road that skips ahead: a strip beside the road from d0 to d1, ending in a tunnel.
class ShortcutStrip:
	var d0 := 0.0
	var d1 := 0.0
	var exit_d := 0.0   # where the player comes out
	var side := 1       # -1 left of the road, 1 right
	var hidden := false # hidden ones have no signs or markings


var shortcuts: Array[ShortcutStrip] = []
var view_ranges: Array = []  # Vector2(d_min, d_max)

var _lanes: Array[LaneSection] = []
var _curve: Array[CurveWave] = []
var decor: Array = []         # scenery beside the road, sorted by distance
var _layers: Array[Node2D] = []
var _chunks: Dictionary = {}  # chunk index -> [ground, decor, surface, front] RoadChunk nodes
var _t := 0.0


func setup(stage_data: StageData, rng_seed: int) -> void:
	stage = stage_data
	length = stage.length
	theme = stage.theme
	night = stage.night
	_lanes = stage.lanes
	_curve = stage.curve
	checkpoints.clear()
	for f in Stages.CHECKPOINTS:
		checkpoints.append(length * f)
	shortcuts.clear()
	for s in stage.shortcuts:
		var d0: float = length * s.at
		var sc := ShortcutStrip.new()
		sc.d0 = d0
		sc.d1 = d0 + STRIP_LEN
		sc.exit_d = d0 + s.skip
		sc.side = s.side
		sc.hidden = s.hidden
		shortcuts.append(sc)
	_generate_decor(rng_seed)
	for l in RoadChunk.Layer.size():
		var layer_node := Node2D.new()
		add_child(layer_node)
		_layers.append(layer_node)


func _process(delta: float) -> void:
	_t += delta
	for k in _chunks:
		_chunks[k][RoadChunk.Layer.DECOR].animate(_t)


# ---------------------------------------------------------------- geometry

func lanes_at(d: float) -> float:
	var n := float(_lanes[0].lanes)
	for i in range(1, _lanes.size()):
		var at: float = _lanes[i].at * length
		var k := clampf((d - (at - 500.0)) / 500.0, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		n = lerpf(n, float(_lanes[i].lanes), k)
	return n


func half_width(d: float) -> float:
	return lanes_at(d) * LANE_W * 0.5


func center_x(d: float) -> float:
	var env := clampf(d / 1800.0, 0.0, 1.0) * clampf((length + 400.0 - d) / 1800.0, 0.0, 1.0)
	env = env * env * (3.0 - 2.0 * env)
	var x := 0.0
	var ph := 0.0
	for c in _curve:
		x += c.amplitude * sin(TAU * d / c.period + ph)
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
		var s := shortcuts[i]
		if d >= s.d0 and d <= s.d1 + 60.0:  # includes the tunnel mouth
			var hw := half_width(d)
			var rel := (x - center_x(d)) * float(s.side)
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
	decor.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for side in [-1, 1]:
		var d := -600.0
		while d < length + 1500.0:
			var item := {"d": d, "side": side, "off": rng.randf_range(24.0, 220.0), "size": rng.randf_range(0.7, 1.4),
				"r": rng.randf(), "kind": rng.randi() % 4}
			decor.append(item)
			d += rng.randf_range(70.0, 190.0) if theme != "bridge" else rng.randf_range(300.0, 900.0)
	decor.sort_custom(func(a, b): return a["d"] < b["d"])


func first_decor(d_min: float) -> int:
	var lo := 0
	var hi := decor.size()
	while lo < hi:
		var mid := (lo + hi) / 2
		if decor[mid]["d"] < d_min:
			lo = mid + 1
		else:
			hi = mid
	return lo


# ---------------------------------------------------------------- scenery chunks

## Is there a shortcut opening in the curb on this side at distance d?
func gap_on_side(d: float, side: int) -> bool:
	for s in shortcuts:
		if s.side == side and d >= s.d0 - GATE_GAP and d <= s.d1 + GATE_GAP:
			return true
	return false


## Tells the road which distance ranges the cameras can see. Scenery chunks are built for those
## ranges (plus a margin) and freed again once they scroll out of reach.
func set_view_ranges(ranges: Array) -> void:
	view_ranges = ranges
	var wanted := {}
	for r in ranges:
		for k in range(floori((r.x - VIEW_MARGIN) / CHUNK), floori((r.y + VIEW_MARGIN) / CHUNK) + 1):
			wanted[k] = true
	for k in _chunks.keys():
		if not wanted.has(k):
			for c in _chunks[k]:
				c.queue_free()
			_chunks.erase(k)
	var added := false
	for k in wanted:
		if not _chunks.has(k):
			var layers := []
			for l in _layers.size():
				var c := RoadChunk.new()
				c.setup(self, l, k * CHUNK, (k + 1) * CHUNK)
				_layers[l].add_child(c)
				layers.append(c)
			_chunks[k] = layers
			added = true
	if added:
		# Within a layer nearer chunks are drawn first, so decor further up the road overlaps it.
		var keys := _chunks.keys()
		keys.sort()
		for l in _layers.size():
			for i in keys.size():
				_layers[l].move_child(_chunks[keys[i]][l], i)
