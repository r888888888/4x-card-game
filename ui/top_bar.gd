class_name TopBar
extends HBoxContainer
## The top bar: turn, food and wealth (with next upkeep's change), score, pop, the deck and discard counts, the
## seed and the Menu button. Played cards' resource tokens fly to and from its counters.

const FOOD_COLOR := Color("ffd966")  # the food stat; CardView.WARN_COLOR when pop would starve

var score_label: Label
var menu_button: Button  # "Menu (Esc)"
var _turn_label: Label
var _food_label: Label
var _wealth_label: Label
var _pop_label: Label
var _piles_label: Label
var _seed_label: Label  # "Seed 4242"


func _init(on_menu: Callable) -> void:
	add_theme_constant_override("separation", 36)
	_turn_label = UIKit.stat(self)
	_food_label = UIKit.stat(self, FOOD_COLOR)
	_wealth_label = UIKit.stat(self, Color("f2b46d"))
	_food_label.mouse_filter = Control.MOUSE_FILTER_PASS  # for the forecast tooltip
	_wealth_label.mouse_filter = Control.MOUSE_FILTER_PASS
	score_label = UIKit.stat(self, Color("ffd966"))
	_pop_label = UIKit.stat(self, Color("9fd89f"))
	_piles_label = UIKit.stat(self, Color("c3cad3"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	_seed_label = UIKit.heading("")
	add_child(_seed_label)
	menu_button = UIKit.button("Menu (Esc)", on_menu)
	menu_button.tooltip_text = "New game, restart with a seed, reduce motion, exit."
	add_child(menu_button)


## Shows engine e's stats, pulsing the ones that changed.
func refresh(e: GameEngine) -> void:
	UIKit.set_stat(_turn_label, "Turn %d / %d" % [e.turn, e.turn_limit()])
	_seed_label.text = "Seed %d" % e.seed_value
	var forecast := e.upkeep_forecast()
	UIKit.set_stat(_food_label, "Food: %d%s" % [e.resources.get(GameEngine.FOOD, 0), _forecast_text(forecast, GameEngine.FOOD)])
	UIKit.set_stat(_wealth_label, "Wealth: %d%s" % [e.resources.get(GameEngine.WEALTH, 0), _forecast_text(forecast, GameEngine.WEALTH)])
	var starve: int = forecast.get("starve", 0)
	_food_label.add_theme_color_override("font_color", CardView.WARN_COLOR if starve > 0 else FOOD_COLOR)
	_food_label.tooltip_text = "Next upkeep: %d pop will starve." % starve if starve > 0 else "In brackets: change at the next upkeep, after pop eats."
	_wealth_label.tooltip_text = "In brackets: change at the next upkeep."
	UIKit.set_stat(score_label, "Score: %d" % e.score())
	_pop_label.visible = e.population_on()
	UIKit.set_stat(_pop_label, "Pop: %d" % e.total_pop())
	UIKit.set_stat(_piles_label, "Deck %d  ·  Discard %d" % [e.zone("deck").size(), e.zone("discard").size()])


## Resource tokens for a card_played outcome, on layer: costs fly from the counters to point (where the card
## was), gains and VP fly from point to the counters, which pulse when they arrive.
func fly_outcome(layer: Control, outcome: Dictionary, point: Vector2) -> void:
	var n := 0
	for r in outcome.paid:
		var label := resource_label(r)
		if label != null:
			var from := label.get_global_rect().get_center() + Vector2(0, label.size.y)  # just below the counter
			UIKit.fly_token(layer, "−%d %s" % [outcome.paid[r], r], from, point, UIKit.COST_COLOR, null, n * Anim.TOKEN_STAGGER)
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


## A point on the "Deck N · Discard M" label: 0.25 is roughly the deck, 0.75 the discard pile.
func pile_point(fraction: float) -> Vector2:
	var r := _piles_label.get_global_rect()
	return Vector2(r.position.x + r.size.x * fraction, r.get_center().y)


## " (+2)" / " (-1)": the forecast change for resource, or "" when there is no next upkeep.
func _forecast_text(forecast: Dictionary, resource: String) -> String:
	if not forecast.has(resource):
		return ""
	return " (%+d)" % forecast[resource]
