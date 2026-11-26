class_name OldVarde
extends Node3D
## An old varde on the trail to the summit: a lumpy, barely tapering stack of rough stones of
## uneven size, some grey with lichen and some overgrown with moss. It differs from the player's
## varde, a neat cone of clean grey stones. A fallen one keeps a stump of a few layers with its other
## stones strewn on the ground to one side. A hidden one stands in forest, shorter and almost all
## moss. It stands on the node's position and doesn't block walking.

## Stone layers of a standing varde. Raising it makes a taller stack.
const LAYERS: int = 7
## Layers left of a fallen varde's stump. Raising it leaves a taller stump and strews fewer stones.
const FALLEN_LAYERS: int = 2
## Layers of a hidden varde. Lowering it sinks the varde further into the forest floor's shrubs.
const HIDDEN_LAYERS: int = 4
## Layers by Trail.Kind.
const KIND_LAYERS: Dictionary[Trail.Kind, int] = {Trail.Kind.STANDING: LAYERS, Trail.Kind.FALLEN: FALLEN_LAYERS, Trail.Kind.HIDDEN: HIDDEN_LAYERS}
## Stones in each layer. Four side by side keep the stack broad, so it reads as a pile of stones and
## not as a column.
const PER_LAYER: int = 4
## Radius of the stones in the bottom layer and the top one, in world units. The top stays close to
## the bottom, so the stack stands nearly straight, unlike the player's tapering cone.
const BOTTOM_RADIUS: float = 0.3
const TOP_RADIUS: float = 0.22
## A stone's height against its width. Raising it makes rounder stones and a taller stack.
const FLATNESS: float = 0.65
## Share of a stone's size and place that varies. Uneven stones and gaps make the stack look old and
## settled. At 0.3 the stack looked too neat. Raising it makes it more crooked.
const WOBBLE: float = 0.45
## Radians the whole stack leans, as old vardes settle on soft ground.
const LEAN: float = 0.08
## Chance that a stone is mossy, by Trail.Kind. A hidden varde is almost all moss, so it sinks into
## the forest.
const MOSSY: Dictionary[Trail.Kind, float] = {Trail.Kind.STANDING: 0.5, Trail.Kind.FALLEN: 0.6, Trail.Kind.HIDDEN: 0.85}
## World units from a fallen varde's middle to its nearest and furthest strewn stone, on the side it
## fell. Raising FALL_REACH spreads the stones further.
const FALL_NEAREST: float = 0.5
const FALL_REACH: float = 1.6
## Radians to each side of the fall's direction that the strewn stones spread. Raising it turns the
## fan into a ring around the stump, which reads as a varde taken apart, not one that fell.
const FALL_SPREAD: float = 0.7


## Builds an old varde of kind, a Trail.Kind, shaped by varde_seed, so the same varde always looks
## the same.
func _init(kind: Trail.Kind = Trail.Kind.STANDING, varde_seed: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = varde_seed
	var lichen: ShaderMaterial = Figure.lit(Ramps.FigurePart.LICHEN)
	var moss: ShaderMaterial = Figure.lit(Ramps.FigurePart.MOSS)
	var stack := Node3D.new()
	stack.rotation = Vector3(rng.randf_range(-LEAN, LEAN), 0.0, rng.randf_range(-LEAN, LEAN))
	add_child(stack)
	var y: float = 0.0
	for layer: int in KIND_LAYERS[kind]:
		var radius: float = lerpf(BOTTOM_RADIUS, TOP_RADIUS, float(layer) / (LAYERS - 1))
		# The top layer of a standing varde is one capstone, so it ends in a point.
		var count: int = 1 if kind == Trail.Kind.STANDING and layer == LAYERS - 1 else PER_LAYER
		var turn: float = rng.randf() * TAU
		for i: int in count:
			var spread: float = 0.0 if count == 1 else radius * 1.1
			var at := Vector2.from_angle(turn + TAU * i / count) * spread
			_stone(stack, radius, Vector3(at.x, y + radius * FLATNESS, at.y), kind, lichen, moss, rng)
		# Layers sink into each other by a third, so the stones rest in the gaps below.
		y += radius * 2.0 * FLATNESS * 0.67
	if kind == Trail.Kind.FALLEN:
		var toward: float = rng.randf() * TAU
		for i: int in (LAYERS - FALLEN_LAYERS) * PER_LAYER - 3:
			var at := Vector2.from_angle(toward + rng.randf_range(-FALL_SPREAD, FALL_SPREAD)) * rng.randf_range(FALL_NEAREST, FALL_REACH)
			# Half sunk, as stones that have lain in the grass for years.
			_stone(self, TOP_RADIUS, Vector3(at.x, 0.0, at.y), kind, lichen, moss, rng)


## Stands the varde on island's ground at the middle of cell.
func place(island: IslandData, cell: int) -> void:
	var at: Vector2 = IslandData.center(cell)
	position = Vector3(at.x, Player.height_at(island, at), at.y)


func _stone(parent: Node3D, radius: float, at: Vector3, kind: Trail.Kind, lichen: ShaderMaterial, moss: ShaderMaterial, rng: RandomNumberGenerator) -> void:
	var stone := MeshInstance3D.new()
	stone.mesh = Varde.stone_mesh(radius * (1.0 + rng.randf_range(-WOBBLE, WOBBLE)))
	stone.material_override = moss if rng.randf() < MOSSY[kind] else lichen
	stone.scale = Vector3(rng.randf_range(0.8, 1.3), FLATNESS * rng.randf_range(0.8, 1.2), rng.randf_range(0.7, 1.1))
	stone.position = at + Vector3(rng.randf_range(-WOBBLE, WOBBLE), 0.0, rng.randf_range(-WOBBLE, WOBBLE)) * radius * 0.5
	stone.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
	parent.add_child(stone)
