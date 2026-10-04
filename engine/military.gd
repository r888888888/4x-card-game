class_name Military
extends RefCounted
## Military rules (backlog 161 on): a settled territory's defence from the units stationed there, its working walls,
## its cities and its terrain. Static functions on the engine's state; GameEngine's public methods call them.


## Settled territory uid's defence by source: {units, buildings, cities, terrain, total}, or {} when uid isn't a
## settled territory. Idle units and buildings add nothing; a unit counts where it is stationed, not on its home.
static func defense_parts(e: GameEngine, uid: int) -> Dictionary:
	var territory := Territories.settled(e, uid)
	if territory == null:
		return {}
	var parts := {"units": 0, "buildings": 0, "cities": 0, "terrain": 0}
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.UNIT and card.station_uid == uid and not e.is_idle(card.uid):
			parts.units += card.def.strength
		elif card.def.type == CardDef.BUILDING and card.territory_uid == uid and not e.is_idle(card.uid):
			parts.buildings += card.def.defense
		elif card.def.type == CardDef.CITY and card.territory_uid == uid:
			parts.cities += card.def.defense
	var terrain: Dictionary = e.config.get("terrain_defense", {})
	for k in territory.keywords:
		parts.terrain += terrain.get(k, 0)
	parts.total = parts.units + parts.buildings + parts.cities + parts.terrain
	return parts
