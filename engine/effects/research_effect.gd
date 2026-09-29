extends Effect
## { "op": "research" }
## Reveals the top 2 techs of the research deck to buy one or decline (see GameEngine.reveal_techs).
## Play only: the reveal opens a choice, which upkeep has no one to answer.


func configure(_data: Dictionary, _ctx: Dictionary, errors: Array[String]) -> void:
	if trigger != "play":
		errors.append("'research' only works on play (got trigger '%s')" % trigger)


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.reveal_techs(source)


func play_block_error(engine: GameEngine) -> String:
	return engine.reveal_techs_error()


func describe(_card_db: Dictionary) -> String:
	return "Research"


func describe_long(_card_db: Dictionary) -> String:
	return "Research: reveal 2 techs, buy 1 or decline"
