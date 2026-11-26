class_name Wreck
extends Node3D
## The shipwreck on the landing beach, an old boat driven ashore bow first and heeled over on the
## sand. Code builds it from boxes and cylinders, lit in Ramps.FIGURE's wood ramp by the figure's
## shader, like the vardes. Its stern lies at the waterline and the planking has gone from it, so
## the ribs show. The node's -z is the bow.

## Length of the hull in world units, from stern to the tip of the bow. The figure is 1.5 tall, so
## at 4 the boat reads as a boat beside it and fits between the shore and the start.
const LENGTH: float = 4.0
## Width of the hull at its middle in world units. Raising it makes a broader boat.
const BEAM: float = 1.5
## Height of the hull's sides in world units. Raising it makes a deeper boat that hides more of the
## figure behind it.
const DEPTH: float = 0.8
## Share of LENGTH that keeps its planking, from the bow back. Lowering it shows more bare ribs.
const PLANKED: float = 0.6
## Radians the hull leans onto its side. At 0 it sits upright as if afloat, and past 0.5 it shows
## mostly its bottom.
const HEEL: float = 0.3
## World units the keel sinks into the sand, so the hull looks bedded in and not set on top.
const SINK: float = 0.25
## Ribs that stand bare at the stern where the planking has gone. Each pair stands a little further
## back than the one before.
const RIBS: int = 3


## Builds the boat at the node's origin.
func _init() -> void:
	# The other sizes and angles below are shape proportions picked by eye from frames at zoom 40.
	var material: ShaderMaterial = Figure.lit(Ramps.FigurePart.WOOD)
	var hull := Node3D.new()
	hull.rotation.z = HEEL
	hull.position.y = -SINK
	add_child(hull)
	var planked: float = LENGTH * PLANKED
	# The bottom and both sides run from the bow's root back to where the planking ends.
	_part(hull, _box(Vector3(BEAM * 0.8, 0.2, planked)), Vector3(0.0, 0.1, 0.0), Vector3.ZERO, material)
	for side: float in [-1.0, 1.0]:
		# Each side flares outward from the bottom.
		_part(hull, _box(Vector3(0.12, DEPTH, planked)), Vector3(side * BEAM * 0.45, DEPTH / 2.0, 0.0), Vector3(0.0, 0.0, -side * 0.25), material)
	# The bow, a box turned on its corner so its edge points forward, closes the front.
	var bow: float = BEAM * 0.55
	_part(hull, _box(Vector3(bow, DEPTH, bow)), Vector3(0.0, DEPTH / 2.0, -planked / 2.0), Vector3(0.0, PI / 4.0, 0.0), material)
	for i: int in RIBS:
		var z: float = planked / 2.0 + 0.3 + i * 0.35
		for side: float in [-1.0, 1.0]:
			# Shorter toward the stern, as if they broke off.
			var height: float = DEPTH * (1.0 - i * 0.2)
			_part(hull, _box(Vector3(0.1, height, 0.1)), Vector3(side * BEAM * 0.42, height / 2.0, z), Vector3(0.0, 0.0, -side * 0.3), material)
	# The keel runs on past the ribs to the stern post.
	_part(hull, _box(Vector3(0.15, 0.15, LENGTH * 0.4)), Vector3(0.0, 0.08, planked / 2.0 + LENGTH * 0.2), Vector3.ZERO, material)
	var mast := CylinderMesh.new()
	mast.top_radius = 0.06
	mast.bottom_radius = 0.09
	mast.height = 1.4
	mast.radial_segments = 6
	# Short and leaning back, so it reads as a broken mast and not one that still carries a sail.
	_part(hull, mast, Vector3(0.0, 0.8, -0.4), Vector3(0.5, 0.0, 0.0), material)


## Lays the wreck on island at cell, with its bow toward cell toward, following the slope of the
## ground between its two ends.
func place(island: IslandData, cell: int, toward: int) -> void:
	var at: Vector2 = IslandData.center(cell)
	var forward: Vector2 = (IslandData.center(toward) - at).normalized()
	var bow: float = Player.height_at(island, at + forward * LENGTH / 2.0)
	var stern: float = Player.height_at(island, at - forward * LENGTH / 2.0)
	position = Vector3(at.x, (bow + stern) / 2.0, at.y)
	# -z points along forward, and the hull pitches up the beach with the ground.
	rotation = Vector3(atan2(bow - stern, LENGTH), atan2(-forward.x, -forward.y), 0.0)


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _part(parent: Node3D, mesh: Mesh, at: Vector3, turn: Vector3, material: ShaderMaterial) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation = turn
	parent.add_child(part)
