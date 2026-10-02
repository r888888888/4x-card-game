class_name TopBar
extends HBoxContainer
## The top bar: turn, food, wealth, insight (139) and unrest (144, out of its limit) (with next upkeep's change), score
## and pop, then
## (115) Buy Cards, Knowledge, Log and Menu (the civilization, the government and End turn are in the Sidebar: 202, 203). Any
## change to Food, Wealth, Insight, Unrest, Score or Pop rolls that counter's figure and tags it with its net change
## (126, 181).

const GLYPH := 22  # a counter's glyph (180), about the height of its figure
# Keys for counter() beside the resources (GameEngine.FOOD, WEALTH, INSIGHT, UNREST) (177).
const SCORE := "score"
const POP := "pop"
const TURN := "turn"

var menu_button: Button  # "Menu" (its key, Esc, is in its tooltip: 120)
var log_button: Button  # "Log": opens the log drawer (115); its key, L, is in its tooltip (120)
var _turn_label: Label
var _counters := {}  # key -> Counter: food, wealth, insight, unrest (hidden while off, 144), score, pop (hidden while off)
var _knowledge: Button  # opens the tech tree (059), where techs are learned (140)
var _fresh := true  # a new game's first refresh shows its values at once, with no tags (126)


## on_knowledge opens the tech tree, on_log toggles the log drawer.
func _init(on_menu: Callable, on_knowledge: Callable, on_log: Callable) -> void:
	add_theme_constant_override("separation", Tokens.SPACE_3)  # tight: the stats and six buttons share 1920 px (115, 139, 144)
	_turn_label = UIKit.stat(self)
	_turn_label.theme_type_variation = &"BarStat"
	for key in [GameEngine.FOOD, GameEngine.WEALTH, GameEngine.INSIGHT, GameEngine.UNREST, SCORE, POP]:
		var counter := Counter.new(key)
		add_child(counter)
		_counters[key] = counter
	_counters[SCORE].tooltip_text = "Score: victory points."
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	_knowledge = UIKit.button("Knowledge", on_knowledge)
	add_child(_knowledge)
	log_button = UIKit.button("Log", on_log)
	log_button.tooltip_text = "Shortcut: L. The game log: everything that happened."
	add_child(log_button)
	menu_button = UIKit.button("Menu", on_menu)
	menu_button.tooltip_text = "Shortcut: Esc. New game, restart with a seed, reduce motion, exit."
	add_child(menu_button)


## The counter for key (a resource, SCORE, POP or TURN), or null for an unknown key (177).
func counter(key: String) -> Control:
	return _turn_label if key == TURN else _counters.get(key)


## The whole reading counter(key) shows ("3 (+1)", "Turn 1 / 100"), or "" for an unknown key (177): at once, while the
## figure still rolls (181).
func counter_text(key: String) -> String:
	if key == TURN:
		return _turn_label.text
	return (_counters[key] as Counter).text() if _counters.has(key) else ""


## Makes the next refresh show its values at once, with no tags: a new game (126).
func reset_counters() -> void:
	_fresh = true


## Shows engine e's stats: each counter's figure rolls to its new value and, unless quiet (a screen covering the bar
## shows its own), shows its net change as a tag, left to right Anim.TAG_STAGGER apart (126, 181). The changed counters
## roll one after another, left to right, each starting as the one before registers, so their ticks make one tidy
## run and their registrations come in order (188); quiet, they roll in silence.
func refresh(e: GameEngine, quiet := false) -> void:
	UIKit.set_stat(_turn_label, "Turn %d / %d" % [e.turn, e.turn_limit()])
	var forecast := e.upkeep_forecast()
	var starve: int = forecast.get("starve", 0)
	var limit := e.unrest_limit()
	var readings := {  # key -> [value, the text after the figure]
		GameEngine.FOOD: [e.resources.get(GameEngine.FOOD, 0), _forecast_text(forecast, GameEngine.FOOD)],
		GameEngine.WEALTH: [e.resources.get(GameEngine.WEALTH, 0), _forecast_text(forecast, GameEngine.WEALTH)],
		GameEngine.INSIGHT: [e.resources.get(GameEngine.INSIGHT, 0), _forecast_text(forecast, GameEngine.INSIGHT)],
		GameEngine.UNREST: [e.resources.get(GameEngine.UNREST, 0),
			(" / %d" % limit if limit >= 0 else "") + _forecast_text(forecast, GameEngine.UNREST)],
		SCORE: [e.score(), ""],
		POP: [e.total_pop(), ""],
	}
	_counters[GameEngine.UNREST].visible = e.unrest_on()
	_counters[POP].visible = e.population_on()
	var n := 0
	var roll_at := 0.0
	for key: String in readings:
		var counter: Counter = _counters[key]
		var change := counter.show_value(readings[key][0], readings[key][1], _fresh, roll_at, not quiet and counter.visible)
		roll_at += mini(absi(change), Anim.ODOMETER_MAX_STEPS) * Anim.ODOMETER_STEP
		if change != 0 and not quiet and counter.visible:
			counter.show_tag(change, n * Anim.TAG_STAGGER)
			n += 1
	_fresh = false
	_counters[GameEngine.FOOD].set_color(CardView.WARN_COLOR if starve > 0 else Palette.TEXT)
	_counters[GameEngine.FOOD].tooltip_text = "Next upkeep: famine, %d pop will die." % starve if starve > 0 else "In brackets: change at the next upkeep, after pop eats."
	_counters[GameEngine.WEALTH].tooltip_text = "In brackets: change at the next upkeep."
	_counters[GameEngine.INSIGHT].tooltip_text = "Pays for techs. In brackets: change at the next upkeep."
	_counters[GameEngine.UNREST].set_color(CardView.WARN_COLOR if e.at_unrest_limit() else Palette.TEXT)
	_counters[GameEngine.UNREST].tooltip_text = ("Civil unrest, out of the most your government tolerates%s. " % (
		"" if limit >= 0 else " (it sets no limit)")) + "In brackets: change at the next upkeep."
	_knowledge.visible = e.research_on()
	_knowledge.tooltip_text = "Shortcut: T. The tech tree: every tech by era, what it costs now and what it gives.\nEra: %s." % (
		e.era_name(e.era()))  # the era is here, not on the button, to make room for Insight (139)
	if e.research_card_name() != "":
		_knowledge.tooltip_text += "\nPlay %s card for more insight." % UIKit.with_article(e.research_card_name())


## Where the deck and discard are on screen (121): the Log button, whose drawer shows their counts. Dealt cards come
## from it; cards going to the deck or discard fly to it.
func pile_point() -> Vector2:
	return log_button.get_global_rect().get_center()


## "Log •" while the log has lines not yet seen (116).
func set_log_unread(unread: bool) -> void:
	log_button.text = "Log •" if unread else "Log"


## Puts the Supply button before Knowledge.
func add_supply_button(button: Button) -> void:
	add_child(button)
	move_child(button, _knowledge.get_index())


## " (+2)" / " (-1)": the forecast change for resource, or "" when there is no next upkeep.
func _forecast_text(forecast: Dictionary, resource: String) -> String:
	if not forecast.has(resource):
		return ""
	return " (%+d)" % forecast[resource]
