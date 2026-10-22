class_name ShortcutData
extends Resource
## A shortcut beside the road.

@export_range(0.0, 1.0) var at := 0.5     # where it starts, as a fraction of the stage length
@export var skip := 5000.0                # distance it saves
@export var hidden := false               # no signs or markings
@export_enum("Left:-1", "Right:1") var side := 1
