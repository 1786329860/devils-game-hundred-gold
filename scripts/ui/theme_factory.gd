class_name ThemeFactory
extends RefCounted

const INK := Color("#10121a")
const PANEL := Color("#181b26")
const PANEL_LIGHT := Color("#222638")
const GOLD := Color("#d5ad55")
const GOLD_BRIGHT := Color("#f2d487")
const CRIMSON := Color("#8e3040")
const TEXT := Color("#eee7d5")
const MUTED := Color("#aaa493")
const SUCCESS := Color("#69b584")
const DANGER := Color("#d5636d")

static func create_theme(large_text: bool = false, high_contrast: bool = false) -> Theme:
	var theme := Theme.new()
	var scale := 1.18 if large_text else 1.0
	theme.default_font_size = int(18 * scale)
	theme.set_font_size("font_size", "Label", int(18 * scale))
	theme.set_font_size("font_size", "Button", int(18 * scale))
	theme.set_font_size("font_size", "OptionButton", int(17 * scale))
	theme.set_color("font_color", "Label", Color.WHITE if high_contrast else TEXT)
	theme.set_color("font_color", "Button", Color.WHITE if high_contrast else TEXT)
	theme.set_color("font_hover_color", "Button", GOLD_BRIGHT)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", Color("#666777"))
	theme.set_constant("outline_size", "Label", 2)
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.55))

	var button := panel_style(PANEL_LIGHT, GOLD.darkened(0.45), 1, 10)
	button.content_margin_left = 20
	button.content_margin_right = 20
	button.content_margin_top = 12
	button.content_margin_bottom = 12
	theme.set_stylebox("normal", "Button", button)
	var hover := panel_style(Color("#2c3042"), GOLD, 2, 10)
	hover.content_margin_left = 20
	hover.content_margin_right = 20
	hover.content_margin_top = 12
	hover.content_margin_bottom = 12
	theme.set_stylebox("hover", "Button", hover)
	var pressed := panel_style(Color("#342b28"), GOLD_BRIGHT, 2, 10)
	pressed.content_margin_left = 20
	pressed.content_margin_right = 20
	pressed.content_margin_top = 12
	pressed.content_margin_bottom = 12
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", panel_style(Color("#171923"), Color("#343746"), 1, 10))
	theme.set_stylebox("focus", "Button", panel_style(Color(0, 0, 0, 0), GOLD_BRIGHT, 2, 10))

	var line_edit := panel_style(Color("#11141e"), Color("#464b60"), 1, 8)
	line_edit.content_margin_left = 12
	line_edit.content_margin_right = 12
	line_edit.content_margin_top = 9
	line_edit.content_margin_bottom = 9
	theme.set_stylebox("normal", "LineEdit", line_edit)
	theme.set_stylebox("normal", "OptionButton", button)
	theme.set_stylebox("hover", "OptionButton", hover)
	theme.set_stylebox("pressed", "OptionButton", pressed)
	theme.set_stylebox("normal", "PanelContainer", panel_style(PANEL, Color("#35394a"), 1, 14))
	theme.set_stylebox("panel", "Panel", panel_style(PANEL, Color("#35394a"), 1, 14))
	theme.set_stylebox("panel", "PopupPanel", panel_style(PANEL_LIGHT, GOLD.darkened(0.35), 1, 8))
	theme.set_color("font_color", "RichTextLabel", TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_font_size("normal_font_size", "RichTextLabel", int(18 * scale))
	theme.set_constant("separation", "HBoxContainer", 12)
	theme.set_constant("separation", "VBoxContainer", 12)
	return theme

static func panel_style(color: Color, border_color: Color, border_width: int = 1, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

static func accent_button(button: Button, destructive: bool = false) -> void:
	var color := CRIMSON if destructive else Color("#735526")
	var border := DANGER if destructive else GOLD_BRIGHT
	button.add_theme_stylebox_override("normal", panel_style(color, border, 2, 10))
	button.add_theme_stylebox_override("hover", panel_style(color.lightened(0.10), border, 3, 10))
	button.add_theme_stylebox_override("pressed", panel_style(color.darkened(0.12), border, 2, 10))

