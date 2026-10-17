class_name UiTheme
## Builds the shared Control theme from the Kenney adventure UI pack.

const UI := "res://assets/ui/"


static func box(tex: String, margin: int, content_h := 0, content_v := 0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(UI + tex)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = content_h
	sb.content_margin_right = content_h
	sb.content_margin_top = content_v
	sb.content_margin_bottom = content_v
	return sb


## A slimmer version of the themed button, for dense screens (the controls table).
static func compact(b: Button, height := 36) -> void:
	b.add_theme_stylebox_override("normal", box("button_brown.png", 14, 16, 2))
	b.add_theme_stylebox_override("hover", box("button_grey.png", 14, 16, 2))
	b.add_theme_stylebox_override("focus", box("button_red.png", 14, 16, 2))
	b.add_theme_stylebox_override("pressed", box("button_grey.png", 14, 16, 2))
	b.custom_minimum_size.y = height


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 30
	t.set_stylebox("normal", "Button", box("button_brown.png", 20, 28, 12))
	t.set_stylebox("hover", "Button", box("button_grey.png", 20, 28, 12))
	t.set_stylebox("focus", "Button", box("button_red.png", 20, 28, 12))
	t.set_stylebox("pressed", "Button", box("button_grey.png", 20, 28, 12))
	t.set_stylebox("disabled", "Button", box("button_grey.png", 20, 28, 12))
	var ink := Color(0.24, 0.13, 0.06)
	t.set_color("font_color", "Button", ink)
	t.set_color("font_hover_color", "Button", ink)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ink)
	t.set_color("font_disabled_color", "Button", Color(0.24, 0.13, 0.06, 0.5))
	t.set_color("font_outline_color", "Button", Color(0.35, 0.05, 0.05))
	t.set_constant("outline_size", "Button", 0)
	t.set_font_size("font_size", "Button", 32)
	t.set_stylebox("panel", "Panel", box("panel_brown_dark.png", 28))
	t.set_stylebox("panel", "PanelContainer", box("panel_brown_dark.png", 28, 24, 20))
	t.set_color("font_outline_color", "Label", Color(0.1, 0.06, 0.03))
	t.set_constant("outline_size", "Label", 6)
	return t
