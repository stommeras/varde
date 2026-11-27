class_name MouseWheel
extends Control
## A mouse drawn in pixels like a KeyCap, with its scroll wheel in the coat's red, for the zoom row in
## the pause menu.

## Pixels across the mouse. Raising it makes the mouse wider.
const WIDTH: int = 14
## Pixels down the mouse, the same as a KeyCap, so the mouse lines up with the keys beside it.
const HEIGHT: int = KeyCap.FACE + KeyCap.DEPTH + 2
## Pixels from the top to the line between the two buttons. Raising it makes the buttons longer.
const BUTTONS: int = 8


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var rock: PackedColorArray = Ramps.RAMPS[Ramps.Terrain.ROCK]
	# Three overlapping rectangles cut two pixels off each corner, rounder than a key.
	for inset: int in [0, 1, 2]:
		var round_by: int = 2 - inset
		draw_rect(Rect2(inset, round_by, WIDTH - inset * 2, HEIGHT - round_by * 2), rock[0])
	draw_rect(Rect2(2, 1, WIDTH - 4, HEIGHT - 2), rock[4])
	draw_rect(Rect2(1, 2, WIDTH - 2, HEIGHT - 4), rock[4])
	draw_rect(Rect2(1, BUTTONS, WIDTH - 2, 1), rock[0])
	var middle: int = WIDTH / 2
	draw_rect(Rect2(middle - 1, 1, 2, 1), rock[0])
	draw_rect(Rect2(middle - 2, 2, 4, BUTTONS - 1), rock[0])
	draw_rect(Rect2(middle - 1, 3, 2, BUTTONS - 3), Ramps.FIGURE[Ramps.FigurePart.COAT][1])
