class_name Prompt
extends CanvasLayer
## A key prompt at the bottom of the screen, such as "[F] Kartlegg toppen", in snow-white text with a
## dark outline, so it shows over snow and rock. It starts hidden and fades in and out.

## Seconds the prompt takes to fade in or out.
const FADE_SECONDS: float = 0.2

var _label := Label.new()


## key is the translation key of the prompt's text.
func _init(key: String) -> void:
	_label.text = tr(key)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.position.y -= 24
	_label.add_theme_color_override("font_color", Ramps.RAMPS[Ramps.Terrain.SNOW][3])
	_label.add_theme_color_override("font_outline_color", Ramps.RAMPS[Ramps.Terrain.ROCK][0])
	_label.add_theme_constant_override("outline_size", 4)
	_label.modulate.a = 0.0
	add_child(_label)


## Fades the prompt toward showing if wanted is true, or toward hidden, by one frame of delta seconds.
func fade(wanted: bool, delta: float) -> void:
	_label.modulate.a = move_toward(_label.modulate.a, 1.0 if wanted else 0.0, delta / FADE_SECONDS)
