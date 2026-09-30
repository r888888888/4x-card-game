extends Effect
## { "op": "gain_per_keyword", "resource": "food", "amount": 1, "keywords": ["forest", "grassland"] }
## Gains amount x (settled territories with any of the keywords, printed or rolled). amount defaults to 1.

var resource: String
var amount: int
var keywords: Array[String] = []


## Changes only resources, bonus score or pop, which upkeep_forecast can report (see Effect.upkeep_ok).
func upkeep_ok() -> bool:
	return true


func fields() -> Array[String]:
	return ["resource", "amount", "keywords"]


func configure(data: Dictionary, ctx: Dictionary, errors: Array[String]) -> void:
	resource = Fields.read_string(data, "resource", errors, ctx.resources)
	amount = Fields.read_int(data, "amount", errors, 1, 1)
	var raw: Variant = data.get("keywords")
	if not (raw is Array) or raw.is_empty():
		errors.append("'keywords' must be a non-empty list of keyword ids")
		return
	for k in raw:
		if not (k is String) or not ctx.keywords.has(k):
			errors.append("unknown keyword '%s' in 'keywords'" % [k])
		else:
			keywords.append(k)


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.gain(resource, amount * engine.count_territories_with(keywords), source)


func describe(_card_db: Dictionary) -> String:
	var names: PackedStringArray = []
	for k in keywords:
		names.append(k.replace("_", " "))
	return "+%d %s per %s territory" % [amount, resource, " or ".join(names)]


func describe_long(_card_db: Dictionary) -> String:
	return "+%d %s for each settled territory with %s" % [amount, resource, CardDef.keyword_names(keywords)]
