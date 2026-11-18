class_name Figure
extends Node3D
## The figure the player sees walking, built from spheres, capsules and boxes and drawn by
## figure.gdshader in the colors of Ramps.FIGURE. Legs swing from the hips and bend at the knees, and
## arms swing from the shoulders and bend at the elbows. Its feet stand on the node's position, and it
## faces -z until face() turns it.

const SHADER: Shader = preload("res://player/figure.gdshader")
## The color of the parts terrain hides, the lightest step of a ramp in Ramps.FIGURE.
const SILHOUETTE: Ramps.FigurePart = Ramps.FigurePart.COAT
## World units from the soles to the crown of the head, with the beanie a little above. Every part is
## sized in units of it, so raising it scales the whole figure. At zoom 40, where one screen pixel is
## 0.052 units and the camera looks down at 45°, it draws the figure about 25 pixels tall and 12 wide.
const HEIGHT: float = 1.5
## Cells walked per full walk cycle, a step with each foot. Raising it slows the legs against the
## ground. At 3.5 cells per second, 2.4 gives about 3 steps a second. Legs that kept pace with the
## ground would need 7, and at 2 cells the steps looked fast and mechanical.
const CELLS_PER_CYCLE: float = 2.4
## World units the body drops at each footfall, when the legs are furthest apart, and rises from as
## they pass. Raising it makes the walk heavier and bouncier. At zoom 40 a pixel is 0.052 units, so
## 0.1 is a dip of about 2 pixels.
const BOB: float = 0.1
## Radians the body leans forward from the feet at full walking speed. Raising it makes the figure
## push harder into its walk.
const LEAN: float = 0.12
## How far the legs swing forward and back from the hips, in radians. Raising it lengthens the stride.
const LEG_SWING: float = 0.55
## How far a knee bends as its leg swings forward, in radians.
const KNEE_BEND: float = 0.9
## How far the arms swing from the shoulders, against the legs, in radians.
const ARM_SWING: float = 0.6
## How far the elbows bend, in radians, standing and at the front of the swing.
const ELBOW_BEND: float = 0.25

var _hips: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
## Turns with the walking direction. The feet stand on its origin.
var _body := Node3D.new()
## Which way the figure faces, before the lean.
var _facing := Basis.IDENTITY
## Radians the body leans forward now.
var _lean: float = 0.0

## The ramps as a texture, one row per Ramps.FigurePart, built once for every figure.
static var _ramps: ImageTexture
## The silhouette pass every part shares, built once.
static var _silhouette: ShaderMaterial


func _init() -> void:
	add_child(_body)
	var u: float = HEIGHT
	var hip_y: float = 0.34 * u
	var leg: float = 0.16 * u
	# Torso and pack. The torso is flattened front to back, so the side view is slimmer than the front.
	var torso := _part(_capsule(0.13 * u, 0.36 * u), Ramps.FigurePart.COAT, _body, Vector3(0, 0.5 * u, 0))
	torso.scale = Vector3(1.0, 1.0, 0.75)
	_part(_box(Vector3(0.22, 0.24, 0.12) * u), Ramps.FigurePart.PACK, _body, Vector3(0, 0.52 * u, 0.13 * u))
	# The camera looks down at 45°, so it sees the top of the head more than the face. The cap is a
	# sphere a little higher and further back than the head, which shows only as a beanie on the crown
	# and leaves the face clear. A hemisphere over the whole crown hid the face down to the eyes.
	var head := _part(_sphere(0.15 * u), Ramps.FigurePart.SKIN, _body, Vector3(0, 0.83 * u, 0))
	(head.material_override as ShaderMaterial).set_shader_parameter("face", true)
	_part(_sphere(0.155 * u), Ramps.FigurePart.COAT, head, Vector3(0, 0.07 * u, 0.035 * u))
	for side: float in [-1.0, 1.0]:
		# Legs, each a thigh and a shin with a boot, hanging from a hip joint and a knee joint.
		var hip := _joint(_body, Vector3(side * 0.065 * u, hip_y, 0))
		_part(_capsule(0.05 * u, leg + 0.1 * u), Ramps.FigurePart.TROUSERS, hip, Vector3(0, -leg / 2.0, 0))
		var knee := _joint(hip, Vector3(0, -leg, 0))
		_part(_capsule(0.045 * u, leg + 0.09 * u), Ramps.FigurePart.TROUSERS, knee, Vector3(0, -leg / 2.0, 0))
		_part(_box(Vector3(0.09, 0.05, 0.14) * u), Ramps.FigurePart.BOOTS, knee, Vector3(0, -leg, -0.025 * u))
		_hips.append(hip)
		_knees.append(knee)
		# Arms, each an upper arm and a forearm with a hand, from a shoulder joint and an elbow joint.
		var arm: float = 0.12 * u
		var shoulder := _joint(_body, Vector3(side * 0.17 * u, 0.62 * u, 0))
		_part(_capsule(0.04 * u, arm + 0.08 * u), Ramps.FigurePart.COAT, shoulder, Vector3(0, -arm / 2.0, 0))
		var elbow := _joint(shoulder, Vector3(0, -arm, 0))
		_part(_capsule(0.037 * u, arm + 0.07 * u), Ramps.FigurePart.COAT, elbow, Vector3(0, -arm / 2.0, 0))
		_part(_sphere(0.04 * u), Ramps.FigurePart.SKIN, elbow, Vector3(0, -arm - 0.01 * u, 0))
		_shoulders.append(shoulder)
		_elbows.append(elbow)
	walk(0.0)


