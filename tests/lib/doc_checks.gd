extends RefCounted
## Checks on the docs and the tracked files (330): the repo paths a doc names exist, and no .gd.uid file outlives
## its script.

## The folders a backticked path must start with to count as a repo path.
const PREFIXES: Array[String] = ["engine/", "ui/", "sim/", "autoload/", "scripts/", "tests/", "data/", "docs/"]
## The docs checked besides docs/*.md and each skill's SKILL.md.
const ROOT_DOCS: Array[String] = ["PLAN.md", "CLAUDE.md", "README.md"]


## The docs whose paths are checked, repo-relative.
static func docs_to_check() -> Array[String]:
	var out: Array[String] = ROOT_DOCS.duplicate()
	for file in DirAccess.get_files_at("res://docs"):
		if file.ends_with(".md"):
			out.append("docs/" + file)
	for skill in DirAccess.get_directories_at("res://.claude/skills"):
		if FileAccess.file_exists("res://.claude/skills/%s/SKILL.md" % skill):
			out.append(".claude/skills/%s/SKILL.md" % skill)
	return out


## The repo paths text (the doc at doc_path) names, repo-relative, in order, without duplicates: backticked text
## starting with one of PREFIXES (up to its first space), and the target of every relative link (from the doc's
## folder). A `:line` suffix and an #anchor are dropped; placeholders (NNN, <…>), globs and fenced code are skipped.
static func paths_in(text: String, doc_path: String) -> Array[String]:
	var found := {}  # position in the text -> path
	var prose := RegEx.create_from_string("(?s)```.*?```").sub(text, "", true)
	for m in RegEx.create_from_string("(?<!`)`([^`\\n]+)`(?!`)").search_all(prose):
		var path := _clean(m.get_string(1).strip_edges().split(" ")[0].trim_prefix("res://"))
		if PREFIXES.any(func(p: String) -> bool: return path.begins_with(p)):
			found[m.get_start()] = path
	for m in RegEx.create_from_string("\\]\\(([^)\\s]+)\\)").search_all(prose):
		var target := m.get_string(1)
		if not (target.begins_with("#") or target.contains("://") or target.begins_with("mailto:")):
			found[m.get_start()] = _clean(doc_path.get_base_dir().path_join(target).simplify_path())
	var starts := found.keys()
	starts.sort()
	var out: Array[String] = []
	for start in starts:
		if found[start] != "" and not out.has(found[start]):
			out.append(found[start])
	return out


## "<doc>: <path>" for each path a doc names that doesn't exist; doc_texts maps doc path -> its text.
static func missing_paths(doc_texts: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for doc in doc_texts:
		for path in paths_in(doc_texts[doc], doc):
			var res := "res://" + path
			if not (FileAccess.file_exists(res) or DirAccess.dir_exists_absolute(res)):
				out.append("%s: %s" % [doc, path])
	return out


## The .gd.uid files under dirs (res:// or user:// paths, searched recursively) with no .gd beside them. Lists the
## globalized folders: with "//" in the user folder's path, listing a user:// path lists the project instead.
static func orphan_uids(dirs: Array) -> Array[String]:
	var out: Array[String] = []
	for dir in dirs:
		var files := DirAccess.get_files_at(ProjectSettings.globalize_path(dir))
		for file in files:
			if file.ends_with(".gd.uid") and not files.has(file.trim_suffix(".uid")):
				out.append(dir.path_join(file))
		var subdirs: Array[String] = []
		for sub in DirAccess.get_directories_at(ProjectSettings.globalize_path(dir)):
			subdirs.append(dir.path_join(sub))
		out.append_array(orphan_uids(subdirs))
	return out


## path without an #anchor or :line suffix, or "" for a placeholder or glob.
static func _clean(path: String) -> String:
	path = path.get_slice("#", 0)
	path = RegEx.create_from_string(":\\d+$").sub(path, "")
	if path.contains("NNN") or path.contains("<") or path.contains("*") or path == "":
		return ""
	return path

