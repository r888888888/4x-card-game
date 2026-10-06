extends Effect
## { "op": "create", "card": "city", "zone": "tableau" }
## Puts a new copy of a card into a zone (default tableau), e.g. a Settler founding a City.

var card_id: String
var zone: String


func fields() -> Array[String]:
	return ["card", "zone"]


func configure(data: Dictionary, ctx: Dictionary, errors: Array[String]) -> void:
	card_id = Fields.read_string(data, "card", errors)
	zone = Fields.read_string(data, "zone", errors, GameEngine.CREATE_ZONES, "tableau")


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.create_card(card_id, zone, source)


func describe(card_db: Dictionary) -> String:
	var card_name: String = card_db[card_id].name if card_db.has(card_id) else card_id
	var noun := "%s %s" % [_article(card_name), card_name]
	return "Create %s" % noun if zone == "tableau" else "Add %s to your %s" % [noun, zone]


## "an" before a name starting with a vowel letter, else "a".
static func _article(card_name: String) -> String:
	return "an" if card_name.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a"


func referenced_cards() -> Array[String]:
	return [card_id]


## An upgrade (300) only comes from the build menu, onto its base.
func check_references(card_db: Dictionary, errors: Array[String]) -> void:
	if card_db.has(card_id) and (card_db[card_id] as CardDef).is_upgrade():
		errors.append(ConfigLoader.UPGRADE_ONLY_BUILT % card_id)
