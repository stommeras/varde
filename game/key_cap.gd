class_name KeyCap
extends Control
## One keyboard key drawn in pixels: a light face with the key's letter, raised over a darker side
## with a dark outline and cut corners, all from the rock ramp. The arrow keys show a drawn arrow,
## since the pixel font has no arrow glyphs.

## Pixels across and down the face of a one-letter key. Raising it makes every key bigger.
const FACE: int = 16
## Pixels of side showing under the face. Raising it makes the keys look taller.
const DEPTH: int = 3
## Pixels of face on each side of a longer label, such as "Esc".
const PADDING: int = 4
## Half the width of a drawn arrow's head, in pixels.
const ARROW: int = 4

## The arrow keys and the direction each one's arrow points.
const ARROWS: Dictionary[Key, Vector2] = {
	KEY_UP: Vector2.UP,
	KEY_DOWN: Vector2.DOWN,
	KEY_LEFT: Vector2.LEFT,
	KEY_RIGHT: Vector2.RIGHT,
}

var _key: Key


func _init(key: Key) -> void:
	_key = key


## The label printed on the key, empty for an arrow key.
func label() -> String:
	if ARROWS.has(_key):
		return ""
	match _key:
		KEY_PLUS:
			return "+"
		KEY_MINUS:
			return "-"
		KEY_ESCAPE:
			return tr("KEY_ESCAPE")
	return OS.get_keycode_string(_key)


func _get_minimum_size() -> Vector2:
	var text_width: float = get_theme_default_font().get_string_size(label()).x
	return Vector2(maxf(FACE, ceilf(text_width) + PADDING * 2) + 2, FACE + DEPTH + 2)


func _draw() -> void:
	var rock: PackedColorArray = Ramps.RAMPS[Ramps.Terrain.ROCK]
	var w: float = size.x
	var h: float = size.y
	# Two overlapping rectangles leave the four corner pixels empty, which reads as a rounded key.
	draw_rect(Rect2(1, 0, w - 2, h), rock[0])
	draw_rect(Rect2(0, 1, w, h - 2), rock[0])
	draw_rect(Rect2(1, 1, w - 2, h - 2), rock[2])
	var face := Rect2(1, 1, w - 2, FACE)
	draw_rect(face, rock[4])
	var center: Vector2 = face.get_center()
	if ARROWS.has(_key):
		var forward: Vector2 = ARROWS[_key]
		var across := Vector2(forward.y, forward.x)
		var tip: Vector2 = (center + forward * ARROW).round()
		var base: Vector2 = (center - forward * ARROW).round()
		draw_colored_polygon(PackedVector2Array([tip, base + across * ARROW, base - across * ARROW]), rock[0])
		return
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_default_font_size()
	var text: String = label()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := Vector2(center.x - text_size.x / 2.0, center.y - text_size.y / 2.0 + font.get_ascent(font_size))
	draw_string(font, baseline.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, rock[0])
