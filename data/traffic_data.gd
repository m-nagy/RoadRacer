class_name TrafficData
extends Resource
## How busy a stage is and what drives on it.
## `kinds` and `weights` run in parallel: weights[i] is how common kinds[i] (see CarDefs) is.
## The order is the order the weighted pick walks through them.

@export var density := 1.0
@export var speed := 1.0                     # multiplier on every car's base speed
@export var kinds: Array[String] = []
@export var weights: Array[float] = []


func has_kind(kind: String) -> bool:
	return kinds.has(kind)


func weight_of(kind: String) -> float:
	var i := kinds.find(kind)
	return weights[i] if i >= 0 else 0.0
