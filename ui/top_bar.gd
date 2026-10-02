class_name TopBar
extends HBoxContainer
## The top bar: turn, food, wealth, insight (139) and unrest (144, out of its limit) (with next upkeep's change), score
## and pop, then
## (115) Buy Cards, Knowledge, Log, End turn (120) and Menu (the civilization and government are in the Sidebar, 202). Any
## change to Food, Wealth, Insight, Unrest, Score or Pop rolls that counter's figure and tags it with its net change
## (126, 181).

const GLYPH := 22  # a counter's glyph (180), about the height of its figure
# Keys for counter() beside the resources (GameEngine.FOOD, WEALTH, INSIGHT, UNREST) (177).
const SCORE := "score"
const POP := "pop"
const TURN := "turn"

var menu_button: Button  # "Menu" (its key, Esc, is in its tooltip: 120)
var log_button: Button  # "Log": opens the log drawer (115); its key, L, is in its tooltip (120)
var end_turn_button: Button  # "End turn", or "Discard N (hand limit M)" while the hand is over its limit (120)
var _turn_label: Label
var _counters := {}  # key -> Counter: food, wealth, insight, unrest (hidden while off, 144), score, pop (hidden while off)
var _knowledge: Button  # opens the tech tree (059), where techs are learned (140)
# End turn's key (187): its release sounds wait for both the key coming up and its action (a mouse release sends
# button_up before pressed, a key sends them the other way round).
var _key_up := false
var _acted := false  # the press ran end_turn; _turn_ended: and it ended the turn
var _turn_ended := false
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
	end_turn_button = UIKit.button("End turn", _end_turn)
	end_turn_button.theme_type_variation = "AccentButton"
	end_turn_button.add_to_group(KeySounds.OWN_SOUNDS)
	end_turn_button.button_down.connect(_end_turn_down)
	end_turn_button.button_up.connect(_end_turn_up)
	add_child(end_turn_button)
	menu_button = UIKit.button("Menu", on_menu)
	menu_button.tooltip_text = "Shortcut: Esc. New game, restart with a seed, reduce motion, exit."
	add_child(menu_button)


func _end_turn() -> void:
	var turn := Game.engine.turn
	Game.engine.end_turn()
	_turn_ended = Game.engine.turn != turn
	_acted = true
	if _key_up:
		_end_turn_released()


## End turn's sounds (187): the desk's biggest key going down; coming up, a relay and the turn drum when its press
## ended the turn, else the plain key's release (a discard is owed).
func _end_turn_down() -> void:
	_key_up = false
	_acted = false
	_turn_ended = false
	var sfx := Sfx.find(self)
	if sfx != null:
		sfx.at_contact(Sfx.ENDTURN_PRESS, Anim.KEY_PRESS_TIME, Anim.SNAP, true)


func _end_turn_up() -> void:
	_key_up = true
	if _acted:
		_end_turn_released()
	else:
		_released_without_action.call_deferred()


## A release that ran no action by the end of the frame (dragged off the key) only comes back up.
func _released_without_action() -> void:
	if not _acted:
		_end_turn_released()


func _end_turn_released() -> void:
	_acted = true  # sound once
	_key_up = false
	var sfx := Sfx.find(self)
	if sfx == null:
		return
	if not _turn_ended:
		sfx.at_contact(Sfx.BUTTON_RELEASE, Anim.KEY_RELEASE_TIME, Anim.MACHINED, true)
		return
	var commit := 0.0 if UIKit.calm() else Anim.contact(Anim.KEY_RELEASE_TIME, Anim.MACHINED)
	sfx.play(Sfx.ENDTURN_COMMIT, commit, true)
	sfx.play(Sfx.ENDTURN_TURN, commit + Anim.ENDTURN_TURN_DELAY, true)


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
	var error := e.end_turn_error()
	end_turn_button.disabled = error != ""
	end_turn_button.tooltip_text = error if error != "" else "Shortcut: E. Upkeep, then draw up to your hand size."
	var pending := e.pending()
	if pending.get("kind", "") == GameEngine.PENDING_DISCARD:
		end_turn_button.text = "Discard %d (hand limit %d)" % [pending.count, e.hand_limit()]
	else:
		end_turn_button.text = "End turn"
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
