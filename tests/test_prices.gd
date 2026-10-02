extends "res://tests/lib/anarchy_case.gd"
## Prices and unrest in one place (backlog 173): EngineCore's can_pay and pay check and pay a price ({resource:
## amount}) for every action that costs something; Fields.amounts_text names a price ("2 food, 5 wealth"); set_unrest
## is the one way unrest is added or capped, stopping at unrest_limit(). Games from tests/lib/anarchy_case.gd (Chiefs,
## limit 5; era unrest 3).


## The lines of engine scripts (effects included) other than engine_core.gd matching pattern, as "file:line: text".
func engine_lines_matching(pattern: String) -> Array[String]:
	var re := RegEx.create_from_string(pattern)
	var out: Array[String] = []
	for dir in ["res://engine/", "res://engine/effects/"]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd") or file == "engine_core.gd":
				continue
			var lines := FileAccess.get_file_as_string(dir + file).split("\n")
			for i in lines.size():
				if re.search(lines[i]) != null and not lines[i].strip_edges().begins_with("#"):
					out.append("%s:%d: %s" % [file, i + 1, lines[i].strip_edges()])
	return out


# --- AC1: a short price of several resources names each one you have ---

func test_a_short_price_of_two_resources_names_both() -> void:
	var e := anarchy_engine()
	e.resources["food"] = 0
	e.resources["wealth"] = 1
	eq(e.price_error("Restoring order", {"food": 2, "wealth": 6}),
		"Restoring order needs 2 food, 6 wealth (you have 0 food, 1 wealth).", "two resources")
	eq(e.price_error("Restoring order", {"wealth": 6}), "Restoring order needs 6 wealth (you have 1).", "one resource")


# --- AC2: one helper checks a price, one pays it ---

func test_can_pay_and_pay_a_price() -> void:
	var e := anarchy_engine()
	e.resources["food"] = 2
	e.resources["wealth"] = 1
	check(e.can_pay({"food": 2}), "2 food with 2")
	check(e.can_pay({}), "nothing")
	check(not e.can_pay({"food": 2, "wealth": 2}), "2 wealth with 1")
	check(not e.can_pay({"insight": 11}), "11 insight with 10")
	e.pay({"food": 2, "wealth": 1})
	eq([e.resources.food, e.resources.wealth, e.resources.insight], [0, 0, 10], "after paying 2 food and 1 wealth")


func test_only_engine_core_takes_resources_away_or_names_food_and_wealth_as_fields() -> void:
	eq(engine_lines_matching("resources(\\[[^\\]]*\\]|\\.[a-z_]+)\\s*-="), [] as Array[String],
		"resources lowered outside EngineCore")
	eq(engine_lines_matching("resources\\.(food|wealth)\\b"), [] as Array[String], "resources.food / resources.wealth")


# --- AC3: the amounts text is public ---

func test_amounts_text_names_each_resource_of_a_price() -> void:
	eq(Fields.amounts_text({"food": 2, "wealth": 5}), "2 food, 5 wealth", "two resources")
	eq(Fields.amounts_text({"wealth": 5}), "5 wealth", "one")
	eq(engine_lines_matching("_amounts\\("), [] as Array[String], "calls to Famine._amounts")


# --- AC4: one helper adds or caps unrest, stopping at the limit ---

func test_set_unrest_stops_at_the_limit_and_returns_the_change() -> void:
	var e := anarchy_engine()
	e.resources["unrest"] = 4
	eq(e.set_unrest(9), 1, "4 → 5 of 5")
	eq(e.resources.unrest, 5, "capped at the limit")
	eq(e.set_unrest(2), -3, "5 → 2")
	eq(e.resources.unrest, 2, "lowered")


func test_a_new_era_at_unrest_4_of_5_adds_1() -> void:
	var e := anarchy_engine()
	var recorded := record_messages(e)
	e.resources["unrest"] = 4
	var dawn := put_in_hand(e, "dawn")
	check(e.play_card(dawn), "Dawn: %s" % e.play_error(dawn))
	eq(e.resources.get("unrest"), 5, "4 + 3, capped at 5")
	check_noticed(recorded, "+1 unrest", GameEngine.NOTICE_CAUTION)


func test_only_engine_core_writes_unrest() -> void:
	eq(engine_lines_matching("resources\\[(GameEngine\\.)?UNREST\\]\\s*=[^=]"), [] as Array[String],
		"unrest written outside EngineCore")
