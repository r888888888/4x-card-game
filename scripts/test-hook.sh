#!/usr/bin/env bash
# Claude Code Stop hook: runs the test suite when Claude finishes a turn, and sends
# failures back to Claude (exit 2) so it keeps working until the suite is green.
# Skips when nothing relevant changed since the last green run, and while a TDD red
# checkpoint is waiting for review (.claude/tdd-red exists).
set -uo pipefail
cd "$(dirname "$0")/.."

input="$(cat)"
green_stamp=".godot/.test-green-stamp"

if [[ -f .claude/tdd-red ]]; then
	echo "{\"systemMessage\": \"TDD red checkpoint ($(head -1 .claude/tdd-red)): failing tests are expected; test hook paused.\"}"
	exit 0
fi

if [[ -f "$green_stamp" ]] && [[ -z "$(find engine autoload ui tests data scripts \
		\( -name '*.gd' -o -name '*.json' -o -name '*.tscn' \) -newer "$green_stamp" -print -quit 2>/dev/null)" ]]; then
	exit 0
fi

if output="$(scripts/test.sh 2>&1)"; then
	mkdir -p .godot && touch "$green_stamp"
	exit 0
fi

summary="$(printf '%s\n' "$output" | tail -1)"
if [[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" == "true" ]]; then
	# Already blocked once this turn: don't loop, just tell the user.
	jq -n --arg m "Tests still failing ($summary). Run scripts/test.sh for details." '{systemMessage: $m}'
	exit 0
fi

{
	echo "Test suite is failing ($summary):"
	printf '%s\n' "$output" | grep -e '^FAIL' -e 'SCRIPT ERROR' | head -30
	echo "Fix these before finishing. If you are deliberately stopping at a TDD red checkpoint,"
	echo "write the backlog item id to .claude/tdd-red first (see the tdd skill)."
} >&2
exit 2
