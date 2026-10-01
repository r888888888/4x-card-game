class_name CardInstance
extends RefCounted
## A physical copy of a card during a game. Several instances can share one CardDef.

var uid: int
var def: CardDef
var territory_uid := -1  # the territory this card sits on, or -1
var pop := 0  # territories: population living there
var keywords: Array[String] = []  # territories: printed keywords, then rolled resource keywords
var turns_left := 0  # active events: upkeeps left before the event is discarded
var counters := 0  # the Famine: how bad it is, 1 to max_counters (083)


func _init(p_uid: int, p_def: CardDef) -> void:
	uid = p_uid
	def = p_def
	keywords = p_def.keywords.duplicate()


## A new instance with the same uid, card and per-copy fields (for GameState.copy).
func copy() -> CardInstance:
	var c := CardInstance.new(uid, def)
	c.territory_uid = territory_uid
	c.pop = pop
	c.keywords = keywords.duplicate()
	c.turns_left = turns_left
	c.counters = counters
	return c
