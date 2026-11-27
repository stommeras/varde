extends "res://tests/test_case.gd"


func test_same_seed_gives_same_clouds() -> void:
	var again: IslandData = IslandGenerator.generate(1)
	expect(again.clouds == island(1).clouds and again.cloud == island(1).cloud, "seed 1 gave different clouds the second time")


## Each cloud sits on a contender and covers its top and only land near the top, and about half the
## contenders have one.
func test_clouds_cap_contenders() -> void:
	var clouded: int = 0
	var contenders: int = 0
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		contenders += data.contenders.size()
		clouded += data.clouds.size()
		for i: int in data.clouds.size():
			var top: int = data.clouds[i]
			expect(top in data.contenders, "seed %d: a cloud stands on %d, which is no contender" % [island_seed, top])
			expect(data.cloud[top] == i + 1, "seed %d: cloud %d doesn't cover its top" % [island_seed, i])
			var cells: int = 0
			for cell: int in data.cloud.size():
				if data.cloud[cell] == i + 1:
					cells += 1
					expect(data.height[cell] >= data.height[top] - Clouds.DEPTH, "seed %d: cloud %d covers a cell far under its top" % [island_seed, i])
			expect(cells > 150, "seed %d: cloud %d covers only %d cells" % [island_seed, i, cells])
	expect(clouded >= contenders * 0.25 and clouded <= contenders * 0.75, "%d of %d contenders have a cloud" % [clouded, contenders])
