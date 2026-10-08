extends Effect
## { "op": "create", "card": "city", "zone": "tableau", "unique": false }
## Puts a new copy of a card into a zone (default tableau), e.g. a Settler founding a City. A unique create does nothing
## while the player owns a copy (364: the first Fishing Huts adds the one Net Fishing).

var card_id: String
var zone: String
var unique: bool


func fields() -> Array[String]:
	return ["card", "zone", "unique"]


func configure(data: Dictionary, ctx: Dictionary, errors: Array[String]) -> void:
	card_id = Fields.read_string(data, "card", errors)
	zone = Fields.read_string(data, "zone", errors, GameEngine.CREATE_ZONES, "tableau")
	unique = Fields.read_bool(data, "unique", errors)


func apply(engine: GameEngine, source: CardInstance) -> void:
	if unique and owned(engine):
		return
	engine.create_card(card_id, zone, source)


## Whether the player owns a copy of the card: one in any of GameEngine.OWNED_ZONES.
func owned(engine: GameEngine) -> bool:
	for zone_name in GameEngine.OWNED_ZONES:
		if engine.zone(zone_name).find_id(card_id) != null:
			return true
	return false


func describe(card_db: Dictionary) -> String:
	var card_name: String = card_db[card_id].name if card_db.has(card_id) else card_id
	var noun := "%s %s" % [_article(card_name), card_name]
	var text := "Create %s" % noun if zone == "tableau" else "Add %s to your %s" % [noun, zone]
	return text + " if you have none" if unique else text


func describe_long(card_db: Dictionary) -> String:
	return describe(card_db).replace(" if you have none", ", unless you already have one")


## "an" before a name starting with a vowel letter, else "a".
static func _article(card_name: String) -> String:
	return "an" if card_name.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a"


func referenced_cards() -> Array[String]:
	return [card_id]


## An upgrade (300) only comes from the build menu, onto its base.
func check_references(card_db: Dictionary, errors: Array[String]) -> void:
	if card_db.has(card_id) and (card_db[card_id] as CardDef).is_upgrade():
		errors.append(ConfigLoader.UPGRADE_ONLY_BUILT % card_id)
