extends "res://tests/lib/test_case.gd"
## Comparing two checkouts game by game (backlog 293): when a strategy x civ cell needs no more seeds (cell_done), and
## the report's lines. The runs on the real data are in tests/balance/test_sim_compare_runs.gd.


# --- AC1: cell_done ---

func test_a_cell_with_no_spread_is_done() -> void:
	var stats: Object = SimStats.new()
	check(stats.cell_done([0, 0, 0, 0, 0], 200.0, 20), "half-width 0")


func test_a_cell_whose_interval_is_wider_than_5_percent_is_not_done() -> void:
	var stats: Object = SimStats.new()
	check(not stats.cell_done([10, -10, 10, -10, 0], 200.0, 20), "half-width 2.776 x 10 / sqrt 5 = 12.4 > 10")


func test_a_cell_at_the_maximum_seeds_is_done() -> void:
	var stats: Object = SimStats.new()
	var deltas := []
	for i in 4:
		deltas.append_array([50, -50, 50, -50, 0])
	check(not stats.cell_done(deltas.slice(0, 15), 200.0, 20), "15 seeds: half-width 2.145 x 46.3 / sqrt 15 = 25.6 > 10")
	check(stats.cell_done(deltas, 200.0, 20), "20 seeds of 20, though half-width 21.5 > 10")


func test_the_tolerance_is_at_least_one_point() -> void:
	var stats: Object = SimStats.new()
	check(stats.cell_done([2, 3, 2, 3, 2], 0.0, 20), "main mean 0: tolerance 1 point, half-width 0.68")
	check(not stats.cell_done([0, 3, 0, 3, 0], 0.0, 20), "half-width 2.776 x 1.64 / sqrt 5 = 2.04 > 1")


# --- AC4: the report's lines ---

func test_a_cell_line_shows_both_means_the_change_its_interval_and_the_seeds() -> void:
	var stats: Object = SimStats.new()
	var cell := {"civ": "sumer", "main_mean": 249.0, "this_mean": 262.4, "delta": 13.4, "half_width": 4.1, "seeds": 10}
	eq(stats.cell_line(cell), "sumer  main 249.0  this 262.4  Δ +13.4 ±4.1 (+5.4%)  seeds 10", "the line")


func test_a_cell_that_moved_more_than_10_percent_is_flagged() -> void:
	var stats: Object = SimStats.new()
	var cell := {"civ": "", "main_mean": 200.0, "this_mean": 170.0, "delta": -30.0, "half_width": 2.0, "seeds": 5}
	eq(stats.cell_line(cell), "default  main 200.0  this 170.0  Δ -30.0 ±2.0 (-15.0%)  seeds 5 !", "flagged")
	cell.delta = -20.0
	cell.this_mean = 180.0
	eq(stats.cell_line(cell), "default  main 200.0  this 180.0  Δ -20.0 ±2.0 (-10.0%)  seeds 5", "10% exactly: not")


# --- 379: food and wealth trends, compared ---

func test_379_trend_change_line_shows_each_sample_moved() -> void:
	var compare: Object = SimCompare.new()
	var main := {"score": 40.0, "wealth_t10": 3.0, "wealth_t20": 10.0, "food_t10": 5.0}
	var this := {"score": 41.0, "wealth_t10": 3.0, "wealth_t20": 7.5, "food_t10": 5.0}
	eq(compare.trend_change_line("wealth", main, this), "wealth by turn  Δ 10 +0.0, 20 -2.5", "every sample, signed")
	eq(compare.trend_change_line("food", main, this), "", "no food sample moved")
	eq(compare.trend_change_line("food", {"score": 1.0}, {"score": 2.0}), "", "no samples")
	main.erase("wealth_t20")
	eq(compare.trend_change_line("wealth", main, this), "", "only samples both sides have")
