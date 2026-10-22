class_name WorldData
extends Resource
## A world: one track and weather family with three stages that get harder one after the other.

@export var id := ""
@export var name := ""
@export var stages: Array[StageVariant] = []
