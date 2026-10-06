class_name BuildMenu
extends RefCounted
## The build menu (295): buildings aren't cards in the deck; the config's build_menu lists them, techs unlock its
## entries, and building one puts a new copy straight onto a settled territory for an action and its cost, as playing
## it would (CardPlay.place_error, CardPlay.put_into_play). A once entry (a wonder) is built once a game. Static
## functions on the engine's state; GameEngine's public methods call them.


## The unlocked entries, in config order.
static func entries(e: GameEngine) -> Array[String]:
	var out: Array[String] = []
	for id in e.config.get("build_menu", {}):
		if not e.state.locked_builds.has(id):
			out.append(id)
	return out


static func targets(e: GameEngine, card_id: String) -> Array[int]:
	if not entries(e).has(card_id):
		return [] as Array[int]
	return CardPlay.targets_for(e, _copy(e, card_id))


static func error(e: GameEngine, card_id: String, territory_uid: int) -> String:
	var busy := e._blocked_error("build")
	if busy != "":
		return busy
	var card_name: String = e.card_db[card_id].name if e.card_db.has(card_id) else card_id
	var menu: Dictionary = e.config.get("build_menu", {})
	if not menu.has(card_id):
		return "%s can't be built." % card_name
	if e.state.locked_builds.has(card_id):
		return "%s isn't unlocked yet." % card_name
	if menu[card_id].once and e.state.built_once.has(card_id):
		return "%s is already built." % card_name
	return CardPlay.place_error(e, _copy(e, card_id), territory_uid)


static func build(e: GameEngine, card_id: String, territory_uid: int) -> bool:
	if error(e, card_id, territory_uid) != "":
		return false
	var target := territory_uid if territory_uid != -1 else targets(e, card_id)[0]
	if e.config.build_menu[card_id].once:
		e.state.built_once.append(card_id)
	CardPlay.put_into_play(e, e._make_card(card_id), target, "Built")
	return true


static func preview(e: GameEngine, card_id: String, territory_uid: int) -> Dictionary:
	if error(e, card_id, territory_uid) != "":
		return {}
	var cost := CardPlay.cost_to_play(e, e.card_db[card_id])
	var f := e.fork()
	var before := _readings(e, territory_uid)
	build(f, card_id, territory_uid)
	var after := _readings(f, territory_uid)
	var lines: Array = []
	for key in before:
		if before[key] != after[key]:
			lines.append([key, before[key], after[key]])
	return {"cost": cost, "lines": lines}


## What build_preview compares on e, in its line order: each resource's upkeep forecast, then territory_uid's figures
## and the actions left (while limited).
static func _readings(e: GameEngine, territory_uid: int) -> Dictionary:
	var out := {}
	var forecast := e.upkeep_forecast()
	for r in e.config.resources:
		out[r] = forecast.get(r, 0)
	out["free_slots"] = e.free_slots(territory_uid)
	out["free_workers"] = e.free_workers(territory_uid)
	out["defense"] = e.defense(territory_uid)
	out["housing"] = e.housing(territory_uid)
	if e.actions_per_turn() >= 0:
		out["actions_left"] = e.actions_left()
	return out


## Opens build-menu entry card_id (the unlock op); a notice says so. Nothing if it was open.
static func unlock(e: GameEngine, card_id: String, source: CardInstance) -> void:
	if e.state.locked_builds.erase(card_id):
		var prefix := "  %s: " % source.def.name if source != null else "  "
		e._notice(prefix + now_text(e.card_db, card_id))


## What unlocking build-menu entry card_id means: "Granary can now be built.", a unit "… recruited." (296), an upgrade
## "Plough can now be built on a Farm." (300).
static func now_text(card_db: Dictionary, card_id: String) -> String:
	var def: CardDef = card_db[card_id]
	if def.is_upgrade():
		return "%s can now be built on %s." % [def.name, Population.with_article(card_db[def.upgrade_of].name)]
	return "%s can now be %s." % [def.name, "recruited" if def.type == CardDef.UNIT else "built"]


## A stand-in copy of card_id for the checks, with no uid: building makes the real one.
static func _copy(e: GameEngine, card_id: String) -> CardInstance:
	return CardInstance.new(-1, e.card_db[card_id])
