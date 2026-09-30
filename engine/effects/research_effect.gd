extends Effect
## { "op": "research" }
## Reveals the top 2 techs of the research deck to buy one or decline (see GameEngine.reveal_techs).
## Play only (not upkeep_ok): the reveal opens a choice, which upkeep has no one to answer.


func apply(engine: GameEngine, source: CardInstance) -> void:
	engine.reveal_techs(source)


func play_block_error(engine: GameEngine, _card: CardInstance) -> String:
	return engine.reveal_techs_error()


func opens_choice() -> bool:
	return true


func describe(_card_db: Dictionary) -> String:
	return "Seek knowledge"


func describe_long(_card_db: Dictionary) -> String:
	return "Seek knowledge: reveal 2 techs, buy 1 or decline"
