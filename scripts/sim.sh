#!/usr/bin/env bash
# Runs the headless balance simulator on data/*.json. Usage: scripts/sim.sh [seeds] [strategy] [--civ id] [--turns n]  (default 20, all)
#   scripts/sim.sh --compare <checkout> [max seeds] [strategy] [--civ id] [--turns n]: compares that checkout ("main") with
#   this one game by game (293): seeds in rounds of 5 per strategy x civ until the score change is within ±5% of main's,
#   or max seeds (default 20); a line per cell (! past 10%), then the other metrics that moved. Both need sim/ from 293.
# Prints mean, min and max per metric over seeds 1..N (a block per strategy, scored per civilization, 134); exits 1 if the data has loader errors.
# Plays the games on the performance cores but one (152, 291; every core but one where the count is unknown; on Linux
# every CPU scripts/cpus.sh allows, since a container has no desktop to keep responsive, 317), each worker taking the next game from one queue; SIM_PROCS=n sets how many, SIM_PROCS=1 plays them in one process.
# Each game's result is cached by the code and data that played it (292), shared by every checkout; SIM_CACHE=0 skips
# the cache. One parallel run at a time across every checkout: a second one exits 1 at once, naming the running one's pid (291).
# A parallel run prints a progress line to stderr each minute, and stops a worker that finishes no turn for 10 minutes
# (SIM_STALL_SEC=n sets the limit), exiting 1 with the worker, game and turn it stopped at (318).
# Runs at nice 10 (SIM_NICE=n overrides; the worker processes inherit it) so a run on every core leaves the desktop responsive.
set -uo pipefail
args=()
while (($#)); do  # --compare <checkout> goes to sim/run.gd as SIM_COMPARE (an absolute path), not as a launch option
	if [[ "$1" == --compare ]]; then
		[[ $# -ge 2 && -f "$2/project.godot" ]] || { echo "--compare needs a checkout: ${2:-}" >&2; exit 1; }
		export SIM_COMPARE="$(cd "$2" && pwd)"
		shift 2
	else
		args+=("$1")
		shift
	fi
done
set -- ${args[@]+"${args[@]}"}
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
stamp=".godot/.test-import-stamp"
if [[ ! -f "$stamp" ]] || [[ -n "$(find . -name '*.gd' -newer "$stamp" -not -path './.godot/*' -print -quit)" ]]; then
	"$GODOT" --headless --path . --import >/dev/null 2>&1
	mkdir -p .godot && touch "$stamp"
fi

# On Linux one more than the allowed CPUs, so procs_from_env's "but one" leaves a worker on each of them.
if [[ -z "${SIM_PERF_CORES:-}" ]] && linux_cpus="$(scripts/cpus.sh)"; then
	SIM_PERF_CORES=$((linux_cpus + 1))
fi
export SIM_PERF_CORES="${SIM_PERF_CORES:-$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null)}"
nice -n "${SIM_NICE:-10}" "$GODOT" --headless --path . --script res://sim/run.gd -- "$@" 2>&1 \
	| grep -v -e '^Godot Engine v' -e '^$' -e '^ *GDScript backtrace' -e '^ *\[[0-9]*\] ' \
		-e 'ObjectDB instances were leaked' -e 'resources still in use at exit' -e '^ *at: '
exit "${PIPESTATUS[0]}"
