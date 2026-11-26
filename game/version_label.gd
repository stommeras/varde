class_name VersionLabel
extends Label
## The game's version in small text in the bottom-right corner, so a bug report can name the build.
## Only release builds have a version, since the release workflow writes it from the tag. A local
## build hides the label.

## Pixels of dark outline around the letters, so the version reads over bright ground.
const OUTLINE: int = 4
## Pixels between the label and the screen's edges.
const MARGIN: int = 8


func _init() -> void:
	text = ProjectSettings.get_setting("application/config/version", "")
	visible = text != ""
	add_theme_font_size_override("font_size", 12)
	add_theme_color_override("font_color", Ramps.RAMPS[Ramps.Terrain.SNOW][3])
	add_theme_color_override("font_outline_color", Ramps.RAMPS[Ramps.Terrain.WATER][0])
	add_theme_constant_override("outline_size", OUTLINE)
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
