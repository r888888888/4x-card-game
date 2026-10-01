#!/usr/bin/env bash
# Runs the headless balance simulator on data/*.json. Usage: scripts/sim.sh [seeds] [strategy]  (default 20, all)
# Prints mean, min and max per metric over seeds 1..N (a block per strategy, scored per civilization, 134); exits 1 if the data has loader errors.
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
stamp=".godot/.test-import-stamp"
if [[ ! -f "$stamp" ]] || [[ -n "$(find . -name '*.gd' -newer "$stamp" -not -path './.godot/*' -print -quit)" ]]; then
	"$GODOT" --headless --path . --import >/dev/null 2>&1
	mkdir -p .godot && touch "$stamp"
fi

"$GODOT" --headless --path . --script res://sim/run.gd -- "${1:-20}" "${2:-all}" 2>&1 \
	| grep -v -e '^Godot Engine v' -e '^$' -e '^ *GDScript backtrace' -e '^ *\[[0-9]*\] ' \
		-e 'ObjectDB instances were leaked' -e 'resources still in use at exit' -e '^ *at: '
exit "${PIPESTATUS[0]}"
