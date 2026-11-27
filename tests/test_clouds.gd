extends "res://tests/test_case.gd"


func test_same_seed_gives_same_clouds() -> void:
	var again: IslandData = IslandGenerator.generate(1)
	expect(again.cloud_tops == island(1).cloud_tops and again.cloud == island(1).cloud, "seed 1 gave different clouds the second time")


## Each cloud sits on a contender and covers its top and only land near the top, and about half the
## contenders have one.
func test_clouds_cap_contenders() -> void:
	var clouded: int = 0
	var contenders: int = 0
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		contenders += data.contenders.size()
		clouded += data.cloud_tops.size()
		for i: int in data.cloud_tops.size():
			var top: int = data.cloud_tops[i]
			expect(top in data.contenders, "seed %d: a cloud stands on %d, which is no contender" % [island_seed, top])
			expect(data.cloud[top] == i + 1, "seed %d: cloud %d doesn't cover its top" % [island_seed, i])
			var cells: int = 0
			for cell: int in data.cloud.size():
				if data.cloud[cell] == i + 1:
					cells += 1
					expect(data.height[cell] >= data.height[top] - Clouds.DEPTH, "seed %d: cloud %d covers a cell far under its top" % [island_seed, i])
			expect(cells > 150, "seed %d: cloud %d covers only %d cells" % [island_seed, i, cells])
	expect(clouded >= contenders * 0.25 and clouded <= contenders * 0.75, "%d of %d contenders have a cloud" % [clouded, contenders])


## A cloud narrows the view until a survey has faded it all the way, and then for good.
func test_a_faded_cloud_no_longer_narrows_the_view() -> void:
	var data: IslandData = island(0)
	var terrain := IslandTerrain.new()
	terrain.show_island([], data)
	var top: int = data.cloud_tops[0]
	expect(terrain.clouded(top), "the top under cloud 0 isn't clouded")
	terrain.fade_cloud(top, 0.5)
	expect(terrain.clouded(top), "a half-faded cloud no longer narrows the view")
	terrain.fade_cloud(top, 1.0)
	expect(not terrain.clouded(top), "a faded cloud still narrows the view")
	terrain.free()
