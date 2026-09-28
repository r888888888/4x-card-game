class_name CardInstance
extends RefCounted
## A physical copy of a card during a game. Several instances can share one CardDef.

var uid: int
var def: CardDef
var territory_uid := -1  # the territory this card sits on, or -1
var passes := 0  # techs: times another tech was bought over it; each is -1 wealth
var pop := 0  # territories: population living there


func _init(p_uid: int, p_def: CardDef) -> void:
	uid = p_uid
	def = p_def
