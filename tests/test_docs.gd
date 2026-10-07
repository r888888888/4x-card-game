extends "res://tests/lib/test_case.gd"
## The docs and the tracked files stay true to the tree (backlog 330): every repo path PLAN.md, CLAUDE.md, README.md,
## docs/*.md and the skills name exists, and no .gd.uid file is left behind by a deleted script. 331: every test file
## opens with a ## header saying what it covers, and docs/testing.md indexes each in one short row. The checks live in
## tests/lib/doc_checks.gd.

const DocChecks := preload("res://tests/lib/doc_checks.gd")
const UID_DIRS: Array[String] = ["res://engine", "res://ui", "res://sim", "res://autoload", "res://tests"]


# --- AC1: the paths a doc names ---

func test_paths_in_finds_backticked_and_linked_repo_paths() -> void:
	var text := "See `engine/game_engine.gd`, `scripts/test.sh --balance`, [main](ui/main.gd:42) and `tests/balance/`."
	eq(DocChecks.paths_in(text, "PLAN.md"),
		["engine/game_engine.gd", "scripts/test.sh", "ui/main.gd", "tests/balance/"] as Array[String], "paths")


func test_placeholders_globs_commands_and_web_links_are_skipped() -> void:
	var text := "`docs/backlog/NNN-slug.md`, `tests/test_<area>.gd`, `data/*.json`, `godot --path .`, " \
		+ "[web](https://example.com/engine/x.gd), [here](#spikes), `res://ui/main.tscn`\n```bash\nscripts/nope.sh\n```"
	eq(DocChecks.paths_in(text, "README.md"), ["ui/main.tscn"] as Array[String], "only the real path")


func test_link_paths_resolve_from_the_docs_folder() -> void:
	var text := "[rules](../CLAUDE.md), [spikes](development-process.md#spikes), [hook](../scripts/test-hook.sh)"
	eq(DocChecks.paths_in(text, "docs/testing.md"),
		["CLAUDE.md", "docs/development-process.md", "scripts/test-hook.sh"] as Array[String], "resolved")


func test_missing_paths_names_the_doc_and_the_path() -> void:
	var texts := {"docs/a.md": "`engine/game_engine.gd` and `engine/nope.gd`", "PLAN.md": "`ui/gone/`"}
	eq(DocChecks.missing_paths(texts), ["docs/a.md: engine/nope.gd", "PLAN.md: ui/gone/"] as Array[String], "missing")


func test_the_checked_docs_are_plan_claude_readme_the_docs_and_the_skills() -> void:
	var docs := DocChecks.docs_to_check()
	for doc in ["PLAN.md", "CLAUDE.md", "README.md", "docs/testing.md", "docs/testing-index.md",
			"docs/development-process.md",			".claude/skills/tdd/SKILL.md", ".claude/skills/add-effect/SKILL.md"]:
		check(docs.has(doc), "%s is checked: %s" % [doc, docs])


func test_every_path_the_docs_name_exists() -> void:
	var texts := {}
	var named := 0
	for doc in DocChecks.docs_to_check():
		texts[doc] = FileAccess.get_file_as_string("res://" + doc)
		named += DocChecks.paths_in(texts[doc], doc).size()
	check(named >= 50, "the docs name at least 50 repo paths (found %d)" % named)
	eq(DocChecks.missing_paths(texts), [] as Array[String], "paths the docs name that don't exist")


# --- AC3: no orphan .uid files ---

func test_a_uid_with_no_script_beside_it_is_an_orphan() -> void:
	var root := "user://doc_checks_uids"
	DirAccess.make_dir_recursive_absolute(root + "/sub")
	for path in ["a.gd", "a.gd.uid", "b.gd.uid", "sub/c.gd.uid"]:
		FileAccess.open("%s/%s" % [root, path], FileAccess.WRITE).store_string("x")
	eq(DocChecks.orphan_uids([root]), [root + "/b.gd.uid", root + "/sub/c.gd.uid"] as Array[String], "orphans")
	for path in ["sub/c.gd.uid", "b.gd.uid", "a.gd.uid", "a.gd", "sub", ""]:
		DirAccess.remove_absolute("%s/%s" % [root, path])


