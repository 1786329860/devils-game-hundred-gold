class_name BackgroundArt
extends Control

var accent := Color("#6e2534")
var high_contrast := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, Color(0.02, 0.025, 0.04, 0.58))
	for i in 12:
		var t := float(i) / 11.0
		var color := Color(0.08, 0.05, 0.09, 0.32).lerp(Color(0.03, 0.04, 0.07, 0.56), t)
		draw_rect(Rect2(0, size.y * t, size.x, size.y / 11.0 + 2), color)
	var center := Vector2(size.x * 0.5, size.y * 0.43)
	var base_radius := minf(size.x, size.y) * 0.29
	for ring in 5:
		var alpha := 0.13 - ring * 0.018
		draw_arc(center, base_radius + ring * 36.0, 0, TAU, 128, Color(accent, alpha), 2.0)
	for spoke in 12:
		var angle := TAU * spoke / 12.0
		var inner := center + Vector2.from_angle(angle) * base_radius * 0.42
		var outer := center + Vector2.from_angle(angle) * base_radius * 1.25
		draw_line(inner, outer, Color(accent, 0.09), 1.5)
	# 对称契约印记，不依赖外部素材也能保持完整视觉。
	var sigil := PackedVector2Array()
	for i in 10:
		var angle := -PI / 2.0 + TAU * i / 10.0
		var radius := base_radius * (0.34 if i % 2 == 0 else 0.14)
		sigil.append(center + Vector2.from_angle(angle) * radius)
	sigil.append(sigil[0])
	draw_polyline(sigil, Color(ThemeFactory.GOLD, 0.12 if not high_contrast else 0.24), 2.0, true)
	for i in 24:
		var x := fmod(float(i * 197), maxf(1.0, size.x))
		var y := fmod(float(i * 113 + 71), maxf(1.0, size.y))
		var radius := 1.0 + float(i % 3)
		draw_circle(Vector2(x, y), radius, Color(ThemeFactory.GOLD_BRIGHT, 0.08 + 0.02 * (i % 4)))
