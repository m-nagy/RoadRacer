class_name RaceRules
extends RefCounted
## The rules of a race: checkpoints, shortcuts, the finish line, overtakes, and what happens when
## a player runs out of fuel.

const SCORE_OVERTAKE := 50
const SCORE_CHECKPOINT := 1000

var world: World
var road: Road
var rivals: Array[Rival]
var players: Array[PlayerCar]

var _out_notified: Dictionary = {}
var _finished_notified: Dictionary = {}


func _init(w: World) -> void:
	world = w
	road = w.road
	rivals = w.rivals
	players = w.players


func update_progress() -> void:
	for p in players:
		if p.state != PlayerCar.State.RACING:
			continue
		var d: float = p.d()
		while p.next_cp < road.checkpoints.size() and d >= road.checkpoints[p.next_cp]:
			p.next_cp += 1
			p.time_left += world.cp_bonus
			p.score += SCORE_CHECKPOINT
			world.popup.emit(p.slot, "CHECKPOINT +%d" % int(world.cp_bonus), "good")
			AudioManager.play("checkpoint")
		var s := road.strip_at(p.position.x, d)
		if s >= 0 and d >= road.shortcuts[s].d1 - 50.0:  # nose reaches the tunnel
			var target: float = road.shortcuts[s].exit_d
			p.teleport_to(target)
			world.course.stream()
			p.score += 1000.0
			world.popup.emit(p.slot, "SHORTCUT!", "good")
			AudioManager.play("whoosh")
			world.shortcut_taken.emit(p.slot)
			continue
		if d >= road.length:
			p.score += int(p.time_left) * 100
			p.finish()
			AudioManager.engine_stop(p.slot)
			AudioManager.play("goal")
			world.popup.emit(p.slot, "GOAL!", "good")
			if not _finished_notified.has(p.slot):
				_finished_notified[p.slot] = true
				world.player_finished.emit(p.slot)
			continue
		# Overtakes
		for r in rivals:
			var ahead: bool = r.d() > d
			if r.was_ahead.get(p.slot, false) and not ahead and r.d() < d - r.hh and not r.passed_by.has(p.slot) and r.kind != "fuelcar":
				r.passed_by[p.slot] = true
				p.overtakes += 1
				p.score += SCORE_OVERTAKE
				AudioManager.play("overtake", -8.0)
			r.was_ahead[p.slot] = ahead


## Engine sound for each player, and the "out of fuel" notice the first time a player runs dry.
func update_players() -> void:
	for p in players:
		if p.state == PlayerCar.State.RACING:
			AudioManager.engine_set(p.slot, p.speed / PlayerCar.FAST_MAX)
		else:
			AudioManager.engine_set(p.slot, 0.0)
		if p.state == PlayerCar.State.OUT and not _out_notified.has(p.slot):
			_out_notified[p.slot] = true
			AudioManager.engine_stop(p.slot)
			world.popup.emit(p.slot, "OUT OF FUEL", "bad")
			world.player_out.emit(p.slot)
