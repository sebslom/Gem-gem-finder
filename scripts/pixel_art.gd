class_name GemArt
extends RefCounted

const SUITS = [Color("57b6e2"), Color("a16bcb"), Color("da6453"), Color("7bb956"), Color("e8ba5b")]

static func astronaut(canvas: CanvasItem, pos: Vector2, color: Color, phase: float, facing: float = 1.0, scale_value: float = 1.0) -> void:
	var outline := Color("283b43")
	# Deliberate pixel silhouettes: backpack, boots, gloves and a reflective visor.
	var stride := roundf(sin(phase) * 3) * scale_value
	var s := scale_value
	canvas.draw_rect(Rect2(pos + Vector2(-11 * facing, -4) * s, Vector2(6, 17) * s), outline)
	canvas.draw_rect(Rect2(pos + Vector2(-10 * facing, -2) * s, Vector2(4, 12) * s), Color("cc7953"))
	canvas.draw_rect(Rect2(pos + Vector2(-7, -4) * s, Vector2(14, 20) * s), outline)
	canvas.draw_rect(Rect2(pos + Vector2(-6, -3) * s, Vector2(12, 16) * s), color)
	canvas.draw_rect(Rect2(pos + Vector2(-3, -3) * s, Vector2(6, 8) * s), Color("dce4d2"))
	canvas.draw_rect(Rect2(pos + Vector2(-7 * s, 12 * s + stride), Vector2(6, 8) * s), Color("dde5d8"))
	canvas.draw_rect(Rect2(pos + Vector2(1 * s, 12 * s - stride), Vector2(6, 8) * s), Color("c6d5c9"))
	canvas.draw_rect(Rect2(pos + Vector2(-9, -19) * s, Vector2(18, 17) * s), outline)
	canvas.draw_rect(Rect2(pos + Vector2(-7, -21) * s, Vector2(14, 21) * s), Color("e2e9d8"))
	canvas.draw_rect(Rect2(pos + Vector2(-10, -16) * s, Vector2(20, 12) * s), Color("e2e9d8"))
	canvas.draw_rect(Rect2(pos + Vector2(-6 + facing, -17) * s, Vector2(12, 13) * s), Color("31494e"))
	canvas.draw_rect(Rect2(pos + Vector2(-4 + facing, -15) * s, Vector2(8, 8) * s), Color("557776"))
	canvas.draw_rect(Rect2(pos + Vector2(-3 + facing, -15) * s, Vector2(4, 3) * s), Color("aac4ac"))
	canvas.draw_rect(Rect2(pos + Vector2(6 * facing, 1) * s, Vector2(5, 8) * s), Color("dce4d2"))

static func tree(canvas: CanvasItem, pos: Vector2, height: float, tint: Color) -> void:
	canvas.draw_rect(Rect2(pos + Vector2(-9, -height * 0.7), Vector2(18, height * 0.7)), Color("6c5437") * tint)
	canvas.draw_rect(Rect2(pos + Vector2(-9, -height * 0.7), Vector2(5, height * 0.7)), Color("4d4932") * tint)
	for layer in 4:
		var width := (height * 0.52) * (1 - layer * 0.18)
		var y := -height * (0.34 + layer * 0.18)
		var polygon := PackedVector2Array([pos + Vector2(-width, y), pos + Vector2(-width, y - 10), pos + Vector2(-width * 0.7, y - 10), pos + Vector2(-width * 0.7, y - 25), pos + Vector2(0, y - height * 0.32), pos + Vector2(width * 0.7, y - 25), pos + Vector2(width * 0.7, y - 10), pos + Vector2(width, y - 10), pos + Vector2(width, y)])
		canvas.draw_colored_polygon(polygon, Color("368646").lightened(layer * 0.08) * tint)

static func ship(canvas: CanvasItem, base: Vector2) -> void:
	var p := base + Vector2(-108, -116)
	canvas.draw_rect(Rect2(p + Vector2(18, 30), Vector2(153, 65)), Color("455d68"))
	canvas.draw_rect(Rect2(p + Vector2(22, 24), Vector2(125, 62)), Color("bbc5b6"))
	canvas.draw_rect(Rect2(p + Vector2(29, 29), Vector2(45, 53)), Color("829595"))
	for y in [32, 49, 66]:
		canvas.draw_rect(Rect2(p + Vector2(20, y), Vector2(58, 4)), Color("536b73"))
	canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(140, 24), p + Vector2(187, 61), p + Vector2(187, 87), p + Vector2(137, 87)]), Color("9eaeaa"))
	canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(145, 32), p + Vector2(177, 58), p + Vector2(144, 58)]), Color("4195b7"))
	canvas.draw_rect(Rect2(p + Vector2(124, 68), Vector2(65, 17)), Color("eda739"))
	canvas.draw_rect(Rect2(p + Vector2(130, 72), Vector2(56, 5)), Color("ffcc60"))
	canvas.draw_circle(p + Vector2(105, 51), 14, Color("536d78"))
	canvas.draw_circle(p + Vector2(105, 51), 10, Color("64b1c8"))
	canvas.draw_circle(p + Vector2(102, 48), 4, Color("98d3d7"))
	for y in [4, 79]:
		canvas.draw_rect(Rect2(p + Vector2(5, y), Vector2(43, 25)), Color("8caaa9"))
		canvas.draw_rect(Rect2(p + Vector2(-5, y - 5), Vector2(13, 34)), Color("49676e"))
		canvas.draw_rect(Rect2(p + Vector2(13, y + 4), Vector2(27, 16)), Color("5c7b82"))
	canvas.draw_rect(Rect2(p + Vector2(139, 89), Vector2(8, 27)), Color("bcc2a6"))
	canvas.draw_rect(Rect2(p + Vector2(128, 111), Vector2(30, 5)), Color("586969"))
	canvas.draw_rect(Rect2(p + Vector2(145, 0), Vector2(3, 24)), Color("9cbab8"))
	for x in [82, 115]:
		for y in [32, 78]:
			canvas.draw_rect(Rect2(p + Vector2(x, y), Vector2(3, 3)), Color("e5e7c9"))

static func planet(canvas: CanvasItem, pos: Vector2, radius: float, color: Color, rings: bool) -> void:
	if rings:
		canvas.draw_arc(pos, radius * 1.4, -0.35, 2.9, 48, color.darkened(0.35), 9)
	canvas.draw_circle(pos, radius, color.darkened(0.16))
	canvas.draw_circle(pos + Vector2(-radius * 0.16, -radius * 0.17), radius * 0.8, color)
	for i in 6:
		var point := Vector2.from_angle(i * 2.4) * radius * (0.35 + 0.08 * (i % 3))
		canvas.draw_circle(pos + point, radius * (0.1 + 0.05 * (i % 2)), color.darkened(0.2))
	if rings:
		canvas.draw_arc(pos, radius * 1.4, 2.9, 5.93, 48, color.lightened(0.12), 8)
