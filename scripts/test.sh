#!/usr/bin/env bash
# Runs the headless test suite. Usage: scripts/test.sh [--balance] [filter]
#   filter: substring of "file::method", e.g. "rules" or "test_create_card"
#   --balance: run only tests/balance/ (real-data sim runs; the main suite and the Stop hook leave it out), at nice 10
#     (SIM_NICE=n overrides) so the long run on every core leaves the desktop responsive
# Re-imports the project first when any .gd file changed, so new class_names resolve.
# The files run in TEST_JOBS parallel shards (default: the CPU count, 223; on Linux the CPUs scripts/cpus.sh allows, 317), each Godot with its own empty HOME so no
# two share user:// (nor touch the player's). The last line sums them: "N tests, M failures".
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
stamp=".godot/.test-import-stamp"
if [[ ! -f "$stamp" ]] || [[ -n "$(find . -name '*.gd' -newer "$stamp" -not -path './.godot/*' -print -quit)" ]]; then
	"$GODOT" --headless --path . --import >/dev/null 2>&1
	mkdir -p .godot && touch "$stamp"
fi

jobs="${TEST_JOBS:-$(scripts/cpus.sh || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
work="$(mktemp -d "${TMPDIR:-/tmp}/4x-tests.XXXXXX")"
trap 'rm -rf "$work"' EXIT

niceness=0
for arg in "$@"; do [[ "$arg" == --balance ]] && niceness="${SIM_NICE:-10}"; done

pids=()
for ((i = 0; i < jobs; i++)); do
	mkdir -p "$work/home$i"
	HOME="$work/home$i" TEST_SHARD="$i/$jobs" nice -n "$niceness" "$GODOT" --headless --fixed-fps 120 --path . \
		--script res://tests/run_tests.gd -- "$@" >"$work/out$i" 2>&1 &
	pids+=($!)
done

tests=0
failures=0
status=0
summary='^([0-9]+) tests, ([0-9]+) failures$'
for ((i = 0; i < jobs; i++)); do
	wait "${pids[$i]}" || status=1
	# Drop the engine banner and backtrace noise; the runner prints one FAIL line per problem.
	grep -v -E -e '^Godot Engine v' -e '^$' -e '^ *GDScript backtrace' -e '^ *\[[0-9]*\] ' -e "$summary" "$work/out$i"
	line="$(grep -E "$summary" "$work/out$i" | tail -1)"
	if [[ "$line" =~ $summary ]]; then
		tests=$((tests + BASH_REMATCH[1]))
		failures=$((failures + BASH_REMATCH[2]))
	else
		echo "FAIL shard $i/$jobs crashed before its summary (output above)" >&2
		failures=$((failures + 1))
		status=1
	fi
done

if ((tests == 0)); then
	filter=""
	for arg in "$@"; do [[ "$arg" == --balance ]] || filter="$arg"; done
	echo "No tests matched filter '$filter'." >&2
	status=1
fi
echo "$tests tests, $failures failures"
exit "$status"
