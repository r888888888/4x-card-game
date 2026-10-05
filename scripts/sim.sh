#!/usr/bin/env bash
# Runs the headless balance simulator on data/*.json. Usage: scripts/sim.sh [seeds] [strategy] [--civ id] [--turns n]  (default 20, all)
# Prints mean, min and max per metric over seeds 1..N (a block per strategy, scored per civilization, 134); exits 1 if the data has loader errors.
# Plays the games on one process per CPU core (152); SIM_PROCS=n sets how many, SIM_PROCS=1 plays them in one process.
# Runs at nice 10 (SIM_NICE=n overrides; the worker processes inherit it) so a run on every core leaves the desktop responsive.
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
stamp=".godot/.test-import-stamp"
if [[ ! -f "$stamp" ]] || [[ -n "$(find . -name '*.gd' -newer "$stamp" -not -path './.godot/*' -print -quit)" ]]; then
	"$GODOT" --headless --path . --import >/dev/null 2>&1
	mkdir -p .godot && touch "$stamp"
fi

nice -n "${SIM_NICE:-10}" "$GODOT" --headless --path . --script res://sim/run.gd -- "$@" 2>&1 \
	| grep -v -e '^Godot Engine v' -e '^$' -e '^ *GDScript backtrace' -e '^ *\[[0-9]*\] ' \
		-e 'ObjectDB instances were leaked' -e 'resources still in use at exit' -e '^ *at: '
exit "${PIPESTATUS[0]}"
