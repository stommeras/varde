extends "res://tests/test_case.gd"


func test_same_seed_gives_same_clouds() -> void:
	expect(IslandGenerator.generate(1).cloud_base == island(1).cloud_base, "seed 1 gave a different cloud layer the second time")


## About half the islands have a layer, with at least two contenders sticking through it.
func test_layer_lets_two_tops_through() -> void:
	var layers: int = 0
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		if data.cloud_base > 1.0:
			continue
		layers += 1
		var through: int = 0
		for top: int in data.contenders:
			if data.height[top] >= Clouds.top(data) + Clouds.PEEK - 0.0001:
				through += 1
		expect(through >= 2, "seed %d: only %d contenders stick through the layer" % [island_seed, through])
	expect(layers >= SEEDS * 0.2 and layers <= SEEDS * 0.8, "%d of %d islands have a layer" % [layers, SEEDS])


## The layer hides the land over its base from under it, and the land under its top from over it.
func test_layer_hides_the_other_side() -> void:
	var data := IslandData.new()
	data.height.resize(3)
	data.height[0] = 0.5
	data.height[1] = 0.92
	data.height[2] = 0.99
	data.cloud_base = 0.9
	expect(Clouds.clear_of(data, 0, PackedInt32Array([0, 1, 2])) == PackedInt32Array([0]), "from under the layer, the land over it shows")
	expect(Clouds.clear_of(data, 2, PackedInt32Array([0, 1, 2])) == PackedInt32Array([2]), "from over the layer, the land under it shows")
	expect(Clouds.inside(data, 1) and not Clouds.inside(data, 0) and not Clouds.inside(data, 2), "the layer's inside is off")
