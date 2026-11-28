class_name OldVarde
extends Node3D
## An old varde on the way up a mountain: a lumpy, barely tapering stack of rough stones of
## uneven size, some grey with lichen and some overgrown with moss. It differs from the player's
## varde, a neat cone of clean grey stones. A fallen one keeps a stump of a few layers with its other
## stones strewn on the ground to one side. A hidden one stands in forest, shorter and almost all
## moss. It stands on the node's position and doesn't block walking.

## How much larger the summit's varde stands than the old vardes up the way, so the player knows it
## up close as the end of the line. Raising it makes the summit varde taller and broader.
const SUMMIT_SCALE: float = 1.6
## Stone layers of a standing varde. Raising it makes a taller stack.
const LAYERS: int = 7
## Layers left of a fallen varde's stump. Raising it leaves a taller stump and strews fewer stones.
const FALLEN_LAYERS: int = 2
## Layers of a hidden varde. Lowering it sinks the varde further into the forest floor's shrubs.
const HIDDEN_LAYERS: int = 4
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
## Share of a layer's height by which the layer above sinks into it, so the stones rest in the gaps
## below. Raising it makes a lower, tighter stack.
const NESTLE: float = 0.33
## Share of a stone's size and place that varies. Uneven stones and gaps make the stack look old and
## settled. Raising it makes it more crooked.
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

## The strewn stones of a fallen varde, which place() lays on the ground.
var _strewn: Array[MeshInstance3D] = []


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
		# A standing varde ends in a single capstone.
		var count: int = 1 if kind == Trail.Kind.STANDING and layer == LAYERS - 1 else PER_LAYER
		var turn: float = rng.randf() * TAU
		for i: int in count:
			var spread: float = 0.0 if count == 1 else radius * 1.1
			var at := Vector2.from_angle(turn + TAU * i / count) * spread
			_stone(stack, radius, Vector3(at.x, y + radius * FLATNESS, at.y), kind, lichen, moss, rng)
		y += radius * 2.0 * FLATNESS * (1.0 - NESTLE)
	if kind == Trail.Kind.FALLEN:
		var toward: float = rng.randf() * TAU
		# The stones of the fallen layers, the capstone among them.
		for i: int in (LAYERS - FALLEN_LAYERS - 1) * PER_LAYER + 1:
			var at := Vector2.from_angle(toward + rng.randf_range(-FALL_SPREAD, FALL_SPREAD)) * rng.randf_range(FALL_NEAREST, FALL_REACH)
			# Centered on the ground, so they lie half sunk, as stones long fallen.
			_strewn.append(_stone(self, TOP_RADIUS, Vector3(at.x, 0.0, at.y), kind, lichen, moss, rng))


## Stands the varde on island's ground at the middle of cell, and lays each strewn stone of a fallen
## one on the ground where it lies. At the stump's height, the stones downhill floated on a steep slope.
func place(island: IslandData, cell: int) -> void:
	var at: Vector2 = IslandData.center(cell)
	position = Vector3(at.x, Player.height_at(island, at), at.y)
	for stone: MeshInstance3D in _strewn:
		stone.position.y = Player.height_at(island, at + Vector2(stone.position.x, stone.position.z)) - position.y


func _stone(parent: Node3D, radius: float, at: Vector3, kind: Trail.Kind, lichen: ShaderMaterial, moss: ShaderMaterial, rng: RandomNumberGenerator) -> MeshInstance3D:
	var stone := MeshInstance3D.new()
	stone.mesh = Varde.stone_mesh(radius * (1.0 + rng.randf_range(-WOBBLE, WOBBLE)))
	stone.material_override = moss if rng.randf() < MOSSY[kind] else lichen
	stone.scale = Vector3(rng.randf_range(0.8, 1.3), FLATNESS * rng.randf_range(0.8, 1.2), rng.randf_range(0.7, 1.1))
	stone.position = at + Vector3(rng.randf_range(-WOBBLE, WOBBLE), 0.0, rng.randf_range(-WOBBLE, WOBBLE)) * radius * 0.5
	stone.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
	parent.add_child(stone)
	return stone
