#!/usr/bin/env bash
# Runs the headless balance simulator on data/*.json. Usage: scripts/sim.sh [seeds] [strategy] [--civ id] [--turns n]  (default 20, all)
#   scripts/sim.sh --compare <checkout> [max seeds] [strategy] [--civ id] [--turns n]: compares that checkout ("main") with
#   this one game by game (293): seeds in rounds of 5 per strategy x civ until the score change is within ±5% of main's,
#   or max seeds (default 20); a line per cell (! past 10%), then the other metrics that moved. Both need sim/ from 293.
# Prints mean, min and max per metric over seeds 1..N (a block per strategy, scored per civilization, 134); exits 1 if the data has loader errors.
# Plays the games on the performance cores but one (152, 291; every core but one where the count is unknown), each
# worker taking the next game from one queue; SIM_PROCS=n sets how many, SIM_PROCS=1 plays them in one process.
# Each game's result is cached by the code and data that played it (292), shared by every checkout; SIM_CACHE=0 skips
# the cache. One parallel run at a time across every checkout: a second one exits 1 at once, naming the running one's pid (291).
# Runs at nice 10 (SIM_NICE=n overrides; the worker processes inherit it) so a run on every core leaves the desktop responsive.
set -uo pipefail
export SIM_CWD="$PWD"  # --compare's relative path is from here
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
stamp=".godot/.test-import-stamp"
if [[ ! -f "$stamp" ]] || [[ -n "$(find . -name '*.gd' -newer "$stamp" -not -path './.godot/*' -print -quit)" ]]; then
	"$GODOT" --headless --path . --import >/dev/null 2>&1
	mkdir -p .godot && touch "$stamp"
fi

export SIM_PERF_CORES="${SIM_PERF_CORES:-$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null)}"
nice -n "${SIM_NICE:-10}" "$GODOT" --headless --path . --script res://sim/run.gd -- "$@" 2>&1 \
	| grep -v -e '^Godot Engine v' -e '^$' -e '^ *GDScript backtrace' -e '^ *\[[0-9]*\] ' \
		-e 'ObjectDB instances were leaked' -e 'resources still in use at exit' -e '^ *at: '
exit "${PIPESTATUS[0]}"
