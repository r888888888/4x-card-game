class_name TopBar
extends HBoxContainer
## The top bar: turn, food and wealth (with next upkeep's change), score and pop, then
## (115) the civilization and government button (one since 119), Buy Cards, Knowledge, Log and the Menu button. Costs float up from its counters; gains fly to them.

const FOOD_COLOR := Palette.GAIN  # the food stat; CardView.WARN_COLOR when pop would starve

var score_label: Label
var menu_button: Button  # "Menu (Esc)"
var log_button: Button  # "Log (L)": opens the log drawer (115)
var _turn_label: Label
var _food_label: Label
var _wealth_label: Label
var _pop_label: Label
var _identity: Button  # "Egypt · Chiefdom": opens the civilization and government modal; hidden with neither (119)
var _knowledge: Button  # opens the tech tree (059); research itself is a card (034)


## on_knowledge opens the tech tree, on_identity the civilization and government modal, on_log toggles the log drawer.
func _init(on_menu: Callable, on_knowledge: Callable, on_identity: Callable, on_log: Callable) -> void:
	add_theme_constant_override("separation", 20)  # tight: the stats and six buttons share 1920 px (115)
	_turn_label = UIKit.stat(self)
	_food_label = UIKit.stat(self, FOOD_COLOR)
	_wealth_label = UIKit.stat(self, Palette.WEALTH)
	_food_label.mouse_filter = Control.MOUSE_FILTER_PASS  # for the forecast tooltip
	_wealth_label.mouse_filter = Control.MOUSE_FILTER_PASS
	score_label = UIKit.stat(self, Palette.GAIN)
	_pop_label = UIKit.stat(self, Palette.POP)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	_identity = UIKit.button("", on_identity)
	_identity.tooltip_text = "Your civilization and government."
	_identity.hide()
	add_child(_identity)
	_knowledge = UIKit.button("Knowledge (T)", on_knowledge)
	add_child(_knowledge)
	log_button = UIKit.button("Log (L)", on_log)
	log_button.tooltip_text = "The game log: everything that happened."
	add_child(log_button)
	menu_button = UIKit.button("Menu (Esc)", on_menu)
	menu_button.tooltip_text = "New game, restart with a seed, reduce motion, exit."
	add_child(menu_button)


## Shows engine e's stats, pulsing the ones that changed.
func refresh(e: GameEngine) -> void:
	UIKit.set_stat(_turn_label, "Turn %d / %d" % [e.turn, e.turn_limit()])
	var forecast := e.upkeep_forecast()
	UIKit.set_stat(_food_label, "Food: %d%s" % [e.resources.get(GameEngine.FOOD, 0), _forecast_text(forecast, GameEngine.FOOD)])
	UIKit.set_stat(_wealth_label, "Wealth: %d%s" % [e.resources.get(GameEngine.WEALTH, 0), _forecast_text(forecast, GameEngine.WEALTH)])
	var starve: int = forecast.get("starve", 0)
	_food_label.add_theme_color_override("font_color", CardView.WARN_COLOR if starve > 0 else FOOD_COLOR)
	_food_label.tooltip_text = "Next upkeep: famine, %d pop will die." % starve if starve > 0 else "In brackets: change at the next upkeep, after pop eats."
	_wealth_label.tooltip_text = "In brackets: change at the next upkeep."
	UIKit.set_stat(score_label, "Score: %d" % e.score())
	_pop_label.visible = e.population_on()
	UIKit.set_stat(_pop_label, "Pop: %d" % e.total_pop())
	var names: PackedStringArray = []
	for zone_name in IdentityModal.ZONES:
		if not e.zone(zone_name).is_empty():
			names.append(e.zone(zone_name).cards[0].def.name)
	_identity.text = " · ".join(names)
	_identity.visible = not names.is_empty()
	_knowledge.text = "Knowledge (T) · %s" % e.era_name(e.era())
	_knowledge.visible = e.config.research_deck.size() > 0
	_knowledge.tooltip_text = "The tech tree: every tech by era, what it costs now and what it gives."
	if e.research_card_name() != "":
		_knowledge.tooltip_text += "\nPlay %s card to reveal 2 techs." % UIKit.with_article(e.research_card_name())


## "Log (L) •" while the log has lines not yet seen (116).
func set_log_unread(unread: bool) -> void:
	log_button.text = "Log (L) •" if unread else "Log (L)"


## Puts the Supply button after the civilization and government.
func add_supply_button(button: Button) -> void:
	add_child(button)
	move_child(button, _knowledge.get_index())


## The civilization and government button (visible or not).
func identity_button() -> Button:
	return _identity


## Where a card leaving for the civilization and government button flies to (the government a player just played).
func identity_point() -> Vector2:
	return _identity.get_global_rect().get_center()


## Resource tokens for a card_played outcome, on layer: costs float up from just below their counters (114), gains
## and VP fly from point (where the card was) to the counters, which pulse when they arrive.
func fly_outcome(layer: Control, outcome: Dictionary, point: Vector2) -> void:
	var n := 0
	for r in outcome.paid:
		var label := resource_label(r)
		if label != null:
			var from := label.get_global_rect().get_center() + Vector2(0, label.size.y)  # just below the counter
			UIKit.float_token(layer, "−%d %s" % [outcome.paid[r], r], from, UIKit.COST_COLOR, n * Anim.TOKEN_STAGGER)
			n += 1
	for r in outcome.gained:
		var label := resource_label(r)
		if label != null and outcome.gained[r] != 0:
			UIKit.fly_token(layer, "+%d %s" % [outcome.gained[r], r], point, label.get_global_rect().get_center(),
				UIKit.GAIN_COLOR, label, n * Anim.TOKEN_STAGGER)
			n += 1
	if outcome.vp != 0:
		UIKit.fly_token(layer, "+%d VP" % outcome.vp, point, score_label.get_global_rect().get_center(),
			UIKit.GAIN_COLOR, score_label, n * Anim.TOKEN_STAGGER)


## The counter for resource, or null if the bar has none.
func resource_label(resource: String) -> Label:
	if resource == GameEngine.FOOD:
		return _food_label
	if resource == GameEngine.WEALTH:
		return _wealth_label
	return null


## " (+2)" / " (-1)": the forecast change for resource, or "" when there is no next upkeep.
func _forecast_text(forecast: Dictionary, resource: String) -> String:
	if not forecast.has(resource):
		return ""
	return " (%+d)" % forecast[resource]
