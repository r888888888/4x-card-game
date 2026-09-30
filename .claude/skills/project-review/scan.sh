#!/usr/bin/env bash
# Mechanical checks for the project-review skill. Prints candidates, not verdicts: read each hit before
# reporting it. Usage: .claude/skills/project-review/scan.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

section() { printf '\n=== %s\n' "$1"; }

section "Script sizes (engine/, ui/, sim/, autoload/): largest first"
wc -l engine/*.gd engine/**/*.gd ui/*.gd sim/*.gd autoload/*.gd 2>/dev/null | grep -v total | sort -rn | head -12

section "Test suite: count, failures, time"
{ time scripts/test.sh >/tmp/project-review-tests.$$ 2>&1; } 2>&1 | grep real
grep -E 'tests, |^WARN |^FAIL' /tmp/project-review-tests.$$; rm -f /tmp/project-review-tests.$$

section "Tests per file"
for f in tests/test_*.gd; do printf '%4d  %s\n' "$(grep -c '^func test_' "$f")" "$f"; done | sort -rn

section "Helpers defined in more than one test file (same name; check they behave the same)"
grep -ho '^func [a-z][a-z0-9_]*' tests/test_*.gd | grep -v 'func test_' | sort | uniq -c | awk '$1 > 1' | sort -rn

section "Helpers in test files that already exist in tests/lib/"
for name in $(grep -ho '^func [a-z][a-z0-9_]*' tests/lib/*.gd | awk '{print $2}' | sort -u); do
	grep -l "^func $name(" tests/test_*.gd 2>/dev/null | sed "s/^/$name: /"
done

section "Tests calling private engine members"
grep -n '\._[a-z]' tests/test_*.gd tests/lib/*.gd | grep -v '^\s*#' | head -20

section "Padding assertions"
grep -nE 'check\(true|eq\(true, true' tests/*.gd

section "Assertions on log text"
grep -nE 'log_lines|logged' tests/test_*.gd | head -20

section "Content tests that may pin exact data values (eq on real data)"
grep -nE 'eq\(r\.|eq\(.*r\.cards\.|eq\(.*r\.config\.' tests/test_content.gd | head -30

section "Loader-validation tests (candidates for tables)"
grep -ho '^func test_[a-z0-9_]*' tests/test_*.gd | grep -cE '_error|warning|_loads|must_be|normalized|defaults'

section "Public engine functions no test mentions (Effect hooks excluded: they run polymorphically)"
for f in $(grep -ho '^func [a-z][a-z0-9_]*' $(ls engine/*.gd | grep -v 'engine/effect.gd') | awk '{print $2}' | sort -u); do
	grep -qw "$f" tests/*.gd tests/lib/*.gd sim/*.gd || echo "$f"
done

section "Public actions without a \`*_error\` query (GameEngine, under # --- Actions ---)"
# Actions whose query doesn't follow the foo/foo_error naming.
ACTION_ERROR_PAIRS="play_card:play_error buy_tech:buy_tech_error new_game:new_game_error end_turn:end_turn_error buy:buy_error grow:grow_error"
sed -n '/^# --- Actions ---/,/^# --- /p' engine/game_engine.gd \
	| grep -oE '^func [a-z][a-z0-9_]*\(.*\) -> (bool|void)' | awk '{print $2}' | sed 's/(.*//' | grep -v '_error$' \
	| while read -r action; do
		query="${action}_error"
		for pair in $ACTION_ERROR_PAIRS; do [ "${pair%%:*}" = "$action" ] && query="${pair#*:}"; done
		grep -q "^func $query(" engine/game_engine.gd || echo "$action"
	done

section "Card type / resource string literals compared or indexed in engine/ and ui/ (should be constants)"
grep -rnE '(==|!=) *"(action|building|city|territory|tech|event|civilization|government)"|(\[|get\()"(food|wealth)"|\.(food|wealth)\b' engine ui \
	| grep -v '^\S*: *##' | head -20

section "UI code that may hold rules (conditions on engine state)"
grep -nE 'if .*(e|Game\.engine)\.(resources|zone\(|pending|turn|is_over|config)' ui/*.gd | head -20

section "Tracked files that shouldn't be"
git ls-files | grep -E '\.DS_Store$|~$|\.orig$' || echo "(none)"

section "Local permissions that contradict CLAUDE.md's Git rules"
grep -nE 'git (merge|push|rebase|reset|branch -D)' .claude/settings*.json 2>/dev/null || echo "(none)"
