class_name ZoneRing
extends Node3D
## A thin ring that floats over the edge of a peak's survey zone, so the player can find the top. It
## bobs and pulses, which marks it as a sign rather than a thing standing on the island.

const SHADER: Shader = preload("res://player/zone_ring.gdshader")
## World units from the middle of the tube to its surface. At zoom 40 a pixel is 0.052 units, so
## 0.1 draws a tube about 4 pixels thick, light in the middle and dark at the edges. At 0.08 the ring
## was a pixel or two and broke up. Raising it thickens the ring.
const TUBE: float = 0.1
## World units the ring floats above the highest ground along its edge, so no part of the slope under
## it hides the front of the ring. Floating over the average height, the front sank into the slope
## on uneven peaks. Raising it lifts the ring further off the ground.
const LIFT: float = 0.4
## World units the ring bobs up and down from where it floats.
const BOB: float = 0.15
## Seconds per bob and per pulse. Lowering it makes the ring busier.
const PERIOD: float = 2.0
## Points along the zone's edge whose highest ground sets the ring's height. Raising it catches
## narrower ridges under the ring.
const SAMPLES: int = 32

## Seconds since the ring was made, which drives the bob and the pulse.
var _time: float = 0.0
## Height the ring floats at, before the bob.
var _height: float = 0.0
## How much of the ring shows, from 0 to 1. The pulse dims the ring's middle instead of dropping
## pixels, because a ring with half its pixels gone looked broken.
var _amount: float = 0.0
var _mesh := MeshInstance3D.new()
var _material := ShaderMaterial.new()


func _init() -> void:
	_material.shader = SHADER
	_material.set_shader_parameter("rim", Ramps.RAMPS[Ramps.Terrain.ROCK][0])
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	visible = false


## Puts the ring radius cells around the top of cell on island, LIFT above the highest ground along
## its edge. A gold ring marks the true summit, a white one any other peak.
func place(island: IslandData, cell: int, radius: float, gold: bool = false) -> void:
	_material.set_shader_parameter("core", Ramps.GOLD[2] if gold else Ramps.RAMPS[Ramps.Terrain.SNOW][3])
	_material.set_shader_parameter("core_dim", Ramps.GOLD[1] if gold else Ramps.RAMPS[Ramps.Terrain.SNOW][1])
	var top := Vector2(cell % IslandData.SIZE + 0.5, cell / IslandData.SIZE + 0.5)
	var highest: float = -INF
	for i: int in SAMPLES:
		highest = maxf(highest, Player.height_at(island, top + Vector2.from_angle(TAU * i / SAMPLES) * radius))
	_height = highest + LIFT
	position = Vector3(top.x, _height, top.y)
	var torus := TorusMesh.new()
	torus.inner_radius = radius - TUBE
	torus.outer_radius = radius + TUBE
	torus.rings = 64
	torus.ring_segments = 8
	_mesh.mesh = torus


## Shows amount of the ring, from 0, hidden, to 1.
func fade(amount: float) -> void:
	_amount = amount
	visible = amount > 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	var wave: float = sin(TAU * _time / PERIOD)
	position.y = _height + BOB * wave
	_material.set_shader_parameter("amount", _amount)
	_material.set_shader_parameter("glow", 0.5 + 0.5 * wave)
