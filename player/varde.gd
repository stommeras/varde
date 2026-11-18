class_name Varde
extends Node3D
## A varde the player stacks on a surveyed peak: layers of flat, rough stones that taper upward,
## about as tall as the figure, lit in Ramps.FIGURE's stone ramp like the figure. It stands on the
## node's position and starts with no stones showing until build() lays them.

## Stones in each layer, bottom first. The lower layers hold several stones side by side, so the
## stack reads as stones and not as one block. Adding layers makes it taller.
const LAYERS: Array[int] = [3, 3, 2, 2, 1, 1]
## Radius of the stones in the bottom layer and in the top one, in world units. Lowering the top
## narrows the cairn's point, raising the bottom gives it a wider foot.
const BOTTOM_RADIUS: float = 0.3
const TOP_RADIUS: float = 0.16
## A stone's height against its width. Each stone is a flattened sphere, so its top takes the sun and
## its underside falls into shade, which draws a dark seam above the stone below. Raising it makes
## rounder stones and a taller stack.
const FLATNESS: float = 0.55
## Share of the stones' height by which a layer sinks into the one below, so they rest on each other
## instead of balancing on a point.
const NESTLE: float = 0.15
## Share of a stone's size and place that varies, so the stack looks laid by hand. Raising it makes
## the stack more crooked.
const WOBBLE: float = 0.2

var _stones: Array[MeshInstance3D] = []


## Builds the stones, shaped by stack_seed, so the same peak always gets the same varde.
func _init(stack_seed: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = stack_seed
	# One material for every stone, since they all draw the same ramp.
	var material: ShaderMaterial = Figure.lit(Ramps.FigurePart.STONE)
	var y: float = 0.0
	for layer: int in LAYERS.size():
		var count: int = LAYERS[layer]
		var radius: float = lerpf(BOTTOM_RADIUS, TOP_RADIUS, float(layer) / (LAYERS.size() - 1))
		var height: float = radius * 2.0 * FLATNESS
		# Stones side by side sit one radius from the middle, so neighbors just touch.
		var spread: float = 0.0 if count == 1 else radius
		var turn: float = rng.randf() * TAU
		for i: int in count:
			var angle: float = turn + TAU * i / count
			var size: float = radius * (1.0 + rng.randf_range(-WOBBLE, WOBBLE))
			var stone := MeshInstance3D.new()
			stone.mesh = _stone_mesh(size)
			stone.material_override = material
			stone.scale = Vector3(1.0, FLATNESS, rng.randf_range(0.75, 1.0))
			var offset := Vector2.from_angle(angle) * spread + Vector2(rng.randf_range(-WOBBLE, WOBBLE), rng.randf_range(-WOBBLE, WOBBLE)) * radius * 0.5
			stone.position = Vector3(offset.x, y + height / 2.0, offset.y)
			stone.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
			stone.visible = false
			add_child(stone)
			_stones.append(stone)
		y += height * (1.0 - NESTLE)


## Shows the share amount, from 0 to 1, of the stones, bottom first.
func build(amount: float) -> void:
	for i: int in _stones.size():
		_stones[i].visible = i < roundi(amount * _stones.size())


# Few segments, so the flat faces catch the light at different steps and the stone looks rough.
static func _stone_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 7
	mesh.rings = 4
	return mesh
