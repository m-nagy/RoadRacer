class_name StageButton
extends Button
## One stage in Stage Select: its name, and either the best score or why it is locked.
## Challenges also show their weather and length.

var stage_id := ""


func setup(stage: StageData, number: int, unlocked: bool, best: int) -> void:
	stage_id = stage.id
	disabled = not unlocked
	var best_text := "Best: %d" % best if unlocked and best > 0 else ""
	if Stages.is_challenge(stage.id):
		var km := stage.length / 8.0 / 1000.0   # 8 px = 1 displayed metre
		var info := best_text
		if not unlocked:
			info = "Locked - clear %s first" % Stages.by_id(Stages.requirement(stage.id)).name
		text = "C%d. %s\n%s  -  %.1f km\n%s" % [number, stage.name, stage.weather.label, km, info]
		add_theme_font_size_override("font_size", 22)
	else:
		text = "%d. %s\n%s" % [number, stage.name, best_text if unlocked else "Locked"]
