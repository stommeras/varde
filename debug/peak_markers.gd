class_name PeakMarkers
extends Node2D
## Marks each peak of the debug view's island with a dot and its prominence, as a share of the
## summit's height. Draws in screen-sized marks whatever the zoom, so the numbers stay readable
## when the whole island fits on screen.

## Size of a dot and of the numbers in screen pixels.
const DOT_RADIUS: float = 4.0
const FONT_SIZE: int = 16

var _peaks: Array[Peak] = []
var _pixels_per_cell: float = 1.0
var _zoom: float = 1.0


## Shows peaks on a map drawn at pixels_per_cell.
func show_peaks(peaks: Array[Peak], pixels_per_cell: float) -> void:
	_peaks = peaks
	_pixels_per_cell = pixels_per_cell
	queue_redraw()


## Redraws for a camera at zoom.
func set_zoom(zoom: float) -> void:
	_zoom = zoom
	queue_redraw()


func _draw() -> void:
	# The project theme's font, since ThemeDB.fallback_font stays Godot's Open Sans.
	var font: Font = ThemeDB.get_project_theme().default_font
	var fill: Color = Ramps.base(Ramps.Terrain.SNOW)
	var outline: Color = Ramps.RAMPS[Ramps.Terrain.ROCK][0]
	var unit: float = 1.0 / _zoom
	for peak: Peak in _peaks:
		var at := Vector2(peak.cell % IslandData.SIZE + 0.5, peak.cell / IslandData.SIZE + 0.5) * _pixels_per_cell
		draw_circle(at, (DOT_RADIUS + 1.0) * unit, outline)
		draw_circle(at, DOT_RADIUS * unit, fill)
		draw_set_transform(at + Vector2(DOT_RADIUS + 3.0, 4.0) * unit, 0.0, Vector2.ONE * unit)
		var text: String = "%.2f" % peak.prominence
		draw_string_outline(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, outline)
		draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, fill)
		draw_set_transform(Vector2.ZERO)
