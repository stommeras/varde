class_name OldVarde
extends Node3D
## An old varde on the trail to the summit: a straight tower of flat slabs, laid crosswise in pairs,
## taller than the figure and lit in Ramps.FIGURE's lichen ramp. It differs from the player's varde,
## a tapering cone of round grey stones. A fallen one keeps a stump of a few layers with its other
## slabs strewn on the ground to one side. A hidden one stands in forest, shorter and overgrown, in
## the moss ramp. It stands on the node's position and doesn't block walking.

## Slab layers of a standing varde. Raising it makes a taller tower.
const LAYERS: int = 10
## Layers left of a fallen varde's stump. Raising it leaves a taller stump and strews fewer slabs.
const FALLEN_LAYERS: int = 3
## Layers of a hidden varde. Lowering it sinks the varde further into the forest floor's shrubs.
const HIDDEN_LAYERS: int = 6
## Layers by Trail.Kind.
const KIND_LAYERS: Dictionary[Trail.Kind, int] = {Trail.Kind.STANDING: LAYERS, Trail.Kind.FALLEN: FALLEN_LAYERS, Trail.Kind.HIDDEN: HIDDEN_LAYERS}
## Size of one slab in world units: long, thick and deep. Two lie side by side in each layer, so the
## tower is about SLAB.x wide. At 10 layers of 0.17 it stands 1.7 units, over the figure's 1.5.
const SLAB := Vector3(0.62, 0.17, 0.3)
## Share of a slab's size and place that varies, so the tower looks laid by hand. Edges that jut
## out past the slab below cast a dark seam under them, which is what shows the layers. At 0.15 the
## faces lined up and the tower read as one block. Raising it makes the tower more crooked.
const WOBBLE: float = 0.3
## World units from a fallen varde's middle to its nearest and furthest strewn slab, on the side it
## fell. Raising FALL_REACH spreads the slabs further.
const FALL_NEAREST: float = 0.5
const FALL_REACH: float = 1.6
## Radians to each side of the fall's direction that the strewn slabs spread. Raising it turns the
## fan into a ring around the stump, which reads as a varde taken apart, not one that fell.
const FALL_SPREAD: float = 0.6
## Radians a strewn slab tips at most, as it lies on rough ground.
const FALL_TILT: float = 0.3


## Builds an old varde of kind, a Trail.Kind, shaped by varde_seed, so the same varde always looks
## the same.
func _init(kind: Trail.Kind = Trail.Kind.STANDING, varde_seed: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = varde_seed
	var material: ShaderMaterial = Figure.lit(Ramps.FigurePart.MOSS if kind == Trail.Kind.HIDDEN else Ramps.FigurePart.LICHEN)
	var layers: int = KIND_LAYERS[kind]
	var turn: float = rng.randf() * TAU
	for layer: int in layers:
		# Each layer crosses the one below, so the joints don't line up and the slabs lock together.
		var angle: float = turn + layer * PI / 2.0 + rng.randf_range(-WOBBLE, WOBBLE)
		for side: float in [-0.5, 0.5]:
			var across := Vector2.from_angle(angle + PI / 2.0) * side * SLAB.z
			_slab(material, Vector3(across.x, (layer + 0.5) * SLAB.y, across.y), Vector3(0.0, -angle, 0.0), rng)
	if kind == Trail.Kind.FALLEN:
		var toward: float = rng.randf() * TAU
		for slab: int in (LAYERS - FALLEN_LAYERS) * 2:
			var at := Vector2.from_angle(toward + rng.randf_range(-FALL_SPREAD, FALL_SPREAD)) * rng.randf_range(FALL_NEAREST, FALL_REACH)
			# Its middle a third of a slab up, so a tipped slab sinks into the ground instead of floating.
			_slab(material, Vector3(at.x, SLAB.y * 0.3, at.y), Vector3(rng.randf_range(-FALL_TILT, FALL_TILT), rng.randf() * TAU, rng.randf_range(-FALL_TILT, FALL_TILT)), rng)


## Stands the varde on island's ground at the middle of cell.
func place(island: IslandData, cell: int) -> void:
	var at: Vector2 = IslandData.center(cell)
	position = Vector3(at.x, Player.height_at(island, at), at.y)


func _slab(material: ShaderMaterial, at: Vector3, turn: Vector3, rng: RandomNumberGenerator) -> void:
	var mesh := BoxMesh.new()
	mesh.size = SLAB * Vector3(1.0 + rng.randf_range(-WOBBLE, WOBBLE), 1.0 + rng.randf_range(-WOBBLE, WOBBLE), 1.0)
	var slab := MeshInstance3D.new()
	slab.mesh = mesh
	slab.material_override = material
	slab.position = at + Vector3(rng.randf_range(-WOBBLE, WOBBLE), 0.0, rng.randf_range(-WOBBLE, WOBBLE)) * SLAB.z * 0.5
	slab.rotation = turn + Vector3(0.0, rng.randf_range(-WOBBLE, WOBBLE), 0.0)
	add_child(slab)
