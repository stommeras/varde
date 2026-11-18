class_name Sun
extends DirectionalLight3D
## The sun, a directional light that casts shadows across the terrain. It crosses the sky from east
## to west in a half circle over the south.

## The sun's height above the southern horizon at noon. Raising it shortens the midday shadows. 45° is
## about midsummer in southern Norway.
const NOON_ELEVATION: float = deg_to_rad(45.0)
## Degrees along the path where the sun stands until the day cycle in milestone 6 moves it. 120° is
## mid-afternoon, with the sun in the south-west and the slopes that face the camera lit.
const START_ANGLE: float = 120.0


func _init() -> void:
	shadow_enabled = true
	# One shadow map over the whole view. The camera is orthographic and its depth range is short, so
	# the splits of the default mode would only spend the map's resolution on bands of the same size.
	directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	# How far, in shadow map texels, the shadow test moves each point out along its normal before it
	# reads the map. At the default of 2, the web build's Compatibility renderer drew dark polygons of
	# shadow acne on sunlit slopes and along crests, and at 3 a few remained. At 8 the figure's shadow
	# comes loose from its feet. Forward+ draws the frames checked the same at 2 and 5.
	shadow_normal_bias = 5.0
	set_angle(START_ANGLE)


## Puts the sun at degrees along its path, from the eastern horizon at 0 through south at 90 to the
## western horizon at 180.
func set_angle(degrees: float) -> void:
	basis = Basis.looking_at(-direction(deg_to_rad(degrees)))


## The unit vector from the ground toward the sun at angle radians along its path. The path is a
## half circle from east (+x) over the south (+z), tilted so it peaks at NOON_ELEVATION.
static func direction(angle: float) -> Vector3:
	return Vector3(cos(angle), sin(angle) * sin(NOON_ELEVATION), sin(angle) * cos(NOON_ELEVATION))
