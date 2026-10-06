#!/usr/bin/env bash
# Prints how many CPUs this process may use on Linux (317): nproc (the affinity mask) capped by ceil(quota / period)
# from the cgroup v2 cpu.max (CGROUP_CPU_MAX overrides its path; "max" or no file means no cap), never fewer than 1.
# Godot's OS.get_processor_count() sees every CPU of the host, which in a container can be far more than it may run.
# Elsewhere prints nothing and exits 1, so each caller keeps its own count (sim.sh: performance cores; test.sh: hw.ncpu).
set -uo pipefail
[[ "$(uname -s)" == Linux ]] || exit 1
cpus="$(nproc 2>/dev/null || echo 1)"
cpu_max="${CGROUP_CPU_MAX:-/sys/fs/cgroup/cpu.max}"
if [[ -r "$cpu_max" ]]; then
	read -r quota period _ <"$cpu_max"
	if [[ "$quota" =~ ^[0-9]+$ && "${period:-}" =~ ^[0-9]+$ ]] && ((period > 0)); then
		cap=$(((quota + period - 1) / period))
		((cap < cpus)) && cpus="$cap"
	fi
fi
((cpus < 1)) && cpus=1
echo "$cpus"
