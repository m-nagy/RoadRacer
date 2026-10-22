class_name LaneSection
extends Resource
## From `at` (a fraction of the stage length) on, the road has `lanes` lanes; changes blend smoothly.

@export_range(0.0, 1.0) var at := 0.0
@export_range(1, 6) var lanes := 4
