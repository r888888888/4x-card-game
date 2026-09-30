extends RefCounted
## Script line counts and the size limits on engine/ and ui/ (backlog 085).


## Lines in text as `wc -l` counts them: one per newline.
static func line_count(text: String) -> int:
	return text.count("\n")


## Script path -> line count for every .gd file under dirs, subfolders included.
static func count_lines_in(dirs: Array[String]) -> Dictionary:
	var counts := {}
	for dir in dirs:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				var path := dir.path_join(file)
				counts[path] = line_count(FileAccess.get_file_as_string(path))
		var subdirs: Array[String] = []
		for sub in DirAccess.get_directories_at(dir):
			subdirs.append(dir.path_join(sub))
		counts.merge(count_lines_in(subdirs))
	return counts


## Sorted paths over the hard limit ("hard") and over only the soft one ("soft").
static func classify(counts: Dictionary, hard: int, soft: int) -> Dictionary:
	var result := {"hard": [], "soft": []}
	for path in counts:
		if counts[path] > hard:
			result["hard"].append(path)
		elif counts[path] > soft:
			result["soft"].append(path)
	result["hard"].sort()
	result["soft"].sort()
	return result


## The line the suite prints for a script over the soft limit.
static func warning(path: String, lines: int, soft: int) -> String:
	return "WARN %s: %d lines (soft limit %d)" % [path.trim_prefix("res://"), lines, soft]
