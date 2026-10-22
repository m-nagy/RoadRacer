class_name ObstacleData
extends Resource
## Which hazards a stage scatters on the road, and how many.

@export var density := 0.5
@export var kinds: Array[String] = []   # cone, barrel, rock, oil, snowbank, tire
