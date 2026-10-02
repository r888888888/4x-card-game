#!/usr/bin/env bash
# Runs the headless test suite. Usage: scripts/test.sh [--balance] [filter]
#   filter: substring of "file::method", e.g. "rules" or "test_create_card"
#   --balance: run only tests/balance/ (real-data sim runs; the main suite and the Stop hook leave it out)
# Re-imports the project first when any .gd file changed, so new class_names resolve.
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
stamp=".godot/.test-import-stamp"
if [[ ! -f "$stamp" ]] || [[ -n "$(find . -name '*.gd' -newer "$stamp" -not -path './.godot/*' -print -quit)" ]]; then
	"$GODOT" --headless --path . --import >/dev/null 2>&1
	mkdir -p .godot && touch "$stamp"
fi

# Drop the engine banner and backtrace noise; the runner prints one FAIL line per problem.
"$GODOT" --headless --path . --script res://tests/run_tests.gd -- "$@" 2>&1 \
	| grep -v -e '^Godot Engine v' -e '^$' -e '^ *GDScript backtrace' -e '^ *\[[0-9]*\] '
exit "${PIPESTATUS[0]}"
