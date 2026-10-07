extends "res://tests/lib/anarchy_case.gd"
## Engine areas (394): `engine.military`, the units' and raids' actions and queries on one object instead of forwards
## on GameEngine. Holds no state (only a weak reference back to its engine), and a fork's area acts on the fork.
## The actions' listing and dispatch by name are in test_legal_actions; the guard against new forwards is in
## test_engine_structure.

const LEVY := {"id": "levy", "name": "Levy", "type": "unit", "cost": {"food": 1}, "strength": 2}
## What engine.military offers (AC1), and the GameEngine names they replace (AC2), same order.
const AREA_METHODS: Array[String] = ["move_error", "move", "move_targets", "move_block", "strength", "veterancy",
	"strength_tag", "realm_size", "raid_turns_left", "raid_strength", "plunder_pct", "disband_error", "disband",
	"upgrade_error", "upgrade", "origin", "upgrade_line", "upgrade_cost", "raid_target", "raid_forecast", "outcome_text",
	"raid_line", "raid_tag", "raid_short", "defense", "defense_parts", "raid_warning"]
const OLD_NAMES: Array[String] = ["move_unit_error", "move_unit", "move_targets", "unit_move_block", "unit_strength",
	"unit_veterancy", "unit_strength_tag", "realm_size", "raid_turns_left", "raid_strength", "raid_plunder_pct",
	"disband_error", "disband", "upgrade_unit_error", "upgrade_unit", "unit_origin", "upgrade_line", "upgrade_cost",
	"raid_target", "raid_forecast", "raid_outcome_text", "raid_line", "raid_tag", "raid_short", "defense",
	"defense_parts", "raid_warning"]


## An anarchy game with a Levy recruited on the home and Hills settled, so the Levy can move there. Returns
## {e, levy, hills}.
func marching_game() -> Dictionary:
	var e := anarchy_engine({}, {"territory_deck": {"hills": 1, "grassland": 1}}, [LEVY])
	settle(e, ["hills"])
	var levy := put_in_hand(e, "levy")
	check(e.play_card(levy, home_uid(e)), "Levy recruited on the home: %s" % e.play_error(levy, home_uid(e)))
	return {"e": e, "levy": levy, "hills": uid_of(e.zone("tableau"), "hills")}


func test_the_military_area_offers_the_moved_methods() -> void:
	var e := make_engine({"farm": 10})
	var area: Object = e.get("military")  # scaffolding: the area is new in 394
	check(area != null, "engine.military exists")
	if area == null:
		return
	eq(AREA_METHODS.filter(func(m): return not area.has_method(m)), [], "engine.military's missing methods")


func test_the_old_names_are_gone_and_nothing_calls_them() -> void:
	var e := make_engine({"farm": 10})
	eq(OLD_NAMES.filter(func(m): return e.has_method(m)), [], "old names still on GameEngine")
	var callers: Array[String] = []
	for dir in ["res://engine", "res://ui", "res://sim", "res://tests"]:
		for path in scripts_in(dir):
			var text := FileAccess.get_file_as_string(path)
			for name in OLD_NAMES:
				if RegEx.create_from_string("[^\\w](?<!military)\\." + name + "\\(").search(text) != null \
						and not RegEx.create_from_string("\\.military\\." + name + "\\(").search(text) != null:
					callers.append("%s calls .%s(" % [path.get_file(), name])
	eq(callers, [] as Array[String], "callers of the old names")


## The .gd files under dir and its subfolders.
func scripts_in(dir: String) -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir + "/" + file)
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(scripts_in(dir + "/" + sub))
	return out


func test_a_forks_area_acts_on_the_fork() -> void:
	var g := marching_game()
	var e: GameEngine = g.e
	var home := home_uid(e)
	for f: GameEngine in [e.fork(), e.sample_fork(7)]:
		var area: Object = f.get("military")  # scaffolding: the area is new in 394
		check(area != null and area != e.get("military"), "the fork has its own area")
		if area == null:
			continue
		check(area.call("move", g.levy, g.hills), "the Levy marches on the fork: %s" % area.call("move_error", g.levy, g.hills))
		eq(f.unit_station(g.levy), g.hills, "on the fork, at Hills")
		eq(e.unit_station(g.levy), home, "in the game, still home")


func test_an_area_holds_no_state_and_goes_with_its_engine() -> void:
	var e := make_engine({"farm": 10})
	var area: Object = e.get("military")  # scaffolding: the area is new in 394
	check(area != null, "engine.military exists")
	if area == null:
		return
	var vars: Array = (area.get_script() as Script).get_script_property_list() \
		.filter(func(p): return p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE)
	eq(vars.map(func(p): return p.type), [TYPE_OBJECT], "one variable, the reference back: %s" % [vars.map(func(p): return p.name)])
	var gone: WeakRef = weakref(area)
	area = null
	e = null
	eq(gone.get_ref(), null, "freed with its engine")
