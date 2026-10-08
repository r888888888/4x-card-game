class_name CardInstance
extends RefCounted
## A physical copy of a card during a game. Several instances can share one CardDef.

var uid: int
var def: CardDef
var territory_uid := -1  # the territory this card sits on (a unit's home, 160), or -1
var base_uid := -1  # upgrades: the building it is built onto (300), or -1
var station_uid := -1  # units: the territory where it stands (160), or -1
var pop := 0  # territories: population living there
var keywords: Array[String] = []  # territories: printed keywords, then rolled resource keywords
var turns_left := 0  # active events: upkeeps left before the event is discarded
var counters := 0  # the Famine: how bad it is, 1 to max_counters (083); units: veteran counters (165)
var choice_waiting := false  # choice events: drawn while another decision was owed; owed once it is paid (269)
var progress := 0  # project sites: the wealth paid in so far (286)
var given_this_turn := 0  # project sites: the wealth paid in this turn (286)
var city_name := ""  # settled territories: the name it goes by (248); "" for its card's name
var raid_strength := 0  # active raids: the strength fixed when it was announced (374)


func _init(p_uid: int, p_def: CardDef) -> void:
	uid = p_uid
	def = p_def
	keywords = p_def.keywords.duplicate()


## The name it goes by: a named territory's city name (248), else its card's name.
func shown_name() -> String:
	return city_name if city_name != "" else def.name


## A new instance with the same uid, card and per-copy fields (for GameState.copy).
func copy() -> CardInstance:
	var c := CardInstance.new(uid, def)
	c.territory_uid = territory_uid
	c.station_uid = station_uid
	c.base_uid = base_uid
	c.pop = pop
	c.keywords = keywords.duplicate()
	c.turns_left = turns_left
	c.counters = counters
	c.city_name = city_name
	c.progress = progress
	c.given_this_turn = given_this_turn
	c.choice_waiting = choice_waiting
	c.raid_strength = raid_strength
	return c
