extends "res://tests/lib/test_case.gd"
## The docs and the tracked files stay true to the tree (backlog 330): every repo path PLAN.md, CLAUDE.md, README.md,
## docs/*.md and the skills name exists, and no .gd.uid file is left behind by a deleted script. The checks live in
## tests/lib/doc_checks.gd.

const UID_DIRS: Array[String] = ["res://engine", "res://ui", "res://sim", "res://autoload", "res://tests"]


## Held as Object in the red phase so the file parses before the checks exist.
func checks() -> Object:
	return load("res://tests/lib/doc_checks.gd")


# --- AC1: the paths a doc names ---

func test_paths_in_finds_backticked_and_linked_repo_paths() -> void:
	var text := "See `engine/game_engine.gd`, `scripts/test.sh --balance`, [main](ui/main.gd:42) and `tests/balance/`."
	eq(checks().paths_in(text, "PLAN.md"),
		["engine/game_engine.gd", "scripts/test.sh", "ui/main.gd", "tests/balance/"] as Array[String], "paths")


func test_placeholders_globs_commands_and_web_links_are_skipped() -> void:
	var text := "`docs/backlog/NNN-slug.md`, `tests/test_<area>.gd`, `data/*.json`, `godot --path .`, " \
		+ "[web](https://example.com/engine/x.gd), [here](#spikes), `res://ui/main.tscn`\n```bash\nscripts/nope.sh\n```"
	eq(checks().paths_in(text, "README.md"), ["ui/main.tscn"] as Array[String], "only the real path")


func test_link_paths_resolve_from_the_docs_folder() -> void:
	var text := "[rules](../CLAUDE.md), [spikes](development-process.md#spikes), [hook](../scripts/test-hook.sh)"
	eq(checks().paths_in(text, "docs/testing.md"),
		["CLAUDE.md", "docs/development-process.md", "scripts/test-hook.sh"] as Array[String], "resolved")


func test_missing_paths_names_the_doc_and_the_path() -> void:
	var texts := {"docs/a.md": "`engine/game_engine.gd` and `engine/nope.gd`", "PLAN.md": "`ui/gone/`"}
	eq(checks().missing_paths(texts), ["docs/a.md: engine/nope.gd", "PLAN.md: ui/gone/"] as Array[String], "missing")


func test_the_checked_docs_are_plan_claude_readme_the_docs_and_the_skills() -> void:
	var docs: Array = checks().docs_to_check()
	for doc in ["PLAN.md", "CLAUDE.md", "README.md", "docs/testing.md", "docs/development-process.md",
			".claude/skills/tdd/SKILL.md", ".claude/skills/add-effect/SKILL.md"]:
		check(docs.has(doc), "%s is checked: %s" % [doc, docs])


func test_every_path_the_docs_name_exists() -> void:
	var texts := {}
	var named := 0
	for doc in checks().docs_to_check():
		texts[doc] = FileAccess.get_file_as_string("res://" + doc)
		named += (checks().paths_in(texts[doc], doc) as Array).size()
	check(named >= 50, "the docs name at least 50 repo paths (found %d)" % named)
	eq(checks().missing_paths(texts), [] as Array[String], "paths the docs name that don't exist")


# --- AC3: no orphan .uid files ---

func test_a_uid_with_no_script_beside_it_is_an_orphan() -> void:
	var root := "user://doc_checks_uids"
	DirAccess.make_dir_recursive_absolute(root + "/sub")
	for path in ["a.gd", "a.gd.uid", "b.gd.uid", "sub/c.gd.uid"]:
		FileAccess.open("%s/%s" % [root, path], FileAccess.WRITE).store_string("x")
	eq(checks().orphan_uids([root]), [root + "/b.gd.uid", root + "/sub/c.gd.uid"] as Array[String], "orphans")
	for path in ["sub/c.gd.uid", "b.gd.uid", "a.gd.uid", "a.gd", "sub", ""]:
		DirAccess.remove_absolute("%s/%s" % [root, path])


func test_no_uid_file_in_the_project_has_lost_its_script() -> void:
	eq(checks().orphan_uids(UID_DIRS), [] as Array[String], ".gd.uid files with no .gd beside them")
	check(FileAccess.file_exists("res://engine/game_engine.gd.uid"), "the check has uid files to look at")
