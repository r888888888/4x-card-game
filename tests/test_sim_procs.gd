extends "res://tests/lib/test_case.gd"
## How many processes a sim run uses (backlog 291): SIM_PROCS, else the performance cores but one, else every core but
## one; never fewer than 1. The real-data runs (the job queue, the lock) are in tests/balance/test_parallel_sim.gd.


# --- AC1: procs_from_env ---

func test_sim_procs_overrides_the_default() -> void:
	var stats: Object = SimStats.new()
	eq(stats.procs_from_env({"SIM_PROCS": "3"}, 12), 3, "SIM_PROCS 3")
	eq(stats.procs_from_env({"SIM_PROCS": "1", "SIM_PERF_CORES": "8"}, 12), 1, "SIM_PROCS 1")


func test_the_default_is_the_performance_cores_but_one() -> void:
	var stats: Object = SimStats.new()
	eq(stats.procs_from_env({"SIM_PERF_CORES": "8"}, 12), 7, "8 performance cores of 12")


func test_with_no_performance_core_count_it_is_every_core_but_one() -> void:
	var stats: Object = SimStats.new()
	eq(stats.procs_from_env({}, 12), 11, "12 cores")
	eq(stats.procs_from_env({"SIM_PERF_CORES": ""}, 12), 11, "an empty SIM_PERF_CORES (no such sysctl key)")


func test_a_run_never_uses_fewer_than_one_process() -> void:
	var stats: Object = SimStats.new()
	eq(stats.procs_from_env({}, 1), 1, "1 core")
	eq(stats.procs_from_env({"SIM_PERF_CORES": "1"}, 4), 1, "1 performance core")


func test_an_invalid_sim_procs_is_ignored() -> void:
	var stats: Object = SimStats.new()
	eq(stats.procs_from_env({"SIM_PROCS": "0", "SIM_PERF_CORES": "8"}, 12), 7, "SIM_PROCS 0")
	eq(stats.procs_from_env({"SIM_PROCS": "x", "SIM_PERF_CORES": "8"}, 12), 7, "SIM_PROCS x")
