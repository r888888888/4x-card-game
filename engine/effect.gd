class_name Effect
extends RefCounted
## Base class for card effects. Each op lives in engine/effects/ and is
## registered by name in EffectRegistry.

const TRIGGERS: Array[String] = ["play", "upkeep", "start"]  # start: civilizations only, once at new_game

var op: String = ""
var trigger: String = "play"
var keyword: String = ""  # if set, applies only when the card's territory has this keyword


## Data fields this effect accepts besides "op" and "trigger".
func fields() -> Array[String]:
	return []


## Whether this op may use trigger "upkeep": true only for ops that change nothing but resources, bonus score and
## pop. Nobody can choose or target during upkeep, and upkeep_forecast reports only resources and starve.
func upkeep_ok() -> bool:
	return false


## Whether this effect acts on its own card's territory, so it does nothing on a card that has none (a tech or
## an event).
func needs_own_territory() -> bool:
	return false


## Read fields from data, appending any problems to errors.
## ctx has "resources" and "zones" (the valid names for each).
func configure(_data: Dictionary, _ctx: Dictionary, _errors: Array[String]) -> void:
	pass


func apply(_engine: GameEngine, _source: CardInstance) -> void:
	pass


## Short rules text for the card face, without the trigger prefix.
func describe(_card_db: Dictionary) -> String:
	return op


## Full rules text for the tooltip, without the trigger prefix. Defaults to describe.
func describe_long(card_db: Dictionary) -> String:
	return describe(card_db)


## True if this keyword effect can be shown as a bonus on prev's line: prev has no keyword, and
## both have the same op, trigger and fields apart from amount.
func can_merge_with(prev: Effect) -> bool:
	if keyword == "" or prev.keyword != "" or prev.op != op or prev.trigger != trigger:
		return false
	if not "amount" in fields():
		return false
	for f in fields():
		if f != "amount" and prev.get(f) != get(f):
			return false
	return true


## The bonus shown after a merged line, e.g. "+1".
func bonus_text() -> String:
	return "+%d" % get("amount")


## Glossary terms this effect uses (see Glossary), for the card details.
func terms() -> Array[String]:
	var out: Array[String] = []
	if trigger == "upkeep":
		out.append("Upkeep")
	return out


## Card ids this effect refers to; the loader checks they exist.
func referenced_cards() -> Array[String]:
	return []


## Checks referenced cards once every card is loaded (e.g. their type); problems go to errors.
func check_references(_card_db: Dictionary, _errors: Array[String]) -> void:
	pass


## The zone whose cards this effect targets, or "" if it needs no target.
func target_zone() -> String:
	return ""


## Whether this effect may leave a decision pending (pending()), so it can't resolve where nobody can choose.
func opens_choice() -> bool:
	return false


## Why card, which has this effect, can't be played right now, or "" if it can (e.g. nothing to research).
func play_block_error(_engine: GameEngine, _card: CardInstance) -> String:
	return ""


## play_error when the effect needs a target and there is none.
func no_target_error() -> String:
	return "There is nothing to target."


## play_error when the effect needs a target, several are valid, and none was given.
func choose_target_error() -> String:
	return "Choose a target."
