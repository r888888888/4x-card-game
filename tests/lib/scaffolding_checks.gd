extends RefCounted
## Red-phase scaffolding left in the suite (333): an engine typed Object, a script loaded into an untyped Variant, a
## has_method call. A line with `# scaffolding-ok: <reason>` is allowed; comment lines are skipped.

## What each pattern means -> its regex.
const PATTERNS := {
	"an engine typed Object": [
		":\\s*Object\\s*=\\s*[\\w.]*engine\\w*\\(",
		"\\w*engine\\w*\\([^()]*\\)\\s+as\\s+Object\\b",
		"\\b(e|engine)\\s*:\\s*Object\\b",
		"func\\s+\\w*engine\\w*\\(.*\\)\\s*->\\s*Object\\b",
	],
	"a script loaded into an untyped Variant": [":\\s*Variant\\s*=\\s*load\\("],
	"has_method": ["\\bhas_method\\("],
}
const OK := "# scaffolding-ok:"


## "path:line: what" for each scaffolding line in texts (path -> source), sorted by path then line.
static func problems(texts: Dictionary) -> Array[String]:
	var compiled := {}
	for what in PATTERNS:
		compiled[what] = PATTERNS[what].map(func(p: String) -> RegEx: return RegEx.create_from_string(p))
	var paths: Array = texts.keys()
	paths.sort()
	var out: Array[String] = []
	for path in paths:
		var lines: PackedStringArray = (texts[path] as String).split("\n")
		for i in lines.size():
			var line := lines[i]
			if line.strip_edges().begins_with("#") or _excused(line):
				continue
			for what in compiled:
				if compiled[what].any(func(re: RegEx) -> bool: return re.search(line) != null):
					out.append("%s:%d: %s" % [path, i + 1, what])
	return out


## Whether line carries `# scaffolding-ok: <reason>` with a reason.
static func _excused(line: String) -> bool:
	var at := line.rfind(OK)
	return at != -1 and line.substr(at + OK.length()).strip_edges() != ""
