class_name ScoreBreakdown
extends RefCounted
## What makes up the score and the pop as they stand (380), as Ledger rows {label, count, amount}.

const EFFECTS := "Effects"  # the VP effects have added (bonus_score): one stored total, so one row
const POP := "Pop"  # the VP from pop; its count is the pop


## The score's sources: each card's printed VP on the tableau then in ALWAYS_ON_ZONES (copies grouped; an unfinished
## site or a card that has fallen back scores nothing, 286, 301), the VP from effects, then vp_per_pop for each pop.
## score() is their sum.
static func score_rows(e: GameEngine) -> Array[Dictionary]:
	var book := Ledger.new()
	for z in ["tableau"] + GameEngine.ALWAYS_ON_ZONES:
		for card in e.zone(z).cards:
			if Sites.unfinished(e, card) or Fallback.fallen_back(e, card):
				continue  # a site scores once completed (286), a card while it hasn't fallen back (300, 301)
			book.add(card.def.name, card, card.def.vp)
	book.add(EFFECTS, null, e.bonus_score)
	var rows := book.rows()
	if e.population_on() and e.total_pop() * e.config.population.vp_per_pop != 0:
		rows.append({"label": POP, "count": e.total_pop(), "amount": e.total_pop() * e.config.population.vp_per_pop})
	return rows


## Each settled territory's pop, in tableau order under its name (not grouped); [] with population off.
static func pop_rows(e: GameEngine) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not e.population_on():
		return out
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.TERRITORY and card.pop != 0:
			out.append({"label": e.territory_name(card.uid), "count": 1, "amount": card.pop})
	return out
