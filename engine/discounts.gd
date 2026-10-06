class_name Discounts
extends RefCounted
## Civilization discounts (backlog 108): while a civilization is yours, its `discounts` lower what some cards cost. A
## `type` or `tag` filter lowers a hand card's cost to play and a tech's cost to research; `supply` lowers supply
## prices. Static functions on the engine's state.

## The filters a discount entry may use; each entry has exactly one.
const FILTERS: Array[String] = ["type", "tag", "supply"]


## What the civilization's discounts take off def's cost, {resource: amount}: the supply discounts when for_supply
## (a supply price), else the ones whose type or tag def matches.
static func off(e: GameEngine, def: CardDef, for_supply: bool) -> Dictionary:
	var out := {}
	for civ in e.zone("civilization").cards:
		for d in civ.def.discounts:
			if (d.filter == "supply") == for_supply and _matches(d, def):
				for r in d.amounts:
					out[r] = out.get(r, 0) + d.amounts[r]
	return out


## def's cost to play: its printed cost plus its cost_per_territory once per settled territory (320), less the
## discounts, never below 0 per resource.
static func cost(e: GameEngine, def: CardDef) -> Dictionary:
	var less := off(e, def, false)
	var full := def.cost.duplicate()
	if not def.cost_per_territory.is_empty():
		var held := Territories.count_settled(e)
		for r in def.cost_per_territory:
			full[r] = full.get(r, 0) + def.cost_per_territory[r] * held
	var out := {}
	for r in full:
		out[r] = maxi(0, full[r] - less.get(r, 0))
	return out


static func _matches(d: Dictionary, def: CardDef) -> bool:
	match d.filter:
		"type":
			return def.type == d.value
		"tag":
			return def.tags.has(d.value)
	return true  # supply: every pile