## Turns the figure to face direction, x east and y south.
func face(direction: Vector2) -> void:
	_facing = Basis.looking_at(Vector3(direction.x, 0.0, direction.y))
	_turn()


## Poses the limbs for walked cells into the walk cycle at pace, the share of full walking speed.
## Limbs swing, the body bobs and leans by pace, so a figure easing to a stop settles. A walked of 0
## stands still.
func walk(walked: float, pace: float = 1.0) -> void:
	var phase: float = walked / CELLS_PER_CYCLE * TAU
	# Every pose in the cycle has a leg in the air or a knee bent, so standing still is its own pose.
	var amount: float = 0.0 if walked == 0.0 else clampf(pace, 0.0, 1.0)
	# The legs are furthest apart, and the hips lowest, at sin(phase) = ±1, once per step.
	_body.position.y = -BOB * absf(sin(phase)) * amount
	_lean = LEAN * amount
	_turn()
	for side: int in 2:
		# The two sides swing half a cycle apart, and each arm against the leg on its own side.
		var swing: float = sin(phase + side * PI) * amount
		_hips[side].rotation.x = swing * LEG_SWING
		# A knee bends while its foot swings forward, off the ground, and straightens as it lands.
		_knees[side].rotation.x = -KNEE_BEND * maxf(0.0, cos(phase + side * PI)) * amount
		_shoulders[side].rotation.x = -swing * ARM_SWING
		_elbows[side].rotation.x = ELBOW_BEND * (1.0 + maxf(0.0, -swing))


# Rotating about the body's x axis by a negative angle tips its top toward -z, its front. The feet
# stand on the origin, so the body pivots on them.
func _turn() -> void:
	_body.basis = _facing * Basis(Vector3.RIGHT, -_lean)


## A joint under parent at position, which rotates the limb parts added under it.
func _joint(parent: Node3D, at: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.position = at
	parent.add_child(joint)
	return joint


## Adds mesh under parent at position in the ramp of part.
func _part(mesh: Mesh, part: Ramps.FigurePart, parent: Node3D, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	var material: ShaderMaterial = lit(part)
	material.next_pass = silhouette()
	instance.material_override = material
	parent.add_child(instance)
	return instance


## A material that lights a mesh in the ramp of part, as the figure's parts are lit.
static func lit(part: Ramps.FigurePart) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("ramps", ramps())
	material.set_shader_parameter("steps", Ramps.FIGURE[part].size())
	material.set_shader_parameter("part", part)
	return material


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 4
	return mesh


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


## The pass that draws the parts terrain hides in one flat color.
static func silhouette() -> ShaderMaterial:
	if _silhouette == null:
		_silhouette = ShaderMaterial.new()
		_silhouette.shader = preload("res://player/silhouette.gdshader")
		_silhouette.set_shader_parameter("color", Ramps.FIGURE[SILHOUETTE][2])
	return _silhouette


## Ramps.FIGURE as a texture, one row per part with its steps from darkest on the left.
static func ramps() -> ImageTexture:
	if _ramps == null:
		_ramps = ImageTexture.create_from_image(Ramps.image(Ramps.FIGURE))
	return _ramps
