extends "res://tests/lib/test_case.gd"
## Palette roles (192): a colour set in code once is passed as a role name, so it follows a Day mode switch; a role
## name in ui/ is one the Palette has; and the Night and Day sets name the same roles as Palette's colours.

const PALETTE_PATH := "res://ui/palette.gd"
const UI_KIT_PATH := "res://ui/ui_kit.gd"


## The all-caps StringName literals (&"GAIN") in the ui/ scripts' code, as "ui/file:line NAME".
func role_literals() -> Array[String]:
	var found: Array[String] = []
	var literal := RegEx.create_from_string("&\"([A-Z][A-Z_]*)\"")
	for file in DirAccess.get_files_at("res://ui"):
		if not file.ends_with(".gd"):
			continue
		var lines := FileAccess.get_file_as_string("res://ui/" + file).split("\n")
		for i in lines.size():
			var code := lines[i].split("#")[0]
			for m in literal.search_all(code):
				found.append("ui/%s:%d %s" % [file, i + 1, m.get_string(1)])
	return found


## The names of Palette's static Color vars, from its source (a script's property list leaves out static vars).
func palette_colours() -> Array[String]:
	var names: Array[String] = []
	var declaration := RegEx.create_from_string("(?m)^static var ([A-Z][A-Z_]*): Color\\b")
	for m in declaration.search_all(FileAccess.get_file_as_string(PALETTE_PATH)):
		names.append(m.get_string(1))
	names.sort()
	return names


func test_stat_takes_a_role_name_not_a_colour() -> void:
	var found := false
	for m in (load(UI_KIT_PATH) as Script).get_script_method_list():
		if m.name == "stat":
			found = true
			eq(m.args.size(), 2, "stat(parent, role)")
			if m.args.size() == 2:
				eq(m.args[1].type, TYPE_STRING_NAME, "stat's colour parameter is a StringName (a Palette role)")
	check(found, "UIKit.stat exists")


func test_a_stat_follows_a_day_mode_switch() -> void:
	await with_temp_settings(func():
		var main := open_main()
		var stat: Label = UIKit.stat(main, &"POP")
		Settings.set_day_mode(true)
		await wait_frames()
		eq(stat.get_theme_color("font_color").to_html(false), Palette.DAY["POP"].to_html(false), "day POP")
		Settings.set_day_mode(false)
		await wait_frames()
		eq(stat.get_theme_color("font_color").to_html(false), Palette.NIGHT["POP"].to_html(false), "night POP")
		close_main(main))


func test_every_role_name_in_the_ui_is_a_palette_role() -> void:
	var literals := role_literals()
	check(not literals.is_empty(), "precondition: ui/ passes some roles by name")
	var unknown: Array[String] = []
	for entry in literals:
		if not Palette.NIGHT.has(entry.get_slice(" ", 1)):
			unknown.append(entry)
	eq(unknown, [] as Array[String], "role names that aren't Palette roles")


func test_night_and_day_name_the_palettes_colours() -> void:
	var night: Array[String] = []
	night.assign(Palette.NIGHT.keys())
	night.sort()
	var day: Array[String] = []
	day.assign(Palette.DAY.keys())
	day.sort()
	eq(day, night, "Day names the same roles as Night")
	eq(palette_colours(), night, "Palette's colours are exactly Night's roles")
