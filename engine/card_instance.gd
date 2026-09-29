class_name CardInstance
extends RefCounted
## A physical copy of a card during a game. Several instances can share one CardDef.

var uid: int
var def: CardDef
var territory_uid := -1  # the territory this card sits on, or -1
var passes := 0  # techs: times another tech was bought over it; each is -1 wealth
var pop := 0  # territories: population living there
var keywords: Array[String] = []  # territories: printed keywords, then rolled resource keywords


func _init(p_uid: int, p_def: CardDef) -> void:
	uid = p_uid
	def = p_def
	keywords = p_def.keywords.duplicate()


## A new instance with the same uid, card and per-copy fields (for GameState.copy).
func copy() -> CardInstance:
	var c := CardInstance.new(uid, def)
	c.territory_uid = territory_uid
	c.passes = passes
	c.pop = pop
	c.keywords = keywords.duplicate()
	return c
