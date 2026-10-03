class_name Glossary
extends RefCounted
## Short explanations of the fixed game mechanics, shown with a card's details (backlog 056). Keyword terms are not
## here: CardDetails generates them from the card data.

const TERMS := {
	"Upkeep": "At the end of each turn, every card in your realm with an upkeep effect resolves it.",
	"Slots": "Each settled territory holds a limited number of buildings. A city can add slots to its territory.",
	"Workers": "With population on, each building or unit needs a free pop on its territory to be placed and to work. "
		+ "Buildings and units beyond a territory's pop are idle and skip upkeep.",
	"Pop": "People living on a territory. Pop works buildings, eats food at upkeep and scores VP.",
	"Housing": "The most pop a territory can hold. Growth stops there. Some buildings add housing to their territory.",
	"Famine Guard": "Each upkeep, a working building with a famine guard saves pop on its territory that would "
		+ "starve for lack of food.",
	"Requires": "The building can only go on a territory with one of the listed keywords.",
	"Prerequisite": "A tech can only be learned once you have researched its prerequisite.",
	"Era": "Techs come in eras. A new era adds its techs to the research deck.",
	"Explore": "Reveal territories from the territory deck and keep one in the frontier.",
	"Frontier": "Territories you have discovered but not settled. A Settler can found a city there.",
	"Settle": "Move a frontier territory into your realm and found a city on it.",
	"Grow": "Add pop to a territory, up to its housing.",
}
## Terms a player learns in the first turn; card details leave them out (backlog 112).
const BASIC: Array[String] = ["Upkeep", "Slots", "Pop"]


## The explanation of term, or "" if it isn't a fixed term.
static func text(term: String) -> String:
	return TERMS.get(term, "")
