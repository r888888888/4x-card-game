extends "res://engine/effects/gain_per_keyword_effect.gd"
## { "op": "lose_per_keyword", "resource": "food", "amount": 1, "keywords": ["desert"] }
## Takes amount x (settled territories with any of the keywords, printed or rolled), never below 0: the mirror of
## gain_per_keyword, whose fields and checks it shares (268). amount defaults to 1.


func apply(engine: GameEngine, source: CardInstance) -> void:
	var n := amount * engine.count_territories_with(keywords)
	if n > 0:
		engine.lose(resource, n, source)


func describe(_card_db: Dictionary) -> String:
	return "−%d %s per %s territory" % [amount, resource, keyword_list()]


func describe_long(_card_db: Dictionary) -> String:
	return "−%d %s for each settled territory with %s" % [amount, resource, CardDef.keyword_names(keywords)]