func test_no_uid_file_in_the_project_has_lost_its_script() -> void:
	eq(DocChecks.orphan_uids(UID_DIRS), [] as Array[String], ".gd.uid files with no .gd beside them")
	check(FileAccess.file_exists("res://engine/game_engine.gd.uid"), "the check has uid files to look at")


# --- 331 AC1: every test file opens with a header ---

func test_a_test_file_without_a_header_after_extends_is_named() -> void:
	var texts := {"a.gd": "extends X\n## What a covers.\n", "b.gd": "extends X\n\nfunc test_b() -> void:\n",
		"c.gd": "extends X\n# a plain comment\n", "d.gd": "extends X\n##\n"}
	eq(DocChecks.headerless(texts), ["b.gd", "c.gd", "d.gd"] as Array[String], "files with no header")


func test_every_test_file_opens_with_a_header() -> void:
	var texts := {}
	for path in DocChecks.suite_files():
		texts[path] = FileAccess.get_file_as_string("res://" + path)
	check(texts.size() >= 150, "the check reads the test files (%d)" % texts.size())
	check(texts.has("tests/balance/test_sim_reports.gd"), "the balance suite's files are read too")
	eq(DocChecks.headerless(texts), [] as Array[String], "test files with no ## header after extends")


# --- 331 AC2, AC3: docs/testing.md indexes them in short rows ---

func test_table_problems_name_missing_rows_rows_for_no_file_and_long_rows() -> void:
	var long_row := "| `tests/test_c.gd` | %s |" % "x".repeat(150)
	var doc := "| File | Covers |\n|---|---|\n| `tests/test_a.gd` | A |\n| `tests/test_gone.gd` | Gone |\n%s\n" % long_row
	eq(DocChecks.table_problems(doc, ["tests/test_a.gd", "tests/test_b.gd", "tests/test_c.gd"]),
		["no row for tests/test_b.gd", "a row for a missing file: tests/test_gone.gd",
		"row over 160 characters: tests/test_c.gd (%d)" % long_row.length()] as Array[String], "problems")


# --- 391 AC1: docs/testing-index.md holds the index ---

func test_testing_index_lists_every_test_file_in_one_short_row() -> void:
	var doc := FileAccess.get_file_as_string("res://docs/testing-index.md")
	eq(DocChecks.table_problems(doc, DocChecks.suite_files()), [] as Array[String], "docs/testing-index.md's file table")


# --- 391 AC2: docs/testing.md holds no index rows ---

func test_index_rows_names_the_file_of_each_index_row() -> void:
	var checks = load("res://tests/lib/doc_checks.gd")
	var doc := "| File | Covers |\n|---|---|\n| `tests/test_a.gd` | A |\n| `tests/lib/x.gd` | Helper |\n" \
		+ "| `tests/balance/test_b.gd` | B |\n| `keywords()` | Ids |\n"
	eq(checks.index_rows(doc), ["tests/test_a.gd", "tests/balance/test_b.gd"] as Array[String], "index rows")


func test_testing_md_has_no_test_file_rows() -> void:
	var checks = load("res://tests/lib/doc_checks.gd")
	var doc := FileAccess.get_file_as_string("res://docs/testing.md")
	eq(checks.index_rows(doc), [] as Array[String], "test file rows left in docs/testing.md")


# --- 391 AC3: the guide is short and links the index ---

func test_testing_md_is_under_15_kb_and_links_the_index() -> void:
	var size := FileAccess.get_file_as_bytes("res://docs/testing.md").size()
	check(size < 15 * 1024, "docs/testing.md is %d bytes" % size)
	var doc := FileAccess.get_file_as_string("res://docs/testing.md")
	check(DocChecks.paths_in(doc, "docs/testing.md").has("docs/testing-index.md"), "docs/testing.md links the index")


func test_testing_md_is_under_25_kb() -> void:
	var size := FileAccess.get_file_as_bytes("res://docs/testing.md").size()
	check(size < 25 * 1024, "docs/testing.md is %d bytes" % size)
