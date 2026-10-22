class_name CarKind
extends Resource
## Sprite, size and behaviour of one kind of car. Speeds are px/s (1 km/h = 1.8 px/s).

@export var texture: Texture2D
@export var frames: Array[Texture2D] = []   # animated lights (police, ambulance); empty = static
@export var scale := 0.46
@export var hw := 20.0                      # half width of the collision box
@export var hh := 43.0                      # half length
@export var speed := 300.0
@export_enum("keeper", "passive", "changer", "blocker", "rammer", "passer") var behavior := "keeper"
