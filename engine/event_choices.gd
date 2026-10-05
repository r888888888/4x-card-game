class_name EventChoices
extends RefCounted
## Choice events (backlog 269): an event with `choices` offers 2 or 3 options, each {cost, effects}, one of them free.
## When it is drawn, after its own play effects, the choice is owed (GameEngine.PENDING_EVENT_CHOICE); drawn while
## another decision is owed, it waits (CardInstance.choice_waiting) and is owed once that one is paid. Choosing pays
## the option's cost and resolves its effects once. Static functions on the engine's state.

const MIN_OPTIONS := 2
const MAX_OPTIONS := 3


## An event's raw choices as [{cost, effects}]; problems go to errs, prefixed "choices" or "choices[i]".
static func parse(raw: Variant, ctx: Dictionary, errs: Array[String]) -> Array:
	var out := []
	if not (raw is Array):
		errs.append("'choices' must be a list of options like [{\"cost\": {\"wealth\": 2}, \"effects\": [...]}]")
		return out
	if raw.size() < MIN_OPTIONS or raw.size() > MAX_OPTIONS:
		errs.append("choices: an event offers %d to %d options (got %d)" % [MIN_OPTIONS, MAX_OPTIONS, raw.size()])
	for i in raw.size():
		var option := _parse_option(raw[i], ctx, errs, "choices[%d]" % i)
		if not option.is_empty():
			out.append(option)
	if out.size() == raw.size() and not out.is_empty() and not out.any(func(o): return o.cost.is_empty()):
		errs.append("choices: at least one option must be free (no cost), so there is always a choice")
	return out


## One option {cost, effects}, or {} when it isn't an object.
static func _parse_option(raw: Variant, ctx: Dictionary, errs: Array[String], at: String) -> Dictionary:
	if not (raw is Dictionary):
		errs.append("%s: an option must be an object like {\"cost\": {\"wealth\": 2}, \"effects\": [...]}" % at)
		return {}
	var cost := {}
	var raw_cost: Variant = raw.get("cost", {})
	if raw_cost is Dictionary:
		for r in raw_cost:
			var n: Variant = Fields.as_int(raw_cost[r])
			if not ctx.resources.has(r):
				errs.append("%s: cost: unknown resource '%s'" % [at, r])
			elif Fields.unpayable(r) != "":
				errs.append("%s: cost: %s" % [at, Fields.unpayable(r)])
			elif typeof(n) != TYPE_INT or n < 1:
				errs.append("%s: cost: '%s' must be an integer >= 1" % [at, r])
			else:
				cost[r] = n
	else:
		errs.append("%s: 'cost' must be an object like {\"wealth\": 2}" % at)
	var effects: Array[Effect] = []
	var raw_effects: Variant = raw.get("effects", [])
	if not (raw_effects is Array):
		errs.append("%s: 'effects' must be an array" % at)
		raw_effects = []
	for j in raw_effects.size():
		var where := "%s.effects[%d]" % [at, j]
		var e_errs: Array[String] = []
		var e_warns: Array[String] = []
		var effect := EffectRegistry.create(raw_effects[j], ctx, e_errs, e_warns)
		for m in e_errs:
			errs.append("%s: %s" % [where, m])
		if effect == null or not e_errs.is_empty():
			continue
		var problem := _effect_problem(raw_effects[j], effect)
		if problem != "":
			errs.append("%s: %s" % [where, problem])
		else:
			effects.append(effect)
	return {"cost": cost, "effects": effects}


## Why effect (raw data raw) can't be in an option, or "": an option resolves once, when chosen, on no territory, with
## nothing to target or choose.
static func _effect_problem(raw: Dictionary, effect: Effect) -> String:
	if raw.has("trigger"):
		return "an option's effect can't have a 'trigger' (it resolves once, when chosen)"
	if effect.opens_choice():
		return "an option's effect can't use '%s' (it opens a choice)" % effect.op
	return DataLoader.no_territory_effect_problem(effect, CardDef.EVENT)


## Event was just drawn (Events.draw): a choice event's choice is owed now, or waits behind the decision owed.
static func drawn(e: GameEngine, event: CardInstance) -> void:
	if event.def.choices.is_empty():
		return
	if e.state.pending.is_empty():
		_owe(e, event)
	else:
		event.choice_waiting = true


## A decision was just paid: the first active event whose choice waits is owed now (269).
static func next(e: GameEngine) -> void:
	if not e.state.pending.is_empty():
		return
	for event in e.zone("active_events").cards:
		if event.choice_waiting:
			_owe(e, event)
			return


static func _owe(e: GameEngine, event: CardInstance) -> void:
	event.choice_waiting = false
	e.state.pending = {"kind": GameEngine.PENDING_EVENT_CHOICE, "uid": event.uid, "options": range(event.def.choices.size())}


## The event whose choice is owed, or null.
static func owed_event(e: GameEngine) -> CardInstance:
	if e.state.pending.get("kind", "") != GameEngine.PENDING_EVENT_CHOICE:
		return null
	return e.zone("active_events").find(e.state.pending.uid)


## Why choose_option(index) would refuse, or "".
static func choose_error(e: GameEngine, index: int) -> String:
	var owed := e._owed_error(GameEngine.PENDING_EVENT_CHOICE, "No event choice is waiting.")
	if owed != "":
		return owed
	var choices: Array = owed_event(e).def.choices
	if index < 0 or index >= choices.size():
		return "No such option."
	var cost: Dictionary = choices[index].cost
	for r in cost:
		if e.resources.get(r, 0) < cost[r]:
			return "Not enough %s: needs %d." % [r, cost[r]]
	return ""


## Pays option index's cost and resolves its effects on the owed event, then emits option_chosen with what it did (the
## cost in lost). False (and no change) if choose_error says no.
static func choose(e: GameEngine, index: int) -> bool:
	if choose_error(e, index) != "":
		return false
	var event := owed_event(e)
	var option: Dictionary = event.def.choices[index]
	e.state.pending = {}
	e._outcome = CardPlay.new_outcome(event.uid)
	e._outcome.merge({"id": event.def.id, "index": index})
	e.pay(option.cost)
	for r in option.cost:
		e._outcome.lost[r] = option.cost[r]
	e._log("%s: %s." % [event.def.name, event.def.option_text(index, e.card_db)])
	for effect in option.effects:
		effect.apply(e, event)
	var outcome := e._outcome
	e._outcome = {}
	e.option_chosen.emit(outcome)
	e.changed.emit()
	return true
