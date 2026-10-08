class_name ScoreBreakdown
extends RefCounted
## What makes up the score and the pop as they stand (380), as Ledger rows {label, count, amount}.

const EFFECTS := "Effects"  # the VP effects have added (bonus_score): one stored total, so one row
const POP := "Pop"  # the VP from pop; its count is the pop


## The score's sources: each card's printed VP on the tableau then in ALWAYS_ON_ZONES (copies grouped; an unfinished
## site or a card that has fallen back scores nothing, 286, 301), the VP from effects, then vp_per_pop for each pop.
## They sum to total(e), which is score().
static func score_rows(e: GameEngine) -> Array[Dictionary]:
	var book := Ledger.new()
	for card in scoring_cards(e):
		book.add(card.def.name, card, card.def.vp)
	book.add(EFFECTS, null, e.bonus_score)
	var rows := book.rows()
	var pop_vp := pop_score(e)
	if pop_vp != 0:
		rows.append({"label": POP, "count": e.total_pop(), "amount": pop_vp})
	return rows


## The score (score()): what score_rows' amounts sum to, added up directly with no rows built (408): the bot asks for it
## thousands of times a turn.
static func total(e: GameEngine) -> int:
	var sum := e.bonus_score + pop_score(e)
	for card in scoring_cards(e):
		sum += card.def.vp
	return sum


## The cards whose printed VP counts, VP 0 left out: on the tableau, neither fallen back (Fallback.fallen_uids, one
## pass) nor an unfinished site; then every card in ALWAYS_ON_ZONES.
static func scoring_cards(e: GameEngine) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	var fallen := Fallback.fallen_uids(e)
	for card in e.zone("tableau").cards:
		if card.def.vp != 0 and not fallen.has(card.uid) and not Sites.unfinished(e, card):
			out.append(card)  # a site scores once completed (286), a card while it hasn't fallen back (300, 301)
	for z in GameEngine.ALWAYS_ON_ZONES:
		for card in e.zone(z).cards:
			if card.def.vp != 0:
				out.append(card)
	return out


## The VP from pop: vp_per_pop for each pop; 0 with population off.
static func pop_score(e: GameEngine) -> int:
	return e.total_pop() * e.config.population.vp_per_pop if e.population_on() else 0


## Each settled territory's pop, in tableau order under its name (not grouped); [] with population off.
static func pop_rows(e: GameEngine) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not e.population_on():
		return out
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.TERRITORY and card.pop != 0:
			out.append({"label": e.territory_name(card.uid), "count": 1, "amount": card.pop})
	return out
